# FM350 -> LAN: jednokierunkowy failover po ~60 s

## Cel

Jeżeli FM350 pozostaje logicznie aktywny (RNDIS/PDN/IP istnieją), ale rzeczywisty Internet przez modem nie działa, preferowana trasa domyślna przez FM350 może blokować działający LAN.

Watchdog `fm350-failover` ma temu zapobiec.

## Zasada działania

- działa tylko wtedy, gdy FM350 jest aktualną trasą domyślną;
- wykrywa aktualny interfejs FM350 przez `fm350-detect` (bez stałej nazwy typu `enp0s20f0u3`);
- co 15 s wykonuje mały test ICMP przez interfejs FM350;
- testuje `1.1.1.1`, a następnie `9.9.9.9`;
- krótkie zawieszenia 5G nie powodują natychmiastowego przełączenia;
- po około 60 s ciągłej niedostępności i przy istnieniu alternatywnej trasy domyślnej usuwa wyłącznie trasę `default` przez FM350;
- Linux przechodzi wtedy na istniejący LAN (w aktualnej konfiguracji P7510 LAN ma niższą metrykę niż Wi-Fi);
- watchdog nie wykonuje automatycznego powrotu na 5G.

Powrót na FM350 jest ręczny, np. przez `5gon`.

## Konfiguracja

W `/etc/fm350-rndis.conf`:

```text
FAILOVER_ENABLE="yes"
FAILOVER_AFTER_SECONDS="60"
FAILOVER_CHECK_INTERVAL="15"
FAILOVER_PING_TIMEOUT="2"
```

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
