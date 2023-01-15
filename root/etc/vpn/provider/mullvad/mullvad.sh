_provider () { 
    ACCOUNT=$(echo "$1" | jq -r '.Account')
    PRIVATEKEY=$(echo "$1" | jq -r '.PrivateKey')
    PUBKEY=$(wg pubkey <<<${PRIVATEKEY})
    # we could implement multihop fairly trivially by selecting serverkey and multihop port from our target city and then finding the closest one
    # args are ACCOUNT_NUMBER, PRIVATE KEY
    account=$(curl -fsSL https://api.mullvad.net/www/accounts/$ACCOUNT)
    city_code=$(echo $account | jq -r --arg wgkey $PUBKEY '.account.city_ports[] | select(.wgkey==$wgkey) | .city_code ' | sed 's/.*-//' ) 
    all_servers=$(curl --get -s https://api.mullvad.net/www/relays/wireguard/ | jq )
    _candidates=$(echo $all_servers | jq -c --arg city_code $city_code '.[] | select(.city_code == $city_code) ' )
    readarray -t candidates < <(echo "${_candidates[@]}")
    candidate=${candidates[$(($RANDOM % ${#candidates[@]}))]}
    address=$(echo $account | jq -r --arg pubkey $PUBKEY '.account.wg_peers[] | select(.key.public==$pubkey ) | .ipv4_address ')
    dns="193.138.218.74"
    serverkey=$(echo $candidate | jq -r .pubkey)
    endpoint=$(echo $candidate | jq -r .ipv4_addr_in):$(echo $candidate | jq .multihop_port)
    allowedips="0.0.0.0/0"
    port=$(echo $account | jq -r --arg pubkey $PUBKEY '.account.wg_peers[] | select(.key.public==$pubkey ) | .city_ports[0].port')
    echo $port > /data/vpn/port.dat
    echo "$(_configure $address $PRIVATEKEY $dns 15 $serverkey $endpoint $allowedips)"
}
