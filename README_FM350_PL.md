# FM350_PORTABLE_v1

Przenosna paczka do obslugi Fibocom FM350-GL / Dell DW5931e-eSIM w trybie USB RNDIS + AT. Mechanizm jest przygotowany dla:

- Q370 / Manjaro
- Dell Precision 7510 / Manjaro
- Dell 7220 / Kali/Debian

Cel: polaczenie danych przez RNDIS, sterowanie modemem przez AT, automatyczne wykrycie portu AT i interfejsu RNDIS, ustawienie adresu IPv4 `/32` z `AT+CGPADDR`, default route przez modem oraz DNS.

## Bezpieczenstwo

Nie uruchamiac starych skryptow, ktore uzywaja `cat /dev/ttyUSBx`, `printf > /dev/ttyUSBx` albo podobnych przekierowan do portu modemu. Gdy port zniknie, taki kod moze utworzyc zwykly plik w `/dev` i popsuc dalsze wykrywanie.

Ta paczka:

- nie zaklada stalego `/dev/ttyUSB3`,
- nie zaklada stalego `enp0s20f0u3`,
- przed kazda komenda AT sprawdza, czy `AT_PORT` jest urzadzeniem znakowym,
- uzywa `timeout` i `atinout`,
- nie maskuje globalnie ModemManager domyslnie,
- dodaje regule udev ignorujaca tylko FM350 po `0e8d:7127` i `0e8d:7126`.

Globalne maskowanie ModemManager jest dostepne tylko jako swiadoma opcja instalacji: `--mask-modemmanager`.

## Pliki

```text
fm350_portable/
├── install_fm350.fish
├── uninstall_fm350.fish
├── fm350-detect
├── fm350-connect
├── fm350-disconnect
├── fm350info
├── dispatcher/
│   ├── 90-fm350-rndis
│   └── 95-fm350-dns-guard
└── README_FM350_PL.md
```

## Instalacja Manjaro

```bash
cd fm350_portable
sudo fish ./install_fm350.fish --autoconnect yes
```

Instalator uzyje `pacman`, `pamac` albo `yay` i zainstaluje:

```text
atinout ethtool usbutils networkmanager iproute2
```

Instalator tworzy profil NetworkManager `FM350_RNDIS`. Jezeli istnieje stary profil `FM350_PLAY`, zostanie mu ustawione `connection.autoconnect no`, ale profil nie zostanie usuniety.

Instalator wykrywa grupe portu AT, np. `uucp` albo `dialout`, i dopisuje uzytkownika uruchamiajacego `sudo` do tej grupy. Po instalacji wyloguj sie i zaloguj ponownie albo zrestartuj system, zeby `fm350info` dzialal bez `sudo`.

## Instalacja Kali/Debian

```bash
cd fm350_portable
sudo fish ./install_fm350.fish --autoconnect yes
```

Instalator uzyje `apt` i zainstaluje:

```text
atinout ethtool usbutils network-manager iproute2
```

Sprawdz NetworkManager:

```bash
systemctl status NetworkManager
```

Po instalacji wyloguj sie i zaloguj ponownie albo zrestartuj system, zeby aktywowac dodanie uzytkownika do grupy portu AT. Do tego czasu `fm350info` moze wymagac `sudo`.

## Konfiguracja

Plik konfiguracyjny:

```text
/etc/fm350-rndis.conf
```

Przyklad:

```sh
FM_IF="auto"
AT_PORT="auto"
APN="internet"
DNS1="1.1.1.1"
DNS2="8.8.8.8"
DNS3="9.9.9.9"
ROUTE_METRIC="100"
AUTOCONNECT="yes"
DISABLE_MODEMMANAGER_FOR_FM350="yes"
```

`FM_IF="auto"` i `AT_PORT="auto"` oznaczaja dynamiczne wykrywanie. `fm350-detect --write-config` zapisuje wykryte wartosci do konfiguracji, zachowujac APN, DNS i metric.

## Tryb automatyczny

Po instalacji:

```bash
sudo nmcli connection up FM350_RNDIS
```

Dispatcher NetworkManager uruchomi `fm350-connect` w tle. Przy rozlaczeniu profilu uruchomi `fm350-disconnect`.

```bash
sudo nmcli connection down FM350_RNDIS
```

## Tryb reczny

```bash
fm350-detect
fm350info
sudo fm350-connect
ip route get 1.1.1.1
sudo fm350-disconnect
```

Test HTTP przez interfejs modemu:

```bash
FM_IF=$(awk -F= '$1=="FM_IF"{gsub(/"/,"",$2); print $2}' /etc/fm350-rndis.conf)
curl -4 --interface "$FM_IF" -I --max-time 20 https://speed.cloudflare.com
```

## Diagnostyka fm350info

Polecenia:

```bash
fm350info
fm350info --raw
fm350info --json
fm350info --log logs/position_A.log
```

Jezeli port AT ma uprawnienia typu `root:uucp 660` albo `root:dialout 660`, a aktualna sesja nie ma jeszcze tej grupy, `fm350info` wypisze komunikat `uruchom sudo fm350info`. Po ponownym logowaniu lub restarcie systemu zwykly uzytkownik powinien miec dostep.

