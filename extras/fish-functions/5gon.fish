function 5gon
    echo "===== 5G ON / FM350_RNDIS ====="
    sudo -v; or return 1

    set -l detected (fm350-detect 2>/dev/null | string collect)
    set -l fm_if (printf "%s\n" "$detected" | awk -F= '$1=="FM_IF"{print $2}')

    if test -z "$fm_if"
        echo "FM350 interface not detected"
        return 1
    end

    sudo nmcli connection modify FM350_RNDIS connection.interface-name "$fm_if" 2>/dev/null; or true
    sudo nmcli connection up FM350_RNDIS 2>/dev/null; or true

    set -l ip4 ""
    for i in (seq 1 12)
        set ip4 (ip -o -4 addr show "$fm_if" 2>/dev/null | awk '{print $4}' | head -n 1)
        if string match -qr '^10\..*/32$' -- "$ip4"
            break
        end
        sleep 1
    end

    if not string match -qr '^10\..*/32$' -- "$ip4"
        echo "===== FM350 CONNECT FALLBACK ====="
        sudo MANAGE_DNS=no fm350-connect; or return $status
    end

    echo
    echo "===== ROUTE ====="
    set -l route (ip route get 1.1.1.1 2>/dev/null | string collect)
    printf "%s\n" "$route"

    echo
    echo "===== ADDR ====="
    set ip4 (ip -o -4 addr show "$fm_if" 2>/dev/null | awk '{print $4}' | head -n 1)
    ip -br addr show "$fm_if"

    if not string match -q "* dev $fm_if *" -- "$route"; or not string match -qr '^10\..*/32$' -- "$ip4"
        echo "ROUTE_NOT_FM350"
        return 2
    end

    echo
    echo "===== RADIO REFRESH ====="
    5ginfo; or return $status

    return 0
end
