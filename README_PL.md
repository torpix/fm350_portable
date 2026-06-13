# fm350_portable

Portable Linux helper package for **Fibocom FM350-GL / Dell DW5931e-eSIM** 5G modem in USB RNDIS + AT mode.

Projekt przygotowany do szybkiego uruchamiania modemu FM350-GL na różnych komputerach z Linuksem, szczególnie:

* Manjaro / Arch Linux
* Kali / Debian
* NetworkManager
* modem USB widoczny jako RNDIS + porty AT

Test główny: **Q370 / Manjaro / FM350-GL / USB ID 0e8d:7127 / GTUSBMODE=41**.

---

## 1. Cel projektu

`fm350_portable` automatyzuje konfigurację modemu Fibocom FM350-GL w trybie:

```text
RNDIS + AT
```

Pakiet:

* wykrywa modem po USB ID,
* wykrywa interfejs RNDIS,
* wykrywa port AT,
* tworzy profil NetworkManager `FM350_RNDIS`,
* ustawia połączenie danych przez modem,
* ustawia trasę domyślną przez modem,
* ustawia DNS,
* dodaje dispatchery NetworkManager,
* dostarcza `fm350info`, czyli terminalowy „NetMonster-light” dla FM350.

---

## 2. Obsługiwany modem

Testowany modem:

```text
Fibocom FM350-GL / Dell DW5931e-eSIM
```

Obsługiwane identyfikatory USB:

```text
0e8d:7127  GTUSBMODE=41
0e8d:7126  GTUSBMODE=40
```

Testowany tryb roboczy:

```text
GTUSBMODE=41
```

---

## 3. Zawartość repozytorium

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
└── README.md
```

---

## 4. Szybki start

Na nowym komputerze:

```sh
git clone https://github.com/torpix/fm350_portable.git
cd fm350_portable
sh ./bootstrap.sh
```

`bootstrap.sh` sprawdza zależności i uruchamia instalator:

```sh
sudo fish ./install_fm350.fish --autoconnect yes
```

Po instalacji zalecany jest restart:

```sh
sudo reboot
```

Po restarcie:

```sh
fm350-detect
fm350info
ip route get 1.1.1.1
```

---

## 5. Instalacja ręczna

Jeśli nie używasz `bootstrap.sh`:

### Manjaro / Arch

```sh
sudo pacman -S --needed git fish networkmanager ethtool usbutils iproute2
```

`atinout` może wymagać instalacji z AUR, np. przez `yay` albo `pamac`.

Następnie:

```sh
sudo fish ./install_fm350.fish --autoconnect yes
sudo reboot
```

### Kali / Debian

```sh
sudo apt update
sudo apt install -y git fish network-manager ethtool usbutils iproute2 atinout
```

Następnie:

```sh
sudo fish ./install_fm350.fish --autoconnect yes
sudo reboot
```

---

## 6. Co robi instalator

`install_fm350.fish`:

1. Wykrywa modem FM350-GL.
2. Wykrywa port AT, np.:

```text
/dev/ttyUSB3
```

3. Wykrywa interfejs RNDIS, np.:

```text
enp0s20f0u3
```

4. Tworzy konfigurację:

```text
/etc/fm350-rndis.conf
```

Przykład:

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

5. Instaluje skrypty:

```text
/usr/local/sbin/fm350-detect
/usr/local/sbin/fm350-connect
/usr/local/sbin/fm350-disconnect
/usr/local/bin/fm350info
```

6. Instaluje dispatchery NetworkManager:

```text
/etc/NetworkManager/dispatcher.d/90-fm350-rndis
/etc/NetworkManager/dispatcher.d/95-fm350-dns-guard
```

7. Tworzy połączenie NetworkManager:

```text
FM350_RNDIS
```

8. Ustawia autostart, jeśli wybrano:

```sh
--autoconnect yes
```

---

## 7. ModemManager

Pakiet domyślnie **nie maskuje globalnie ModemManager**.

To ważne, bo na laptopach może istnieć drugi modem LTE, np. wewnętrzny modem Dell.

Zamiast globalnego maskowania pakiet ma izolować FM350 po USB ID.

Globalne maskowanie jest dostępne tylko jako świadoma opcja:

```sh
sudo fish ./install_fm350.fish --autoconnect yes --mask-modemmanager
```

Używaj tego tylko wtedy, gdy wiesz, że chcesz całkowicie wyłączyć ModemManager.

---

## 8. Uprawnienia do portu AT

Port AT zwykle wygląda tak:

```text
crw-rw---- root uucp /dev/ttyUSB3
```

Instalator wykrywa grupę portu i dopisuje użytkownika do tej grupy, np.:

```text
uucp
```

Po instalacji potrzebne jest:

```text
wylogowanie i ponowne logowanie
```

albo:

```sh
sudo reboot
```

Bez tego `fm350info` może wymagać `sudo`.

---

## 9. fm350info — NetMonster-light

`fm350info` pokazuje:

* operatora,
* rejestrację LTE/5G,
* sygnał,
* Cell ID / TAC / PCI / kanał,
* pasma LTE/NR,
* agregację,
* aktywny APN,
* IP modemu,
* trasę Linuksa,
* DNS.

Uruchomienie:

```sh
fm350info
```

Lub awaryjnie:

```sh
sudo fm350info
```

Przykładowe pola:

```text
+COPS?
+CEREG?
+CGREG?
+CSQ
+CESQ
+GTCCINFO?
+GTCAINFO?
+GTACT?
+CGACT?
+CGPADDR=1
+CGCONTRDP=1
```

---

## 10. Interpretacja pasm

Przykładowa interpretacja kodów:

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

Przykład:

```text
PCC:5078 ... -109
PCC:101  ... -105
SCC 1:103 ...
```

Oznacza:

```text
5G NR n78
LTE B1
LTE B3 jako dodatkowa nośna
```

---

## 11. Sprawdzenie połączenia

Po instalacji:

```sh
nmcli connection show --active | grep -E 'FM350|LAN'
ip -br addr
ip route get 1.1.1.1
cat /etc/resolv.conf
curl -4 --interface <FM_IF> -I --max-time 20 https://speed.cloudflare.com
```

Przykład dla Q370:

```sh
curl -4 --interface enp0s20f0u3 -I --max-time 20 https://speed.cloudflare.com
```

Dobry wynik:

```text
HTTP/1.1 200 OK
```

---

## 12. Ręczne połączenie / rozłączenie

Połączenie:

```sh
sudo nmcli connection up FM350_RNDIS
```

Rozłączenie:

```sh
sudo nmcli connection down FM350_RNDIS
```

Bezpośrednie skrypty:

```sh
sudo fm350-connect
sudo fm350-disconnect
```

---

## 13. Deinstalacja

```sh
sudo fish ./uninstall_fm350.fish
```

Deinstalator:

* usuwa skrypty FM350,
* usuwa dispatchery FM350,
* może usunąć profil `FM350_RNDIS`,
* nie usuwa pakietów systemowych,
* nie usuwa ModemManager,
* nie rusza istniejącego LAN.

---

## 14. Bezpieczeństwo

Nie używaj starych skryptów typu:

```sh
cat /dev/ttyUSBx
printf ... > /dev/ttyUSBx
```

Jeśli port zniknie, taki kod może przypadkowo utworzyć zwykły plik w `/dev`, np.:

```text
/dev/ttyUSB3
```

i popsuć dalsze wykrywanie modemu.

Ten projekt używa:

```text
atinout + timeout + sprawdzenie urządzenia znakowego
```

Każdy port AT jest sprawdzany jako urządzenie znakowe:

```sh
[ -c "$AT_PORT" ]
```

---

## 15. Logi

Typowe logi:

```text
/tmp/fm350-rndis.log
/tmp/fm350-rndis-dispatcher.log
/tmp/fm350-dns-guard.log
/tmp/fm350info-UID.log
```

`fm350info` używa osobnego logu użytkownika:

```text
/tmp/fm350info-1000.log
```

Brak dostępu do logu nie powinien blokować działania AT.

---

## 16. Troubleshooting

### Problem: `AT_PORT=auto`

Sprawdź:

```sh
lsusb
ls -l /dev/ttyUSB*
sudo fm350-detect
```

Ręczny test portów:

```sh
for p in /dev/ttyUSB*; do
  if [ -c "$p" ]; then
    echo "### $p"
    printf 'ATE0\nATI\nAT+GTUSBMODE?\n' | sudo timeout 10s atinout - "$p" -
  fi
