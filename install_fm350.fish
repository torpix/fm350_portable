#!/usr/bin/env fish

set -l SRC_DIR (cd (dirname (status --current-filename)); and pwd)
set -l CONFIG /etc/fm350-rndis.conf
set -l TIMESTAMP (date +%Y%m%d_%H%M)
set -l AUTOCONNECT yes
set -l MASK_MM no
set -l MANAGE_DNS yes

function usage
    echo "Usage: sudo ./install_fm350.fish [--autoconnect yes|no] [--manage-dns yes|no] [--mask-modemmanager]"
    exit 2
end

set -l i 1
while test $i -le (count $argv)
    switch $argv[$i]
        case --autoconnect
            set i (math $i + 1)
            test $i -le (count $argv); or usage
            set AUTOCONNECT $argv[$i]
        case --manage-dns
            set i (math $i + 1)
            test $i -le (count $argv); or usage
            set MANAGE_DNS $argv[$i]
            contains -- "$MANAGE_DNS" yes no; or usage
        case --mask-modemmanager
            set MASK_MM yes
        case '*'
            usage
    end
    set i (math $i + 1)
end

if test (id -u) -ne 0
    echo "ERROR: run as root, e.g. sudo ./install_fm350.fish" >&2
    exit 1
end

function backup_if_exists
    set -l path $argv[1]
    if test -e "$path"
        cp -a "$path" "$path.bak_$TIMESTAMP"
        echo "Backup: $path -> $path.bak_$TIMESTAMP"
    end
end

function install_pkg
    set -l pkgs $argv
    if command -q pacman
        pacman -S --needed --noconfirm $pkgs
    else if command -q pamac
        pamac install --no-confirm $pkgs
    else if command -q yay
        yay -S --needed --noconfirm $pkgs
    else if command -q apt
        apt update
        apt install -y $pkgs
    else
        echo "ERROR: no supported package manager found (pacman/pamac/yay/apt)" >&2
        exit 1
    end
end

set -l deps atinout ethtool usbutils networkmanager iproute2
if command -q apt
    set deps atinout ethtool usbutils network-manager iproute2
end

echo "Installing dependencies: $deps"
install_pkg $deps

mkdir -p /usr/local/sbin /usr/local/bin /etc/NetworkManager/dispatcher.d /etc/udev/rules.d

for item in \
    /usr/local/sbin/fm350-detect \
    /usr/local/sbin/fm350-connect \
    /usr/local/sbin/fm350-disconnect \
    /usr/local/bin/fm350info \
    /etc/NetworkManager/dispatcher.d/90-fm350-rndis \
    /etc/NetworkManager/dispatcher.d/95-fm350-dns-guard \
    /etc/udev/rules.d/78-fm350-modemmanager.rules \
    $CONFIG
    backup_if_exists $item
end

install -m 0755 "$SRC_DIR/fm350-detect" /usr/local/sbin/fm350-detect
install -m 0755 "$SRC_DIR/fm350-connect" /usr/local/sbin/fm350-connect
install -m 0755 "$SRC_DIR/fm350-disconnect" /usr/local/sbin/fm350-disconnect
install -m 0755 "$SRC_DIR/fm350info" /usr/local/bin/fm350info
install -m 0755 "$SRC_DIR/dispatcher/90-fm350-rndis" /etc/NetworkManager/dispatcher.d/90-fm350-rndis
install -m 0755 "$SRC_DIR/dispatcher/95-fm350-dns-guard" /etc/NetworkManager/dispatcher.d/95-fm350-dns-guard

