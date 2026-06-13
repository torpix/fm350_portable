# fm350_portable

Portable Linux helper package for **Fibocom FM350-GL / Dell DW5931e-eSIM** 5G modem in USB RNDIS + AT mode.

This project provides a repeatable way to use the FM350-GL modem on Linux machines through:

* NetworkManager
* USB RNDIS network interface
* AT command control port
* automatic modem/interface detection
* terminal diagnostics similar to a lightweight NetMonster view

Main validated setup:

```text
Q370 / Manjaro KDE
Fibocom FM350-GL / Dell DW5931e-eSIM
USB ID: 0e8d:7127
GTUSBMODE: 41
NetworkManager
RNDIS interface: enp0s20f0u3
AT port: /dev/ttyUSB3
```

Polish documentation is available in:

```text
README_PL.md
```

---

## 1. Project goal

`fm350_portable` automates setup and runtime handling for the FM350-GL modem in:

```text
RNDIS + AT mode
```

The package can:

* detect the FM350-GL modem by USB ID,
* detect the AT command port,
* detect the RNDIS network interface,
* create a NetworkManager profile named `FM350_RNDIS`,
* activate the cellular data context over AT,
* assign the modem-provided IP address to the RNDIS interface,
* set the default route through the modem,
* enforce DNS while the modem connection is active,
* provide `fm350info`, a terminal-based FM350 diagnostic tool.

---

## 2. Supported modem

Tested modem:

```text
Fibocom FM350-GL / Dell DW5931e-eSIM
```

Supported USB IDs:

```text
0e8d:7127  GTUSBMODE=41
0e8d:7126  GTUSBMODE=40
```

Primary tested mode:

```text
GTUSBMODE=41
```

---

## 3. Repository layout

```text
fm350_portable/
├── bootstrap.sh
├── install_fm350.fish
├── uninstall_fm350.fish
├── fm350-detect
├── fm350-connect
├── fm350-disconnect
├── fm350info
├── dispatcher/
│   ├── 90-fm350-rndis
│   └── 95-fm350-dns-guard
├── .gitignore
├── README.md
└── README_PL.md
```

---

## 4. Quick start

Clone the repository:

```sh
git clone https://github.com/torpix/fm350_portable.git
cd fm350_portable
```

Run the bootstrap script:

```sh
sh ./bootstrap.sh
```

The bootstrap script checks dependencies and runs:

```sh
sudo fish ./install_fm350.fish --autoconnect yes
```

Reboot after installation:

```sh
sudo reboot
```

After reboot:

```sh
fm350-detect
fm350info
ip route get 1.1.1.1
```

---

## 5. Manual installation

### Manjaro / Arch Linux

Install base dependencies:

```sh
sudo pacman -S --needed git fish networkmanager ethtool usbutils iproute2
```

Install `atinout` if it is not already available. On Arch-based systems it may be available through AUR, for example with `yay` or `pamac`.

Then run:

```sh
sudo fish ./install_fm350.fish --autoconnect yes
sudo reboot
```

### Kali / Debian

Install dependencies:

```sh
sudo apt update
sudo apt install -y git fish network-manager ethtool usbutils iproute2 atinout
```

Then run:

```sh
sudo fish ./install_fm350.fish --autoconnect yes
sudo reboot
```

---

## 6. What the installer does

`install_fm350.fish` performs the following steps:

1. Detects the FM350-GL modem.
2. Detects the AT command port, for example:

```text
/dev/ttyUSB3
```

3. Detects the RNDIS network interface, for example:

```text
enp0s20f0u3
```

4. Writes the runtime configuration to:

```text
/etc/fm350-rndis.conf
```

Example configuration:

```text
FM_IF="enp0s20f0u3"
AT_PORT="/dev/ttyUSB3"
APN="internet"
DNS1="1.1.1.1"
DNS2="8.8.8.8"
DNS3="9.9.9.9"
ROUTE_METRIC="100"
AUTOCONNECT="yes"
DISABLE_MODEMMANAGER_FOR_FM350="yes"
```

5. Installs helper scripts:

```text
/usr/local/sbin/fm350-detect
/usr/local/sbin/fm350-connect
/usr/local/sbin/fm350-disconnect
/usr/local/bin/fm350info
```

6. Installs NetworkManager dispatcher scripts:

```text
/etc/NetworkManager/dispatcher.d/90-fm350-rndis
/etc/NetworkManager/dispatcher.d/95-fm350-dns-guard
```

7. Creates or updates the NetworkManager connection:

```text
FM350_RNDIS
```

8. Enables autoconnect if requested:

```sh
--autoconnect yes
```

---

## 7. ModemManager handling

This package does **not** globally mask ModemManager by default.

This is intentional. Some laptops may contain an additional internal LTE modem, for example a Dell WWAN module. Globally disabling ModemManager could break that device.

Instead, this package is designed to keep ModemManager away from the FM350-GL by matching the FM350 USB ID.

Global ModemManager masking is available only as an explicit option:

```sh
sudo fish ./install_fm350.fish --autoconnect yes --mask-modemmanager
```

Use this only if you intentionally want to disable ModemManager system-wide.

---

## 8. AT port permissions

The AT port usually looks like this:

```text
crw-rw---- root uucp /dev/ttyUSB3
```

The installer detects the port group and adds the installing user to that group, for example:

```text
uucp
```

After installation, log out and log back in, or reboot:

```sh
sudo reboot
```

Without a new login session, `fm350info` may still require `sudo`.

---

## 9. fm350info — lightweight NetMonster-style diagnostics

