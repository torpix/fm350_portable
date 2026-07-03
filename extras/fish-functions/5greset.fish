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
    echo "===== 2. DISABLE USB AUTOSUSPEND ====="
    for usb_dev in /sys/bus/usb/devices/*
        if test -f "$usb_dev/idVendor"; and test -f "$usb_dev/idProduct"
            set -l id_vendor (cat "$usb_dev/idVendor" 2>/dev/null)
            set -l id_product (cat "$usb_dev/idProduct" 2>/dev/null)
            if test "$id_vendor" = "0e8d"; and test "$id_product" = "7127"
                if test -f "$usb_dev/power/control"
                    echo on | sudo tee "$usb_dev/power/control" >/dev/null
                end
                if test -f "$usb_dev/power/autosuspend_delay_ms"
                    echo -1 | sudo tee "$usb_dev/power/autosuspend_delay_ms" >/dev/null
                end
            end
        end
    end

    echo
    echo "===== 3. TTY WAKE ====="
    if not test -c /dev/fm350-at
        echo "BRAK /dev/fm350-at"
        echo "RESET_RESULT=REPLUG_REQUIRED"
        return 2
    end

    set -l stty_log (mktemp)
    sudo stty -F /dev/fm350-at 115200 raw -echo -ixon -ixoff -crtscts clocal cread min 0 time 10 2>$stty_log
    set -l stty_status $status
    echo "STTY_STATUS=$stty_status"
    if test -s $stty_log
        cat $stty_log
    end
    rm -f $stty_log

    printf "\r\rAT\rATE0\rAT\r" | sudo tee /dev/fm350-at >/dev/null
    sleep 2

    echo
    echo "===== 4. AT PROBE ====="

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
    echo "===== 5. PDP RESET ====="
    printf "ATE0\r\nAT+CGACT=0,1\r\nAT+CGDCONT=1,\"IPV4V6\",\"internet\"\r\nAT+CGACT=1,1\r\nAT+CGPADDR=1\r\n" \
    | sudo timeout 45s atinout - /dev/fm350-at - 2>/dev/null \
    | grep -Ev "IMEI|IMSI|ICCID|[0-9]{15}" \
    | cat -v

    echo
    echo "RESET_RESULT=SAFE_PDP_DONE"
end
