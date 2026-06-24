function 5greset
    echo "===== 5G RESET / SAFE MODE ====="

    sudo -v; or return 1

    echo
    echo "===== 1. CLEAN LOCAL STATE ====="
    sudo nmcli connection down FM350_RNDIS 2>/dev/null
    sudo MANAGE_DNS=no fm350-disconnect 2>/dev/null
    rm -f /tmp/fm350_radio_status
    sudo pkill -f "atinout.*fm350-at" 2>/dev/null
    sudo pkill -f "atinout.*ttyUSB" 2>/dev/null

    echo
    echo "===== 2. AT PROBE ====="
    if not test -c /dev/fm350-at
        echo "BRAK /dev/fm350-at"
        echo "RESET_RESULT=REPLUG_REQUIRED"
        return 2
    end

    set -l probe1 (printf "AT\r\n" | sudo timeout 8s atinout - /dev/fm350-at - 2>/dev/null | string collect)
    sleep 1
    set -l probe2 (printf "ATE0\r\n" | sudo timeout 8s atinout - /dev/fm350-at - 2>/dev/null | string collect)
    set -l probe3 (printf "AT\r\n" | sudo timeout 8s atinout - /dev/fm350-at - 2>/dev/null | string collect)
    printf "%s\n%s\n%s\n" "$probe1" "$probe2" "$probe3" | grep -Ev 'IMEI|IMSI|ICCID|[0-9]{15}' | cat -v

    if not string match -q "*OK*" -- "$probe3"
        echo
        echo "AT nie odpowiada. Wymagane fizyczne odłączenie/podłączenie FM350."
        echo "RESET_RESULT=AT_DEAD_REPLUG_REQUIRED"
        return 3
    end

    echo
    echo "===== 3. PDP RESET ====="
    printf "ATE0\r\nAT+CGACT=0,1\r\nAT+CGDCONT=1,\"IPV4V6\",\"internet\"\r\nAT+CGACT=1,1\r\nAT+CGPADDR=1\r\n" \
    | sudo timeout 45s atinout - /dev/fm350-at - 2>/dev/null \
    | grep -Ev "IMEI|IMSI|ICCID|[0-9]{15}" \
    | cat -v

    echo
    echo "RESET_RESULT=SAFE_PDP_DONE"
end
