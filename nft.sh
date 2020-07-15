#!/usr/bin/env bash
# Usage: bash <(curl -s https://raw.githubusercontent.com/mixool/script/debian-9/nft.sh)
# Wiki: debian buster nftables https://wiki.archlinux.org/index.php/Nftables
apt update && apt install nftables -y

cat <<EOF > /etc/nftables.conf
#!/usr/sbin/nft -f

flush ruleset

table inet my_table {
    chain my_input {
        type filter hook input priority 0; policy drop;

        ct state established,related accept
        ct state invalid drop
        iifname lo accept

        ip protocol icmp limit rate 5/second accept
        ip6 nexthdr ipv6-icmp limit rate 5/second accept
        ip protocol igmp limit rate 5/second accept

        tcp dport { http, https } accept
        udp dport { http, https } accept
        tcp dport $(cat /etc/ssh/sshd_config | grep -oE "^Port [0-9]*$" | grep -oE "[0-9]*" || echo 22) ct state new limit rate 5/minute accept
    }
    
    chain my_forward {
        type filter hook forward priority 0; policy accept;
    }
    
    chain my_output {
        type filter hook output priority 0; policy accept;
    }
}
EOF

systemctl enable nftables && systemctl restart nftables && systemctl status nftables