function 5gon
    echo "===== 5G ON / FM350_RNDIS ====="
    sudo -v; or return 1

    sudo nmcli connection up FM350_RNDIS

    set -l ip4 ""
    for i in (seq 1 12)
        set ip4 (ip -o -4 addr show enp0s20f0u3 2>/dev/null | awk '{print $4}' | head -n 1)
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
    set ip4 (ip -o -4 addr show enp0s20f0u3 2>/dev/null | awk '{print $4}' | head -n 1)
    ip -br addr show enp0s20f0u3

    if not string match -q '* dev enp0s20f0u3 *' -- "$route"; or not string match -qr '^10\..*/32$' -- "$ip4"
        echo "ROUTE_NOT_FM350"
        return 2
    end

    echo
    echo "===== RADIO REFRESH ====="
    5ginfo; or return $status

    return 0
end