done
```

### Problem: brak internetu mimo aktywnego FM350_RNDIS

Sprawdź:

```sh
ip -br addr
ip route get 1.1.1.1
cat /etc/resolv.conf
curl -4 --interface <FM_IF> -I --max-time 20 https://speed.cloudflare.com
```

### Problem: `fm350info` wymaga sudo

Sprawdź grupy:

```sh
groups
stat -c '%U %G %a %n' /dev/ttyUSB3
```

Jeśli użytkownik nie jest w grupie portu, uruchom ponownie instalator albo dodaj grupę ręcznie.

Po zmianie grupy wymagane jest wylogowanie/zalogowanie albo restart.

### Problem: modem działa, ale tylko LAN ma trasę

Sprawdź:

```sh
ip route get 1.1.1.1
nmcli connection show --active
```

Wymuś połączenie:

```sh
sudo nmcli connection up FM350_RNDIS
```

---

## 17. Test Q370 PASS

Przetestowane na:

```text
Q370 / Manjaro KDE
FM350-GL / Dell DW5931e-eSIM
USB ID: 0e8d:7127
GTUSBMODE: 41
NetworkManager
RNDIS interface: enp0s20f0u3
AT port: /dev/ttyUSB3
```

Potwierdzone:

```text
autostart po reboot: OK
FM350_RNDIS active: OK
route przez modem: OK
HTTP przez modem: OK
fm350info bez sudo: OK
osobny log fm350info: OK
```

---

## 18. Planowane testy

Do wykonania:

```text
Dell Precision 7510 / Manjaro
Dell 7220 / Kali
test z innymi nazwami interfejsów
test z innym AT_PORT
test SIM innego operatora
test anten / pozycji modemu
```

---

## 19. Minimalny workflow na nowym komputerze

```sh
git clone https://github.com/torpix/fm350_portable.git
cd fm350_portable
sh ./bootstrap.sh
sudo reboot
fm350info
ip route get 1.1.1.1
```

---

## 20. Status

```text
Q370: PASS
7510: pending
7220/Kali: pending
```

---

## 21. Utrzymanie

Repozytorium utrzymywane przez:

```text
torpix
```

Projekt roboczy / prywatny helper do własnej infrastruktury Linux + FM350-GL.
