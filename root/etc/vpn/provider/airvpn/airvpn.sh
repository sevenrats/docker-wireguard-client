_provider () {
    all_servers=$(curl -s "https://airvpn.org/api/status/")
    filtered_servers=$(echo $all_servers | jq -r '.servers[] | select(.country_name=="United States" and .health=="ok" and .currentload<25)| .ip_v4_in4+" "+.public_name' | tr '[:upper:]' '[:lower:]')
    server="$(echo "$filtered_servers" | xargs -P 8 -I{} bash -c 'printServerLatency {}' | sort | head -1 | awk '{ print $2 }')"
    echo $server
}