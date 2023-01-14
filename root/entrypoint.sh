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

# Configure stuff
for CONF in ${CONFS[@]}
    do
        if ! [ -f /data/"$CONF" ]; then
            echo "Copying /etc/$CONF to /data/$CONF"
            mkdir -p /data/$CONF && rmdir /data/$CONF
            cp -r /etc/$CONF /data/$CONF
        fi
    done

. /etc/vpn/util/common.sh
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
    _healthcheck_vpn & \
    wait -n
fi

