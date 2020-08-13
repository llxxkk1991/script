#!/usr/bin/env bash
# Wiki: https://docs.ginuerzh.xyz/gost/
# Usage: 一键gost搭建https代理
# Usage: bash <(curl -s https://raw.githubusercontent.com/mixool/script/debian-9/gost_https.sh) my.domain.com CF_Key CF_Email
# Uninstall: /root/.acme.sh/acme.sh --uninstall; systemctl stop gost; systemctl disable gost; rm -rf /etc/systemd/system/gost.service /usr/bin/gost

######## 脚本需要传入三个参数： 域名,Cloudflare账户的GobalAPI,Cloudflare账户的Email
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
rm -rf /etc/gost; mkdir -p /etc/gost
/root/.acme.sh/acme.sh --installcert -d $domain --ecc --fullchain-file /etc/gost/gost.crt --key-file /etc/gost/gost.key --reloadcmd "service gost restart"

# install gost
URL="$(wget -qO- https://api.github.com/repos/ginuerzh/gost/releases/latest | grep -E "browser_download_url.*gost-linux-amd64" | cut -f4 -d\")"
rm -rf /usr/bin/gost
wget -O - $URL | gzip -d > /usr/bin/gost && chmod +x /usr/bin/gost

## 探测防御使用caddy2默认页面
wget -O /etc/gost/index.html https://raw.githubusercontent.com/mixool/script/source/index.html

## 代理账号密码以及Knock参数: https://docs.ginuerzh.xyz/gost/probe_resist/
username="$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)"
password="$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)"
knock="$username.$password"

cat <<EOF > /etc/systemd/system/gost.service
[Unit]
Description=gost
[Service]
ExecStart=/usr/bin/gost -L=https://$username:$password@:443?probe_resist=file:/etc/gost/index.html&knock=$knock&cert=/etc/gost/gost.crt&key=/etc/gost/gost.key
Restart=always
User=root
[Install]
WantedBy=multi-user.target
EOF

systemctl enable gost.service && systemctl daemon-reload && systemctl restart gost.service && systemctl status gost | more | grep -A 2 "gost.service"

# info
echo; echo $(date); echo knock: $knock; echo username: $username; echo password: $password; echo https://$domain
