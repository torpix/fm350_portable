function fm350_radio_status
    set -l tmp /tmp/fm350_radio_status

    set -l rat UNKNOWN
    set -l band "-"
    set -l rsrp "-"
    set -l rsrq "-"
    set -l sinr "-"
    set -l rssi "-"

    if test -f "$tmp"
        for line in (cat "$tmp")
            set -l parts (string split -m1 "=" -- "$line")
            test (count $parts) -ge 2; or continue

            set -l key $parts[1]
            set -l val "$parts[2]"

            switch "$key"
                case RAT
                    set rat "$val"
                case BAND
                    set band "$val"
                case RSRP
                    set rsrp "$val"
                case RSRQ
                    set rsrq "$val"
                case SINR
                    set sinr "$val"
                case RSSI
                    set rssi "$val"
            end
        end
    end

    set -l q 0
    set -l rsrp_num (string replace -r " .*" "" -- "$rsrp")

    if string match -qr "^-?[0-9]+" -- "$rsrp_num"
        if test $rsrp_num -ge -80
            set q 100
        else if test $rsrp_num -ge -90
            set q 80
        else if test $rsrp_num -ge -100
            set q 60
        else if test $rsrp_num -ge -110
            set q 40
        else
            set q 20
        end
    end

    set -l bars_count (math --scale=0 "$q / 10")
    set -l bar ""

    for i in (seq 1 10)
        if test $i -le $bars_count
            set bar "$bar#"
        else
            set bar "$bar-"
        end
    end

    set -l rsrp_out "$rsrp"
    set -l rsrq_out "$rsrq"
    set -l sinr_out "$sinr"
    set -l rssi_out "$rssi"

    if string match -qr "^-?[0-9]+" -- "$rsrp_out"
        set rsrp_out "$rsrp_out dBm"
    end
    if string match -qr "^-?[0-9]+" -- "$rsrq_out"
        set rsrq_out "$rsrq_out dB"
    end
    if string match -qr "^-?[0-9]+" -- "$sinr_out"
        set sinr_out "$sinr_out dB"
    end
    if string match -qr "^-?[0-9]+" -- "$rssi_out"
        set rssi_out "$rssi_out dBm"
    end

    echo "RADIO:"
    echo "  RAT:   $rat     BAND: $band"
    echo "  RSRP:  $rsrp_out    RSRQ: $rsrq_out"
    echo "  SINR:  $sinr_out    RSSI: $rssi_out"
    echo "  Q:     [$bar] $q%"
end
