function 5goff
    echo "===== 5G OFF / FM350_RNDIS ====="

    set -l detected (fm350-detect 2>/dev/null | string collect)
    set -l fm_if (printf "%s\n" "$detected" | awk -F= '$1=="FM_IF"{print $2}')

    sudo nmcli connection down FM350_RNDIS 2>/dev/null; or true

    sudo MANAGE_DNS=no fm350-disconnect
    set -l dis_st $status

    rm -f /tmp/fm350_radio_status

    sleep 2

    echo
    echo "===== ROUTE ====="
    ip route get 1.1.1.1

    echo
    echo "===== ADDR ====="
    if test -n "$fm_if"
        ip -br addr show "$fm_if" 2>/dev/null; or true
    else
        echo "FM350 interface not detected"
    end

    echo
    fm350_radio_status

    return $dis_st
end
