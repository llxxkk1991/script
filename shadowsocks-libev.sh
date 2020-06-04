#!/bin/bash
# Usage: debian 10 & 9 installl shadowsocks-libev && backports
#   curl https://raw.githubusercontent.com/mixool/script/debian-9/shadowsocks-libev.sh | bash
#   uninstall: apt purge shadowsocks-libev -y; apt auto-remove -y

# only root can run this script
[[ $EUID -ne 0 ]] && echo "Error, This script must be run as root!" && exit 1

# version stretch || buster
version=$(cat /etc/os-release | grep -oE "VERSION_ID=\"(9|10)\"" | grep -oE "(9|10)")
if [[ $version == "9" ]]; then
	backports_version="stretch-backports-sloppy"
else
	[[ $version != "10" ]] &&  echo "Error, OS should be debian stretch or buster " && exit 1 || backports_version="buster-backports"
fi

# install shadowsocks-libev from backports
echo -e "deb http://deb.debian.org/debian $backports_version main\ndeb http://http.us.debian.org/debian sid main\ndeb http://ftp.de.debian.org/debian sid main" > /etc/apt/sources.list.d/$backports_version.list
apt update
apt -t $backports_version install shadowsocks-libev -y

# shadowsocks-libev config
cat >/etc/shadowsocks-libev/config.json<<-EOF
{
    "server":["::", "0.0.0.0"],
    "mode":"tcp_and_udp",
    "server_port":$(shuf -i 10000-65535 -n1),
    "local_port":1080,
    "password":"$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)",
    "timeout":86400,
    "method":"aes-128-gcm"
}
EOF

# systemctl shadowsocks-libev informations
systemctl restart shadowsocks-libev && systemctl status shadowsocks-libev