`fm350info` prints:

* operator,
* LTE/5G registration state,
* signal data,
* Cell ID / TAC / PCI / channel data,
* LTE/NR bands,
* carrier aggregation information,
* active APN,
* modem IP address,
* Linux routing state,
* DNS state.

Run:

```sh
fm350info
```

Fallback:

```sh
sudo fm350info
```

Commands used internally include:

```text
AT+COPS?
AT+CEREG?
AT+CGREG?
AT+CSQ
AT+CESQ
AT+GTCCINFO?
AT+GTCAINFO?
AT+GTACT?
AT+CGACT?
AT+CGPADDR=1
AT+CGCONTRDP=1
```

---

## 10. Band code interpretation

Common FM350 band code mapping used by this package:

```text
101  = LTE B1
103  = LTE B3
107  = LTE B7
120  = LTE B20
128  = LTE B28

501  = NR n1
503  = NR n3
5028 = NR n28
5078 = NR n78
```

Example output:

```text
PCC:5078 ... -109
PCC:101  ... -105
SCC 1:103 ...
```

Interpretation:

```text
5G NR n78
LTE B1
LTE B3 as secondary carrier
```

---

## 11. Connectivity checks

After installation:

```sh
nmcli connection show --active | grep -E 'FM350|LAN'
ip -br addr
ip route get 1.1.1.1
cat /etc/resolv.conf
curl -4 --interface <FM_IF> -I --max-time 20 https://speed.cloudflare.com
```

Example for the Q370 test machine:

```sh
curl -4 --interface enp0s20f0u3 -I --max-time 20 https://speed.cloudflare.com
```

Expected result:

```text
HTTP/1.1 200 OK
```

---

## 12. Manual connect and disconnect

Connect through NetworkManager:

```sh
sudo nmcli connection up FM350_RNDIS
```

Disconnect:

```sh
sudo nmcli connection down FM350_RNDIS
```

Direct helper scripts:

```sh
sudo fm350-connect
sudo fm350-disconnect
```

---

## 13. Uninstall

Run:

```sh
sudo fish ./uninstall_fm350.fish
```

The uninstaller removes:

* FM350 helper scripts,
* FM350 dispatcher scripts,
* optional NetworkManager profile entries.

It does not remove system packages, does not remove ModemManager, and does not modify unrelated LAN profiles.

---

## 14. Safety notes

Do not use old scripts that communicate with the modem through patterns such as:

```sh
cat /dev/ttyUSBx
printf ... > /dev/ttyUSBx
```

If the serial port disappears, such code may accidentally create a regular file in `/dev`, for example:

```text
/dev/ttyUSB3
```

That can break modem detection.

This project uses:

```text
atinout + timeout + character device checks
```

Before using an AT port, scripts verify that it is a character device:

```sh
[ -c "$AT_PORT" ]
```

---

## 15. Logs

Typical log files:

```text
/tmp/fm350-rndis.log
/tmp/fm350-rndis-dispatcher.log
/tmp/fm350-dns-guard.log
/tmp/fm350info-UID.log
```

`fm350info` uses a per-user log file:

```text
/tmp/fm350info-1000.log
```

Lack of write access to a log file should not block AT command execution.

---

## 16. Troubleshooting

### `AT_PORT=auto`

Check USB and serial devices:

```sh
lsusb
ls -l /dev/ttyUSB*
sudo fm350-detect
```

Manual AT port test:

```sh
for p in /dev/ttyUSB*; do
  if [ -c "$p" ]; then
    echo "### $p"
    printf 'ATE0\nATI\nAT+GTUSBMODE?\n' | sudo timeout 10s atinout - "$p" -
  fi
done
```

### FM350_RNDIS is active, but there is no internet

Check:

```sh
ip -br addr
ip route get 1.1.1.1
cat /etc/resolv.conf
curl -4 --interface <FM_IF> -I --max-time 20 https://speed.cloudflare.com
```

### `fm350info` requires sudo

Check group membership:

```sh
groups
stat -c '%U %G %a %n' /dev/ttyUSB3
```

If the user is not in the port group, rerun the installer or add the user to the group manually.

After changing groups, log out and log back in or reboot.

### Route still points to LAN

Check:

```sh
ip route get 1.1.1.1
nmcli connection show --active
```

Force the modem connection:

```sh
sudo nmcli connection up FM350_RNDIS
```

---

## 17. Q370 validation status

Validated on:

```text
Q370 / Manjaro KDE
FM350-GL / Dell DW5931e-eSIM
USB ID: 0e8d:7127
GTUSBMODE: 41
NetworkManager
RNDIS interface: enp0s20f0u3
AT port: /dev/ttyUSB3
```

Confirmed:

```text
reboot autostart: OK
FM350_RNDIS active: OK
default route through modem: OK
HTTP through modem: OK
fm350info without sudo: OK
per-user fm350info log: OK
```

---

## 18. Planned tests

Pending:

```text
Dell Precision 7510 / Manjaro
Dell 7220 / Kali
different interface names
different AT port numbers
different SIM/operator
antenna and modem placement tests
```

---

## 19. Minimal workflow on a new machine

```sh
git clone https://github.com/torpix/fm350_portable.git
cd fm350_portable
sh ./bootstrap.sh
sudo reboot
fm350info
ip route get 1.1.1.1
```

---

## 20. Current status

```text
Q370: PASS
Dell Precision 7510: pending
Dell 7220 / Kali: pending
```

---

## 21. Maintainer

```text
torpix
```

This is a practical helper package for personal Linux infrastructure and FM350-GL modem testing.
