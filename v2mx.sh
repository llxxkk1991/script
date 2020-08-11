#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
# Usage:  debian 9/10 one_key for caddy2 tls websocket vmess v2ray
# install: bash <(curl -s https://raw.githubusercontent.com/mixool/script/debian-9/v2mx.sh) my.domain.com CF_Key CF_Email
# uninstall: apt purge caddy -y; rm -rf /etc/apt/sources.list.d/caddy-fury.list; bash <(curl https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) --remove; rm -rf /usr/local/etc/v2ray /var/log/v2ray
## Tips: 个人使用，仅供参考，配置随时改变，当前配置: tcp tls  vless caddy 

# tempfile & rm it when exit
trap 'rm -f "$TMPFILE"' EXIT
TMPFILE=$(mktemp) || exit 1

########
[[ $# != 3 ]] && echo Err !!! Useage: bash this_script.sh my.domain.com CF_Key CF_Email && exit 1
domain="$1"
export CF_Key="$2"
export CF_Email="$3"
########

# install acme.sh
apt install socat -y
curl https://get.acme.sh | sh
source  ~/.bashrc
/root/.acme.sh/acme.sh --issue --dns dns_cf --keylength ec-256 -d $domain

# install caddy
apt update && apt install apt-transport-https ca-certificates -y
rm -rf /etc/apt/sources.list.d/caddy-fury.list
echo "deb [trusted=yes] https://apt.fury.io/caddy/ /" | tee -a /etc/apt/sources.list.d/caddy-fury.list
apt update && apt install caddy -y

# install v2ray; update geoip.dat && geosite.dat
bash <(curl https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
bash <(curl https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-dat-release.sh)
v2my_uuid=$(/usr/local/bin/v2ctl uuid)

# config caddy
cat <<EOF >/etc/caddy/Caddyfile
http://$domain

root * /usr/share/caddy

file_server

header {
X-Content-Type-Options nosniff
X-Frame-Options DENY
Referrer-Policy no-referrer-when-downgrade
}
EOF

# config v2ray
cat <<EOF >/usr/local/etc/v2ray/config.json
{
    "inbounds": 
    [
        {
            "port": 443,"protocol": "vless",
            "settings": {"clients": [{"id": "$v2my_uuid"}],"decryption": "none","fallback": {"port": 80}},
            "streamSettings": {"network": "tcp","security": "tls","tlsSettings": {"alpn": ["http/1.1"],"certificates": [{"certificateFile": "/root/.acme.sh/${domain}_ecc/fullchain.cer","keyFile": "/root/.acme.sh/${domain}_ecc/${domain}.key"}]}}
        }
    ],
    
    "outbounds": 
    [
        {"protocol": "freedom","tag": "direct","settings": {}},
        {"protocol": "blackhole","tag": "blocked","settings": {}}
    ],
    "routing": 
    {
        "rules": 
        [
            {"type": "field","outboundTag": "blocked","ip": ["geoip:private","geoip:cn"]},
            {"type": "field","outboundTag": "blocked","domain": ["geosite:private","geosite:cn","geosite:category-ads-all"]}
        ]
    }
}
EOF

# config v2ray service
cat <<EOF >/etc/systemd/system/v2ray.service
[Unit]
Description=V2Ray Service
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
Environment=V2RAY_LOCATION_ASSET=/usr/local/lib/v2ray/
ExecStart=/usr/local/bin/v2ray -config /usr/local/etc/v2ray/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# systemctl service info
systemctl daemon-reload
echo; echo $(date) caddy status:
systemctl enable caddy && systemctl restart caddy && sleep 1 && systemctl status caddy | more | grep -A 2 "caddy.service"
echo; echo $(date) v2ray status:
systemctl enable v2ray && systemctl restart v2ray && sleep 1 && systemctl status v2ray | more | grep -A 2 "v2ray.service"

# info
echo; echo $(date) v2ray config info:
cat <<EOF >$TMPFILE
        {
            "protocol": "vless",
            "tag": "v2my_$domain",
            "settings": {"vnext": [{"address": "$domain","port": 443,"users": [{"id": "$v2my_uuid","encryption": "none"}]}]},
            "streamSettings": {"security": "tls"}
        },

EOF

cat $TMPFILE
# done
