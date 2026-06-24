function 5goff
    echo "===== 5G OFF / FM350_RNDIS ====="
    sudo nmcli connection down FM350_RNDIS

    sudo MANAGE_DNS=no fm350-disconnect
    set -l dis_st $status

    rm -f /tmp/fm350_radio_status

    sleep 2

    echo
    echo "===== ROUTE ====="
    ip route get 1.1.1.1

    echo
    echo "===== ADDR ====="
    ip -br addr show enp0s20f0u3

    echo
    fm350_radio_status

    return $dis_st
end
