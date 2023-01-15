WG_CONFIG_PATH="/data/vpn/wg0.conf"
CONNECTED=false
CONFPATH=/data/vpn/bucket.conf

_bind_port () {
    # providers that require periodic port binding will overload this.
    # providers that don't can ignore it
    return 0
}

printServerLatency () {
    serverIP=$1
    regionID=$2
    time=$(LC_NUMERIC=en_US.utf8 curl -o /dev/null -s \
        --connect-timeout "5" \
        --write-out "%{time_connect}" \
        "http://$serverIP" | tr -d '"')
    if [ $time > 0 ]; then
        #>&2 echo "Got latency ${time}s for region: $regionID"
        echo "$time $regionID"
    fi
    # Sort the latencyList, ordered by latency
    #sort -no /tmp/latency /tmp/latency
}
export -f printServerLatency

_connected () {
    choices=( "amazon.com" "google.com" "facebook.com" "microsoft.com" )
    choice=${choices[$(($RANDOM % ${#choices[@]}))]}
    if curl -s $choice > /dev/null; then
        return 0
    else
        return 1
    fi
}

_configure () {
    s=$(eval "
cat <<EOF
`cat /etc/vpn/util/peer.conf`
EOF")
    echo "$s"
}

_healthcheck_vpn () {
    local interval=15 # tick tock
    local bindport_timer_reset=840
    local bindport_timer=$bindport_timer_reset
    while true;
    do
        sleep $interval

        if _connected; then
            echo "The VPN HealthCheck is running! You are connected."
        else
            wg-quick down wg0
            _connect
        fi

        if [ $bindport_timer -gt 0 ]; then
            bindport_timer=$(($bindport_timer - $interval))
        else
            if _bind_port; then
                bindport_timer=$bindport_timer_reset
            else
                echo "bindport failed.  this server is for the birds."
                CONNECTED=false
                wg-quick down wg0
                until $CONNECTED
                do
                    _connect
                done
                _connect
            fi
        fi

    done
    return 1
}

_connect () {
    # reset variables and overloaded functions
    . /etc/vpn/util/common.sh
    # read the vpn hint dictionary into an array
    readarray -t CONNECTIONS < <(cat $CONFPATH | jq -c '.[]')
    # select a random provider to get started
    CONNECTION=${CONNECTIONS[$(($RANDOM % ${#CONNECTIONS[@]}))]}
    # import that provider to overload necessary functions
    PROVIDER=$(echo "$CONNECTION" | jq -r '.Provider')
    echo "The provider is $PROVIDER"
    case "$PROVIDER" in
        "PrivateInternetAccess" ) . /etc/vpn/provider/pia/pia.sh && export InitialPortForwardDone=false;;
        "Mullvad" ) . /etc/vpn/provider/mullvad/mullvad.sh;;
        "AirVPN" ) . /etc/vpn/provider/airvpn/airvpn.sh;;
    esac;
    WG_CONFIG=$(_provider $CONNECTION)
    echo "$WG_CONFIG"
    echo "$WG_CONFIG" > $WG_CONFIG_PATH
    wg-quick up wg0
    sleep 2
    if ! _connected; then
        sleep infinity
        wg-quick down wg0
        return 1
    else
        CONNECTED=true
        return 0
    fi
}