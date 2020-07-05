#!/usr/bin/env bash
# Wiki: https://github.com/esrrhs/kcptun
# Usage: bash <(curl -s https://raw.githubusercontent.com/mixool/script/debian-9/kcptun.sh)
# Uninstall: systemctl stop kcptun; systemctl disable kcptun; rm -rf /etc/systemd/system/kcptun.service /usr/bin/kcptun

[[ $# != 0 ]] && METHOD=$(echo $@) || METHOD="-l :$(shuf -i 10000-65535 -n1) -t 127.0.0.1:8388 --key $(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16) --crypt aes -mode fast --smuxver 2 --quiet"

URL="$(wget -qO- https://api.github.com/repos/xtaci/kcptun/releases/latest | grep -E "browser_download_url.*linux-amd64" | cut -f4 -d\")"
rm -rf /usr/bin/kcptun
wget -O /tmp/kcptun.tar.gz $URL && tar -zxf /tmp/kcptun.tar.gz && mv /tmp/server_linux_amd64 /usr/bin/kcptun && chmod +x /usr/bin/kcptun && rm /tmp/client_linux_amd64 /tmp/kcptun.tar.gz

cat <<EOF > /etc/systemd/system/kcptun.service
[Unit]
Description=kcptun
[Service]
ExecStart=/usr/bin/kcptun $METHOD
Restart=always
User=root
[Install]
WantedBy=multi-user.target
EOF

systemctl enable kcptun.service && systemctl daemon-reload && systemctl restart kcptun.service && systemctl status kcptun
