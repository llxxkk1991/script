#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
# Usage:  debian 9/10 one_key for caddy2 tls websocket vmess v2ray
# install: bash <(curl -s https://raw.githubusercontent.com/mixool/script/debian-9/vsswss.sh) my.domain.com
# uninstall: apt purge caddy -y; rm -rf /etc/apt/sources.list.d/caddy-fury.list; bash <(curl https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) --remove; rm -rf /usr/local/etc/v2ray /var/log/v2ray
## Tips: 同时配置了三种模式: wss+ss wss+vmess h2+vmess, 如不需要可在安装完成后删除(caddy|v2ray)配置文件中相关代码后重启服务即可. h2模式目前需要自己编译最新caddy

# tempfile & rm it when exit
trap 'rm -f "$TMPFILE"' EXIT
TMPFILE=$(mktemp) || exit 1

########
[[ $# != 1 ]] && echo Err !!! Useage: bash this_script.sh my.domain.com && exit 1 || domain="$1"

wss_ss_port=$(shuf -i 10000-65535 -n1)
wss_vmess_port=$(shuf -i 10000-65535 -n1)
h2s_vmess_port=$(shuf -i 10000-65535 -n1)

wss_ss_path=$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)
wss_vmess_path=$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)
h2s_vmess_path=$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)

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
wss_uuid=$(/usr/local/bin/v2ctl uuid)
h2s_uuid=$(/usr/local/bin/v2ctl uuid)

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

@websockets_$wss_ss_path {
header Connection *Upgrade*
header Upgrade    websocket
path /$wss_ss_path
}

@websockets_$wss_vmess_path {
header Connection *Upgrade*
header Upgrade    websocket
path /$wss_vmess_path
}

reverse_proxy @websockets_$wss_ss_path localhost:$wss_ss_port
reverse_proxy @websockets_$wss_vmess_path localhost:$wss_vmess_port

reverse_proxy /$h2s_vmess_path localhost:$h2s_vmess_port {
transport http {
versions h2c
}
}
EOF

# config v2ray
cat <<EOF >/usr/local/etc/v2ray/config.json
{
    "inbounds": 
    [
        {
            "port": $wss_ss_port,"listen":"127.0.0.1","protocol": "shadowsocks",
            "settings": {"method": "$ssmethod","password": "$sspasswd","network": "tcp,udp"},
            "streamSettings": {"network": "ws","wsSettings": {"path": "/$wss_ss_path"}}
        },
        {
            "port": $wss_vmess_port,"listen":"127.0.0.1","protocol": "vmess",
            "settings": {"clients": [{"id": "$wss_uuid"}]},
            "streamSettings": {"network": "ws","wsSettings": {"path": "/$wss_vmess_path"}}
        },
        {
            "port": $h2s_vmess_port,"listen":"127.0.0.1","protocol": "vmess",
            "settings": {"clients": [{"id": "$h2s_uuid"}]},
            "streamSettings": {"network": "h2","httpSettings": {"path": "/$h2s_vmess_path","host": ["$domain"]}}
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
systemctl enable caddy && systemctl restart caddy && sleep 1 && systemctl status caddy | more | grep -A 2 "caddy.service"
echo; echo $(date) v2ray status:
systemctl enable v2ray && systemctl restart v2ray && sleep 1 && systemctl status v2ray | more | grep -A 2 "v2ray.service"

# info
echo; echo $(date) v2ray config info:
cat <<EOF >$TMPFILE
        {
            "protocol": "shadowsocks",
            "tag": "wss_ss_$domain",
            "settings": {"servers":[{"address": "$domain","port": 443,"method": "$ssmethod","password": "$sspasswd"}]},
            "streamSettings": {"network": "ws","security": "tls","tlsSettings": {"allowInsecure": false,"serverName": "$domain"},"wsSettings": {"path": "/$wss_ss_path","headers": {"Host": "$domain"}}}
        },
        
        {
            "protocol": "vmess",
            "tag": "wss_vmess_$domain",
            "settings": {"vnext": [{"address": "$domain","port": 443,"users": [{"id": "$wss_uuid"}]}]},
            "streamSettings": {"network": "ws","security": "tls","tlsSettings": {"allowInsecure": false,"serverName": "$domain"},"wsSettings": {"path": "/$wss_vmess_path","headers": {"Host": "$domain"}}}
        },
        
        {
            "protocol": "vmess",
            "tag": "h2s_vmess_$domain",
            "settings": {"vnext": [{"address": "$domain","port": 443,"users": [{"id": "$h2s_uuid"}]}]},
            "streamSettings": {"network": "h2","security": "tls","httpSettings": {"host": ["$domain"],"path": "/$h2s_vmess_path"}}
        },

EOF

cat $TMPFILE
# done
