#!/usr/bin/env bash
# Wiki: https://github.com/esrrhs/pingtunnel
# Usage: bash <(curl -s https://raw.githubusercontent.com/mixool/script/debian-9/pingtunnel.sh) -type server
# Uninstall: systemctl stop pingtunnel; systemctl disable pingtunnel; rm -rf /etc/systemd/system/pingtunnel.service /usr/bin/pingtunnel

[[ $# != 0 ]] && METHOD=$(echo $@) || METHOD="-type server -key $(tr -dc '0-9' </dev/urandom | head -c 8) -nolog 1 -noprint 1"

URL="$(wget -qO- https://api.github.com/repos/esrrhs/pingtunnel/releases/latest | grep -E "browser_download_url.*pingtunnel_linux64" | cut -f4 -d\")"
rm -rf /usr/bin/pingtunnel
wget -O - $URL | gzip -d > /usr/bin/pingtunnel && chmod +x /usr/bin/pingtunnel

https://github.com/esrrhs/pingtunnel/releases/download/2.3/pingtunnel_linux64.zip

cat <<EOF > /etc/systemd/system/pingtunnel.service
[Unit]
Description=pingtunnel
[Service]
ExecStart=/usr/bin/pingtunnel $METHOD
Restart=always
User=root
[Install]
WantedBy=multi-user.target
EOF

systemctl enable pingtunnel.service && systemctl daemon-reload && systemctl restart pingtunnel.service && systemctl status pingtunnel
