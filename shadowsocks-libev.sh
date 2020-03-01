#!/bin/bash
# Usage:
#   curl https://raw.githubusercontent.com/mixool/script/debian-9/shadowsocks-libev.sh | bash

# only root can run this script
[[ $EUID -ne 0 ]] && echo "Error, This script must be run as root!" && exit 1
  
# install shadowsocks-libev from stretch-backports
sh -c 'printf "deb http://deb.debian.org/debian stretch-backports main" > /etc/apt/sources.list.d/stretch-backports.list'
apt update
apt -t stretch-backports install shadowsocks-libev -y

# shadowsocks-libev config
cat >/etc/shadowsocks-libev/config.json<<-EOF
{
    "server":["::", "0.0.0.0"],
    "mode":"tcp_and_udp",
    "server_port":$(shuf -i 10000-65535 -n1),
    "local_port":1080,
    "password":"$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)",
    "timeout":600,
    "method":"xchacha20-ietf-poly1305"
}
EOF

# systemctl shadowsocks-libev informations
systemctl restart shadowsocks-libev && systemctl status shadowsocks-libev
