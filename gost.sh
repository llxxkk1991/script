#!/usr/bin/env bash
# Usage:
#   curl https://raw.githubusercontent.com/mixool/script/debian-9/gost.sh | bash -L=:8080 

[[ $# != 0 ]] && METHOD=$(echo $@) || METHOD="-L=ss://AEAD_CHACHA20_POLY1305:$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)@:$(shuf -i 10000-65535 -n1)"

VER="$(wget -qO- https://github.com/ginuerzh/gost/tags | grep -oEm1 "/tag/v[^\"]*" | cut -dv -f2)"
VER=${VER:=2.11.0}
URL="https://github.com/ginuerzh/gost/releases/download/v${VER}/gost-linux-amd64-${VER}.gz"

echo "1. Downloading gost-linux-amd64-${VER}.gz to /root/gost from $URL" && echo
rm -rf /root/gost
wget -O - $URL | gzip -d > /root/gost && chmod +x /root/gost

echo "2. Generate /etc/systemd/system/gost.service"
cat <<EOF > /etc/systemd/system/gost.service
[Unit]
Description=gost
[Service]
ExecStart=/root/gost $METHOD
Restart=always
User=root
[Install]
WantedBy=multi-user.target
EOF

systemctl enable gost.service && systemctl daemon-reload && systemctl restart gost.service && systemctl status gost -l
