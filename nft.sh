!/usr/bin/env bash
# Usage: bash <(curl -s https://raw.githubusercontent.com/mixool/script/debian-9/nft.sh)
# Wiki: debian buster nftables https://wiki.archlinux.org/index.php/Nftables
apt update && apt install nftables -y

cat <<EOF > /etc/nftables.conf
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        iif lo accept
        ct state invalid drop
        ct state established,related accept
        tcp dport { 80, 443 } accept
        tcp dport $(cat /etc/ssh/sshd_config | grep -oE "^Port [0-9]*$" | grep -oE "[0-9]*" || echo 22) ct state new limit rate 15/minute accept
    }

    chain forward {
        type filter hook forward priority 0; policy drop;
    }

    chain output {
        type filter hook output priority 0; policy accept;
    }

}
EOF

systemctl enable nftables && systemctl restart nftables && systemctl status nftables
