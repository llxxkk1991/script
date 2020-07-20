#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin:/usr/local/go/bin
export PATH
# Usage:  debian 9/10 one_key for caddy2 tls websocket vmess v2ray
# install: bash <(curl -s https://raw.githubusercontent.com/mixool/script/debian-9/raywss_vmess_ss_caddy_cftls.sh) my.domain.com cloudflare_api_token
# uninstall: apt purge caddy -y; rm -rf /etc/apt/sources.list.d/caddy-fury.list; bash <(curl -L -s https://install.direct/go.sh) --remove; rm -rf /etc/v2ray/config.json

# tempfile & rm it when exit
trap 'rm -f "$TMPFILE"' EXIT
TMPFILE=$(mktemp) || exit 1

########
[[ $# != 2 ]] && echo Err !!! Useage: bash this_script.sh my.domain.com cloudflare_api_token && exit 1
domain="$1"
cloudflare_api_token="$2"
curl -sX GET "https://api.cloudflare.com/client/v4/user/tokens/verify" -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type:application/json" | grep -qE "success\":false" && echo cloudflare_api_token err && exit 1

ssport=$(shuf -i 10000-65535 -n1)
vmessport=$(shuf -i 10000-65535 -n1)
until [[ $ssport != $vmessport ]]; do vmessport=$(shuf -i 10000-65535 -n1); done

path_wssss=$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)
path_vmess=$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)

uuid=$(/usr/bin/v2ray/v2ctl uuid)

ssmethod="aes-128-gcm"
sspasswd=$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)
########

# install caddy
apt update && apt install apt-transport-https ca-certificates -y
rm -rf /etc/apt/sources.list.d/caddy-fury.list
echo "deb [trusted=yes] https://apt.fury.io/caddy/ /" | tee -a /etc/apt/sources.list.d/caddy-fury.list
apt update && apt install caddy -y

# xcaddy build caddy with pulgin dns.providers.cloudflare
rm -rf /usr/local/go /root/xcaddy
wget -O - https://golang.org/dl/go1.14.6.linux-amd64.tar.gz | tar -xz -C /usr/local

URL="$(wget -qO- https://api.github.com/repos/caddyserver/xcaddy/releases | grep -E "browser_download_url.*linux_amd64" | cut -f4 -d\")"
wget -O /root/xcaddy $URL && chmod +x /root/xcaddy
/root/xcaddy build --with github.com/caddy-dns/cloudflare
mv -f /root/caddy /usr/bin/caddy

[[ ! $(caddy list-modules | grep -q "dns.providers.cloudflare") ]] && echo caddy with pulgin dns.providers.cloudflare build failed, rm files: /usr/local/go /root/xcaddy && exit 1 || echo caddy with pulgin dns.providers.cloudflare build successed
rm -rf /usr/local/go /root/xcaddy

# install v2ray
bash <(curl -L -s https://install.direct/go.sh)

# config caddy
cat <<EOF >/etc/caddy/Caddyfile
$domain
root * /usr/share/caddy
file_server
header {
Strict-Transport-Security max-age=31536000;
X-Content-Type-Options nosniff
X-Frame-Options DENY
Referrer-Policy no-referrer-when-downgrade
}
tls {
dns cloudflare $cloudflare_api_token
}
@websockets_$path_wssss {
header Connection Upgrade
header Upgrade websocket
path /$path_wssss
}
@websockets_$path_vmess {
header Connection Upgrade
header Upgrade websocket
path /$path_vmess
}
reverse_proxy @websockets_$path_wssss localhost:$ssport
reverse_proxy @websockets_$path_vmess localhost:$vmessport
EOF

# config v2ray
cat <<EOF >/etc/v2ray/config.json
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
        {"protocol": "freedom","tag": "direct","settings": {"domainStrategy": "UseIP"}},
        {"protocol": "blackhole","tag": "blocked","settings": {}}
    ],
    "dns": 
    {
        "servers":["https+local://dns.google/dns-query","https+local://1.1.1.1/dns-query","localhost"],
        "clientIp": "$(ping -w 1 -c 1 $domain | head -n 1 | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | head -n 1)"
    },
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

# systemctl service 
systemctl enable caddy && systemctl restart caddy && systemctl status caddy
systemctl enable v2ray && systemctl restart v2ray && systemctl status v2ray

# info
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
