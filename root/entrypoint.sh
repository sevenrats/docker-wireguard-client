#!/usr/bin/env bash

# Proxy Signals
sp_processes=("tinyproxy")
. /signalproxy.sh
_term() { 
  echo "Caught a termination signal!"
  # there is a bug here where if we lack permission we are stuck because we can't term
  pkill -TERM tinyproxy
  wg-quick down wg0
}

trap _term SIGTERM
trap _term SIGINT
trap _term SIGQUIT
trap _term SIGHUP

_bind_port () {
    # providers that require periodic port binding will overload this.
    # providers that don't can ignore it
    return 0
}

_health_vpn () {
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
            echo "WAITING FOR BINDPORT TIMER: $bindport_timer"
            bindport_timer=$(($bindport_timer - $interval))
        else
            echo "BINDING PORT BEACUSE THE BINDPORT TIMER IS $bindport_timer"
            if _bind_port; then
                bindport_timer=$bindport_timer_reset
            else
                echo "bindport failed.  this server is for the birds."
                wg-quick down wg0
                _connect
            fi
        fi

    done
    return 1
}


# Configure stuff
for CONF in ${CONFS[@]}
    do
        if ! [ -f /data/"$CONF" ]; then
            echo "Copying /etc/$CONF to /data/$CONF"
            mkdir -p /data/$CONF && rmdir /data/$CONF
            cp -r /etc/$CONF /data/$CONF
        fi
    done

file=/etc/vpn/util/peer.conf
_configure () {
    eval "
cat <<EOF
`cat $file`
EOF"
}

_connect () {
    readarray -t CONNECTIONS < <(cat $CONFPATH | jq -c '.[]')
    CONNECTION=${CONNECTIONS[$(($RANDOM % ${#CONNECTIONS[@]}))]}
    PROVIDER=$(echo "$CONNECTION" | jq -r '.Provider')
    echo "THE PROVIDER IS $PROVIDER"
    case "$PROVIDER" in
        "PrivateInternetAccess" ) 
            . /etc/vpn/provider/pia/pia.sh
            export InitialPortForwardDone=false;;
        "Mullvad" ) . /etc/vpn/provider/mullvad/mullvad.sh;;
        "AirVPN" ) echo "Not yet implemented";;
    esac;
    VALUES=$(_provider $CONNECTION)
    WG_CONFIG=$(_configure $VALUES)
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

WG_CONFIG_PATH="/data/vpn/wg0.conf"
CONNECTED=false
CONFPATH=/data/vpn/bucket.conf

if  ! [ -f $CONFPATH ]; then
    echo "JUST A REGULAR VPN CLIENT"
    # Just a regular vpn client
    wg-quick up wg0 &&
    tinyproxy -dc /data/tinyproxy/tinyproxy.conf & \
    wait -n
else
    until $CONNECTED
    do
        _connect
    done
    tinyproxy -dc /data/tinyproxy/tinyproxy.conf & \
    _health_vpn & \
    wait -n
fi

