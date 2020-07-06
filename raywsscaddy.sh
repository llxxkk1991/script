#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
# Usage:  debian 10 one_key for caddy2 tls websocket vmess v2ray
# install: bash <(curl -s https://raw.githubusercontent.com/mixool/script/debian-9/raywsscaddy.sh) my.domain.com
# uninstall: apt purge caddy -y; rm -rf /etc/apt/sources.list.d/caddy-fury.list; bash <(curl -L -s https://install.direct/go.sh) --remove; rm -rf /etc/v2ray/config.json

# install caddy
apt update && apt install apt-transport-https ca-certificates -y
rm -rf /etc/apt/sources.list.d/caddy-fury.list
echo "deb [trusted=yes] https://apt.fury.io/caddy/ /" | tee -a /etc/apt/sources.list.d/caddy-fury.list
apt update && apt install caddy -y

# install v2ray
bash <(curl -L -s https://install.direct/go.sh)

########
domain="$1"
vport=$(shuf -i 10000-65535 -n1)
uuid=$(/usr/bin/v2ray/v2ctl uuid)
path=$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)
########

# config caddy
cat <<EOF >/etc/caddy/Caddyfile
$domain

root * /usr/share/caddy

file_server

@websockets_$path {
header Connection Upgrade
header Upgrade websocket
path /$path
}
reverse_proxy @websockets_$path localhost:$vport
EOF

# config v2ray
cat <<EOF >/etc/v2ray/config.json
{
    "inbounds": 
    [
        {
            "port": $vport,"listen":"127.0.0.1","protocol": "vmess",
            "settings": {"clients": [{"id": "$uuid"}]},
            "streamSettings": {"network": "ws","wsSettings": {"path": "/$path"}}
        }
    ],
    
    "outbounds": 
    [
        {"protocol": "freedom","settings": {}},
        {"protocol": "blackhole","tag": "blocked","settings": {}}
    ],
    
    "routing": 
    {
        "rules": 
        [
            {"type": "field","outboundTag": "blocked","ip": ["geoip:private"]}
        ]
    }
}
EOF

# systemctl service 
systemctl enable caddy && systemctl restart caddy && systemctl status caddy
systemctl enable v2ray && systemctl restart v2ray && systemctl status v2ray

# info
cat <<EOF >/tmp/$path
        {
            "protocol": "vmess",
            "tag": "$domain",
            "settings": {"vnext": [{"address": "$domain","port": 443,"users": [{"id": "$uuid"}]}]},
            "streamSettings": {"network": "ws","security": "tls","tlsSettings": {"allowInsecure": false,"serverName": "$domain"},"wsSettings": {"path": "/$path","headers": {"Host": "$domain"}}}
        }
EOF

cat /tmp/$path && rm -rf /tmp/$path

# done
