function 5ginfo
    set -l at_port /dev/fm350-at
    set -l tmp /tmp/fm350_radio_status

    if not test -c "$at_port"
        rm -f "$tmp"
        echo "BRAK /dev/fm350-at"
        echo "reason: AT_NO_RESPONSE"
        fm350_radio_status
        return 1
    end

    sudo -v; or return 1

    set -l probe1 (printf "AT\r\n" | sudo timeout 8s atinout - "$at_port" - 2>/dev/null | sed '/^[[:space:]]*$/d' | string collect)
    sleep 1
    set -l probe2 (printf "ATE0\r\n" | sudo timeout 8s atinout - "$at_port" - 2>/dev/null | sed '/^[[:space:]]*$/d' | string collect)
    set -l probe3 (printf "AT\r\n" | sudo timeout 8s atinout - "$at_port" - 2>/dev/null | sed '/^[[:space:]]*$/d' | string collect)

    if not string match -q '*OK*' -- "$probe3"
        rm -f "$tmp"
        echo "RADIO UNKNOWN"
        echo "reason: AT_NO_RESPONSE"
        echo
        echo "RAW:"
        printf "%s\n%s\n%s\n" "$probe1" "$probe2" "$probe3" | grep -Ev 'IMEI|IMSI|ICCID|[0-9]{15}'
        return 1
    end

    set -l raw (printf "AT+COPS?\r\nAT+CSQ\r\nAT+CESQ\r\n" | sudo timeout 12s atinout - "$at_port" - 2>/dev/null | sed '/^[[:space:]]*$/d' | grep -Ev 'IMEI|IMSI|ICCID|[0-9]{15}' | string collect)

    set -l cops (printf "%s\n" "$raw" | string match -r '\+COPS:.*')
    set -l csq (printf "%s\n" "$raw" | string match -r '\+CSQ:.*')
    set -l cesq (printf "%s\n" "$raw" | string match -r '\+CESQ:.*')

    set -l rat UNKNOWN
    set -l band "-"
    set -l rsrp "-"
    set -l rsrq "-"
    set -l sinr "-"
    set -l rssi "-"

    if string match -qr ',13' -- "$cops"
        set rat "LTE/NR"
    else if string match -qr ',7' -- "$cops"
        set rat "LTE"
    else if string match -qr ',2' -- "$cops"
        set rat "UMTS"
    else if string match -qr ',0' -- "$cops"
        set rat "GSM"
    end

    if string match -qr '\+CSQ:\s*([0-9]+),' -- "$csq"
        set -l csq_val (string replace -r '.*\+CSQ:\s*([0-9]+),.*' '$1' -- "$csq")
        if test "$csq_val" != "99"
            set rssi (math --scale=0 "-113 + 2 * $csq_val")
        end
    end

    if string match -qr '\+CESQ:' -- "$cesq"
        set -l vals (string replace -r '.*\+CESQ:\s*' '' -- "$cesq" | string split ",")
        if test (count $vals) -ge 6
            set -l rsrq_raw $vals[5]
            set -l rsrp_raw $vals[6]

            if test "$rsrq_raw" != "255"
                set rsrq (math --scale=1 "-19.5 + 0.5 * $rsrq_raw")
            end

            if test "$rsrp_raw" != "255"
                set rsrp (math --scale=0 "-140 + $rsrp_raw")
            end
        end
    end

    begin
        printf "%s\n" "RAT=$rat"
        printf "%s\n" "BAND=$band"
        printf "%s\n" "RSRP=$rsrp"
        printf "%s\n" "RSRQ=$rsrq"
        printf "%s\n" "SINR=$sinr"
        printf "%s\n" "RSSI=$rssi"
    end > "$tmp"

    fm350_radio_status

    echo
    echo "RAW:"
    printf "%s\n" "$raw"
end
