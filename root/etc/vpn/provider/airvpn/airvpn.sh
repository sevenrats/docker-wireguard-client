_provider () {
    #devicename, apikey, portnumber
    API=$(echo "$1" | jq -r '.API')
    DEVICE=$(echo "$1" | jq -r '.Device')
    PORT=$(echo "$1" | jq -r '.Port')
    all_servers=$(curl -s "https://airvpn.org/api/status/")
    filtered_servers=$(echo $all_servers | jq -r '.servers[] | select(.country_name=="United States" and .health=="ok" and .currentload<25)| .ip_v4_in4+" "+.public_name' | tr '[:upper:]' '[:lower:]')
    server="$(echo "$filtered_servers" | xargs -P 8 -I{} bash -c 'printServerLatency {}' | sort | head -1 | awk '{ print $2 }')"
    conf=$(curl -s -H "API-KEY:${API}" "https://airvpn.org/api/generator/?protocols=wireguard_1_udp_1637&servers=$server&device=$DEVICE&wireguard_mtu=0&wireguard_persistent_keepalive=15&iplayer_exit=ipv4")
    echo $port > /data/vpn/port.dat
    echo "$conf"
}