#!/usr/bin/env fish

set -l REMOVE_PROFILE no
set -l TIMESTAMP (date +%Y%m%d_%H%M)

function usage
    echo "Usage: sudo ./uninstall_fm350.fish [--remove-profile]"
    exit 2
end

for arg in $argv
    switch $arg
        case --remove-profile
            set REMOVE_PROFILE yes
        case '*'
            usage
    end
end

if test (id -u) -ne 0
    echo "ERROR: run as root, e.g. sudo ./uninstall_fm350.fish" >&2
    exit 1
end

function restore_latest_backup
    set -l path $argv[1]
    set -l latest (ls -1t "$path".bak_* 2>/dev/null | head -n 1)
    if test -n "$latest"
        cp -a "$latest" "$path"
        echo "Restored backup: $latest -> $path"
        return 0
    end
    return 1
end

nmcli connection down FM350_RNDIS 2>/dev/null; or true
/usr/local/sbin/fm350-disconnect 2>/dev/null; or true

for path in \
    /etc/NetworkManager/dispatcher.d/90-fm350-rndis \
    /etc/NetworkManager/dispatcher.d/95-fm350-dns-guard \
    /etc/udev/rules.d/78-fm350-modemmanager.rules \
    /usr/local/sbin/fm350-detect \
    /usr/local/sbin/fm350-connect \
    /usr/local/sbin/fm350-disconnect \
    /usr/local/bin/fm350info
    if not restore_latest_backup "$path"
        if test -e "$path"
            mv "$path" "$path.removed_$TIMESTAMP"
            echo "Moved aside: $path"
        end
    end
end

udevadm control --reload-rules 2>/dev/null; or true
udevadm trigger 2>/dev/null; or true

if test "$REMOVE_PROFILE" = yes
    nmcli connection delete FM350_RNDIS 2>/dev/null; or true
else
    nmcli connection modify FM350_RNDIS connection.autoconnect no 2>/dev/null; or true
end

echo "Uninstall done. LAN_AC68U and ModemManager packages were not removed."
