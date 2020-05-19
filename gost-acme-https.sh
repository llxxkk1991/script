#!/usr/bin/env bash
# Wiki: https://docs.ginuerzh.xyz/gost/ && https://github.com/acmesh-official/acme.sh/wiki
# Usage: bash <(curl -s https://raw.githubusercontent.com/mixool/script/debian-9/gost-acme-https.sh)
## 使用GOST搭建443端口的服务端HTTPS代理，并开启防探测。使用acme自动申请证书，只在申请和更新证书时acme占用80端口。重复运行即可更改配置。
### 卸载： systemctl disable gost && systemctl stop gost && rm -rf /etc/gost /usr/bin/gost /etc/systemd/system/gost.service && /root/.acme.sh/acme.sh --uninstall

read -p "Please input your domain name for vps:" domain
read -p "Please input your username:" username
read -p "Please input your password:" password
read -p "Please input your probe_resist:" probe_resist

#### 获取最新版gost并配置gost.service
URL="$(wget -qO- https://api.github.com/repos/ginuerzh/gost/releases/latest | grep -E "browser_download_url.*gost-linux-amd64" | cut -f4 -d\")"
rm -rf /usr/bin/gost
wget -O - $URL | gzip -d > /usr/bin/gost && chmod +x /usr/bin/gost

cat <<EOF > /etc/systemd/system/gost.service
[Unit]
Description=gost
[Service]
ExecStart=/usr/bin/gost -L=http2://$username:$password@:443?probe_resist=web:$probe_resist&knock=www.google.com&cert=/etc/gost/gost.crt&key=/etc/gost/gost.key
Restart=always
User=root
[Install]
WantedBy=multi-user.target
EOF

#### 使用acme自动签发和安装证书
curl https://get.acme.sh | sh

/root/.acme.sh/acme.sh  --upgrade  --auto-upgrade

/root/.acme.sh/acme.sh --issue -d $domain --standalone

mkdir -p /etc/gost

/root/.acme.sh/acme.sh --install-cert -d $domain --key-file /etc/gost/gost.key --fullchain-file /etc/gost/gost.crt --reloadcmd "systemctl restart gost"

#### 启动gost.service
systemctl enable gost.service && systemctl daemon-reload && systemctl restart gost.service && sleep 3 && systemctl status gost
