# FM350 -> LAN: jednokierunkowy failover po 3 nieudanych testach

## Cel

Jeżeli FM350 pozostaje logicznie aktywny (RNDIS/PDN/IP istnieją), ale rzeczywisty Internet przez modem nie działa, preferowana trasa domyślna przez FM350 może blokować działający LAN.

Watchdog `fm350-failover` ma temu zapobiec.

## Zasada działania

- działa tylko wtedy, gdy FM350 jest aktualną trasą domyślną;
- wykrywa aktualny interfejs FM350 przez `fm350-detect` (bez stałej nazwy typu `enp0s20f0u3`);
- co 20 s wykonuje mały test ICMP przez interfejs FM350;
- testuje `1.1.1.1`, a następnie `9.9.9.9`;
- PASS nie jest logowany;
- pierwszy FAIL zapisuje tylko pojedynczy wpis `SUSPECT`;
- drugi kolejny FAIL nie jest logowany;
- trzeci kolejny FAIL powoduje failover, jeżeli istnieje alternatywna trasa domyślna;
- failover usuwa wyłącznie trasę `default` przez FM350;
- Linux przechodzi wtedy na istniejący LAN (w aktualnej konfiguracji P7510 LAN ma niższą metrykę niż Wi-Fi);
- po wykonaniu failoveru zapisywany jest pojedynczy wpis końcowy z nową trasą;
- watchdog nie wykonuje automatycznego powrotu na 5G.

Powrót na FM350 jest ręczny, np. przez `5gon`.

## Konfiguracja

W `/etc/fm350-rndis.conf`:

```text
FAILOVER_ENABLE="yes"
FAILOVER_CHECK_INTERVAL="20"
FAILOVER_FAIL_COUNT="3"
FAILOVER_PING_TIMEOUT="2"
```

## Logowanie

Przy normalnej pracy i poprawnym 5G watchdog nie dopisuje wpisów dla kolejnych testów PASS.

Jedna typowa awaria generuje tylko:

```text
SUSPECT ... count=1/3
FAILOVER ... failed_checks=3 ...
```

Jeżeli nie istnieje alternatywna trasa domyślna, failover jest blokowany i zapisywany jest pojedynczy `FAILOVER_BLOCKED` dla danego incydentu.

## Usługa

```sh
systemctl status fm350-failover.service
journalctl -u fm350-failover.service
```

Dodatkowy log:

```text
/tmp/fm350-failover.log
```

## Ważne

Failover jest celowo jednokierunkowy. Watchdog nie dodaje ponownie trasy FM350 po odzyskaniu sieci komórkowej. Ma chronić zdalny dostęp do hosta (np. WireGuard/reverse SSH) przed sytuacją, w której martwy data-path 5G pozostawia aktywną preferowaną trasę domyślną.