printf '%s\n' \
    '# Keep ModemManager away from Fibocom FM350-GL/Dell DW5931e in USB RNDIS+AT modes only.' \
    'ACTION!="add|change|bind", GOTO="fm350_mm_end"' \
    'SUBSYSTEM=="usb", ATTR{idVendor}=="0e8d", ATTR{idProduct}=="7127", ENV{ID_MM_DEVICE_IGNORE}="1"' \
    'SUBSYSTEM=="usb", ATTR{idVendor}=="0e8d", ATTR{idProduct}=="7126", ENV{ID_MM_DEVICE_IGNORE}="1"' \
    'SUBSYSTEM=="tty", ATTRS{idVendor}=="0e8d", ATTRS{idProduct}=="7127", ENV{ID_MM_DEVICE_IGNORE}="1"' \
    'SUBSYSTEM=="tty", ATTRS{idVendor}=="0e8d", ATTRS{idProduct}=="7126", ENV{ID_MM_DEVICE_IGNORE}="1"' \
    'ACTION=="add|change", SUBSYSTEM=="tty", ENV{ID_VENDOR_ID}=="0e8d", ENV{ID_MODEL_ID}=="7127", ENV{ID_USB_INTERFACE_NUM}=="06", SYMLINK+="fm350-at"' \
    'ACTION=="add|change", SUBSYSTEM=="tty", ENV{ID_VENDOR_ID}=="0e8d", ENV{ID_MODEL_ID}=="7126", ENV{ID_USB_INTERFACE_NUM}=="06", SYMLINK+="fm350-at"' \
    'LABEL="fm350_mm_end"' \
    >/etc/udev/rules.d/78-fm350-modemmanager.rules

udevadm control --reload-rules 2>/dev/null; or true
udevadm trigger 2>/dev/null; or true

if test "$MASK_MM" = yes
    echo "Masking ModemManager globally because --mask-modemmanager was requested."
    systemctl mask --now ModemManager.service 2>/dev/null; or true
end

if not systemctl is-active --quiet NetworkManager.service
    systemctl enable --now NetworkManager.service 2>/dev/null; or true
end

if nmcli -t -f NAME connection show | grep -qx FM350_PLAY
    nmcli connection modify FM350_PLAY connection.autoconnect no
end

if not nmcli -t -f NAME connection show | grep -qx FM350_RNDIS
    nmcli connection add type ethernet ifname "*" con-name FM350_RNDIS connection.id FM350_RNDIS
end

nmcli connection modify FM350_RNDIS \
    connection.autoconnect "$AUTOCONNECT" \
    ipv4.method disabled \
    ipv6.method ignore

if not test -e "$CONFIG"
    printf '%s\n' \
        'FM_IF="auto"' \
        'AT_PORT="auto"' \
        'APN="internet"' \
        'DNS1="1.1.1.1"' \
        'DNS2="8.8.8.8"' \
        'DNS3="9.9.9.9"' \
        "MANAGE_DNS=\"$MANAGE_DNS\"" \
        'ROUTE_METRIC="100"' \
        "AUTOCONNECT=\"$AUTOCONNECT\"" \
        'DISABLE_MODEMMANAGER_FOR_FM350="yes"' \
        >"$CONFIG"
end

/usr/local/sbin/fm350-detect --write-config; or true

if test -r "$CONFIG"
    sed -i "s/^AUTOCONNECT=.*/AUTOCONNECT=\"$AUTOCONNECT\"/" "$CONFIG"
    if grep -q '^MANAGE_DNS=' "$CONFIG"
        sed -i "s/^MANAGE_DNS=.*/MANAGE_DNS=\"$MANAGE_DNS\"/" "$CONFIG"
    else
        printf 'MANAGE_DNS="%s"\n' "$MANAGE_DNS" >>"$CONFIG"
    end
    set -l detected_if (awk -F= '$1=="FM_IF"{gsub(/"/,"",$2); print $2}' "$CONFIG")
    if test -n "$detected_if"; and test "$detected_if" != auto
        nmcli connection modify FM350_RNDIS connection.interface-name "$detected_if" 2>/dev/null; or true
    end

    set -l detected_at (awk -F= '$1=="AT_PORT"{gsub(/"/,"",$2); print $2}' "$CONFIG")
    if test -n "$detected_at"; and test "$detected_at" != auto; and test -c "$detected_at"
        set -l port_group (stat -c '%G' "$detected_at" 2>/dev/null)
        if test -n "$port_group"; and test -n "$SUDO_USER"; and test "$SUDO_USER" != root
            usermod -aG "$port_group" "$SUDO_USER"
            echo "Added $SUDO_USER to $port_group for access to $detected_at."
            echo "Log out and log in again, or reboot, before running fm350info without sudo."
        end
    end
end

echo "Installed FM350 portable package."
echo "Config: $CONFIG"
echo "Next: fm350-detect; fm350info; sudo nmcli connection up FM350_RNDIS"