`fm350info` pokazuje:

- operator: `AT+COPS?`
- rejestracja: `AT+CEREG?`, `AT+CGREG?`
- sygnal: `AT+CSQ`, `AT+CESQ`
- komorka/BTS/pasmo: `AT+GTCCINFO?`
- agregacja LTE/5G: `AT+GTCAINFO?`
- obslugiwane tryby/pasma: `AT+GTACT?`
- dane: `AT+CGACT?`, `AT+CGPADDR=1`, `AT+CGCONTRDP=1`
- Linux: adresy, trasa do `1.1.1.1`, `/etc/resolv.conf`

### Interpretacja podstawowych pol

`CSQ`: pierwsza liczba to przyblizony RSSI. `99` oznacza brak danych. Typowe wartosci: im wyzej, tym lepiej.

`CESQ`: rozszerzona jakosc sygnalu. Dla LTE najwazniejsze sa zwykle RSRQ i RSRP w koncowych polach odpowiedzi. Niskie RSRP i bardzo slabe RSRQ beda obnizac stabilnosc i predkosc.

`GTCCINFO`: informacje o aktualnej komorce, m.in. Cell ID, TAC, EARFCN/NR-ARFCN, PCI i kod pasma. Paczka nie geolokalizuje BTS bez bazy danych.

`GTCAINFO`: informacje o agregacji LTE/NR, nosnych skladowych i pasmach. Obecnosc kilku nosnych oznacza CA lub tryb z NR, zalezne od sieci i zasiegu.

`GTACT`: obslugiwane lub skonfigurowane tryby i pasma modemu.

`CGPADDR`: adres IP przydzielony kontekstowi PDP. `fm350-connect` bierze IPv4 z `AT+CGPADDR=1` i ustawia go jako `/32`.

`CGCONTRDP`: szczegoly aktywnego PDP, w tym APN, adresy i parametry operatora.

Prosta mapa pasm w `fm350info`:

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

## Rollback i uninstall

Deinstalacja bez usuwania profilu:

```bash
sudo fish ./uninstall_fm350.fish
```

Deinstalacja z usunieciem profilu `FM350_RNDIS`:

```bash
sudo fish ./uninstall_fm350.fish --remove-profile
```

Skrypt:

- rozlacza `FM350_RNDIS`,
- usuwa dispatchery FM350,
- usuwa narzedzia z `/usr/local/sbin` i `/usr/local/bin`,
- nie rusza `LAN_AC68U`,
- nie usuwa ModemManager,
- probuje przywrocic najnowsze backupy `*.bak_YYYYMMDD_HHMM`.

## Checklist po instalacji

```bash
lsusb
fm350-detect
fm350info
sudo nmcli connection up FM350_RNDIS
ip route get 1.1.1.1
curl -4 --interface <FM_IF> -I --max-time 20 https://speed.cloudflare.com
sudo nmcli connection down FM350_RNDIS
```

Po tescie sprawdz, czy port AT nadal jest urzadzeniem znakowym:

```bash
ls -l /dev/ttyUSB*
```

Oczekiwany typ to `c` na poczatku uprawnien, np. `crw-rw----`.

## Testy platform

### Q370 / Manjaro

```bash
fm350-detect
fm350info
sudo nmcli connection up FM350_RNDIS
sleep 75
ip route get 1.1.1.1
curl -4 --interface "$FM_IF" -I --max-time 20 https://speed.cloudflare.com
sudo nmcli connection down FM350_RNDIS
```

Sprawdz, czy trasa domyslna wraca na LAN oraz czy `/dev/ttyUSB3` nadal jest `crw-rw----`, jezeli to byl wykryty port.

### Dell Precision 7510 / Manjaro

Nie wpisuj recznie `/dev/ttyUSB3`. Nie maskuj globalnie ModemManager, bo w laptopie moze byc wewnetrzny modem LTE, np. Dell DW5821e. Wykrywanie FM350 odbywa sie po USB ID `0e8d:7127` lub `0e8d:7126`.

```bash
fm350-detect
fm350info
sudo fm350-connect
sudo fm350-disconnect
```

### Dell 7220 / Kali

```bash
sudo apt install atinout ethtool usbutils network-manager iproute2
systemctl status NetworkManager
fm350-detect
sudo fm350-connect
curl -4 --interface <FM_IF> -I --max-time 20 https://speed.cloudflare.com
sudo fm350-disconnect
```

## Test porownawczy pozycji modemu

Nie wykonuj wielu speedtestow bez kontroli pakietu danych.

1. Pozycja A: biurko
2. Pozycja B: okno od strony nadajnika
3. Pozycja C: inne okno

Dla kazdej pozycji:

```bash
mkdir -p logs
fm350info --log logs/position_A.log
```

Zapisz wynik Cloudflare Speed Test:

- download
- upload
- latency
- jitter
- packet loss

Porownuj wyniki razem z `GTCCINFO`, `GTCAINFO`, `CSQ`, `CESQ`, Cell ID, TAC, EARFCN/NR-ARFCN i PCI. Bez zewnetrznej bazy BTS nie wyciagaj wnioskow o fizycznej lokalizacji nadajnika.
