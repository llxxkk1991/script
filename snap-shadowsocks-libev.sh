#!/bin/bash
# Usage:
#   curl https://raw.githubusercontent.com/mixool/script/debian-9/snap-shadowsocks-libev.sh | bash

# only root can run this script
[[ $EUID -ne 0 ]] && echo "Error, This script must be run as root!" && exit 1
  
# install shadowsocks-libev from snap
apt update && apt install snapd -y && snap install core && snap install shadowsocks-libev

# shadowsocks-libev config
mkdir -p /var/snap/shadowsocks-libev/common/etc/shadowsocks-libev
cat >/var/snap/shadowsocks-libev/common/etc/shadowsocks-libev/config.json<<-EOF
{
    "server":["::", "0.0.0.0"],
    "mode":"tcp_and_udp",
    "server_port":$(shuf -i 10000-65535 -n1),
    "local_port":1080,
    "password":"$(tr -dc '~!@#$%^&*()_+a-z0-9A-Z' </dev/urandom | head -c 16)",
    "timeout":600,
    "method":"chacha20-ietf-poly1305"
}
EOF

# shadowsocks-libev service
cat >/lib/systemd/system/shadowsocks-libev.service<<-EOF
[Unit]
Description=Shadowsocks-libev Default Server Service
After=network.target

[Service]
Type=simple
User=root
LimitNOFILE=32768
ExecStart=/snap/bin/shadowsocks-libev.ss-server -c /var/snap/shadowsocks-libev/common/etc/shadowsocks-libev/config.json

[Install]
WantedBy=multi-user.target
EOF

# systemctl shadowsocks-libev informations
systemctl enable shadowsocks-libev && systemctl daemon-reload && systemctl restart shadowsocks-libev && sleep 3 && systemctl status shadowsocks-libev
