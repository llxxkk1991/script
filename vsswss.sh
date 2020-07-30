#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
# Usage:  debian 9/10 one_key for caddy2 tls websocket vmess v2ray
# install: bash <(curl -s https://raw.githubusercontent.com/mixool/script/debian-9/vsswss.sh) my.domain.com
# uninstall: apt purge caddy -y; rm -rf /etc/apt/sources.list.d/caddy-fury.list; bash <(curl https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) --remove; rm -rf /usr/local/etc/v2ray/config.json

# tempfile & rm it when exit
trap 'rm -f "$TMPFILE"' EXIT
TMPFILE=$(mktemp) || exit 1

########
[[ $# != 1 ]] && echo Err !!! Useage: bash this_script.sh my.domain.com && exit 1 || domain="$1"

ssport=$(shuf -i 10000-65535 -n1)
vmessport=$(shuf -i 10000-65535 -n1)
until [[ $ssport != $vmessport ]]; do vmessport=$(shuf -i 10000-65535 -n1); done

path_wssss=$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)
path_vmess=$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)

uuid=$(/usr/local/bin/v2ctl uuid)

ssmethod="aes-128-gcm"
sspasswd=$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)
########

# install caddy
apt update && apt install apt-transport-https ca-certificates -y
rm -rf /etc/apt/sources.list.d/caddy-fury.list
echo "deb [trusted=yes] https://apt.fury.io/caddy/ /" | tee -a /etc/apt/sources.list.d/caddy-fury.list
apt update && apt install caddy -y

# install v2ray
bash <(curl https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)

# config caddy
cat <<EOF >/etc/caddy/Caddyfile
$domain

root * /usr/share/caddy

file_server

header {
X-Content-Type-Options nosniff
X-Frame-Options DENY
Referrer-Policy no-referrer-when-downgrade
}

@websockets_$path_wssss {
header Connection *Upgrade*
header Upgrade    websocket
path /$path_wssss
}

@websockets_$path_vmess {
header Connection *Upgrade*
header Upgrade    websocket
path /$path_vmess
}
reverse_proxy @websockets_$path_wssss localhost:$ssport
reverse_proxy @websockets_$path_vmess localhost:$vmessport
EOF

# config v2ray
cat <<EOF >/usr/local/etc/v2ray/config.json
{
    "inbounds": 
    [
        {
            "port": $vmessport,"listen":"127.0.0.1","protocol": "vmess",
            "settings": {"clients": [{"id": "$uuid"}]},
            "streamSettings": {"network": "ws","wsSettings": {"path": "/$path_vmess"}}
        },
        {
            "port": $ssport,"listen":"127.0.0.1","protocol": "shadowsocks",
            "settings": {"method": "$ssmethod","password": "$sspasswd","network": "tcp,udp"},
            "streamSettings": {"network": "ws","wsSettings": {"path": "/$path_wssss"}}
        }
    ],
    
    "outbounds": 
    [
        {"protocol": "freedom","tag": "direct","settings": {}},
        {"protocol": "blackhole","tag": "blocked","settings": {}}
    ],
    "routing": 
    {
        "domainStrategy": "IPIfNonMatch",
        "rules": 
        [
            {"type": "field","outboundTag": "blocked","ip": ["geoip:private"]},
            {"type": "field","outboundTag": "blocked","domain": ["geosite:category-ads-all"]}
        ]
    }
}
EOF

# systemctl service info
echo; echo $(date) caddy status:
systemctl enable caddy && systemctl restart caddy && sleep 3 && systemctl status caddy | more
echo; echo $(date) v2ray status:
systemctl enable v2ray && systemctl restart v2ray && sleep 3 && systemctl status v2ray | more

# info
echo; echo $(date) v2ray config info:
cat <<EOF >$TMPFILE
        {
            "protocol": "vmess",
            "tag": "vmess_$domain",
            "settings": {"vnext": [{"address": "$domain","port": 443,"users": [{"id": "$uuid"}]}]},
            "streamSettings": {"network": "ws","security": "tls","tlsSettings": {"allowInsecure": false,"serverName": "$domain"},"wsSettings": {"path": "/$path_vmess","headers": {"Host": "$domain"}}}
        },

        {
            "protocol": "shadowsocks",
            "tag": "wssss_$domain",
            "settings": {"servers":[{"address": "$domain","port": 443,"method": "$ssmethod","password": "$sspasswd"}]},
            "streamSettings": {"network": "ws","security": "tls","tlsSettings": {"allowInsecure": false,"serverName": "$domain"},"wsSettings": {"path": "/$path_wssss","headers": {"Host": "$domain"}}}
        },
EOF

cat $TMPFILE
# done
