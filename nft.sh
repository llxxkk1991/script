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

        iif lo accept comment "Accept any localhost traffic"
        ct state invalid drop comment "Drop invalid connections"

        meta l4proto icmp icmp type echo-request limit rate over 10/second burst 4 packets drop comment "No ping floods"
        meta l4proto ipv6-icmp icmpv6 type echo-request limit rate over 10/second burst 4 packets drop comment "No ping floods"

        ct state established,related accept comment "Accept traffic originated from us"

        meta l4proto ipv6-icmp icmpv6 type { destination-unreachable, packet-too-big, time-exceeded, parameter-problem, mld-listener-query, mld-listener-report, mld-listener-reduction, nd-router-solicit, nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert, ind-neighbor-solicit, ind-neighbor-advert, mld2-listener-report } accept comment "Accept ICMPv6"
        meta l4proto icmp icmp type { destination-unreachable, router-solicitation, router-advertisement, time-exceeded, parameter-problem } accept comment "Accept ICMP"
        ip protocol igmp accept comment "Accept IGMP"

        tcp dport { 80, 443 } accept
        tcp dport $(cat /etc/ssh/sshd_config | grep -oE "^Port [0-9]*$" | grep -oE "[0-9]*" || echo 22) ct state new limit rate 5/minute accept comment "Avoid brute force on SSH"
    }
    
    chain my_forward {
        type filter hook forward priority 0; policy drop;
    }
    
    chain my_output {
        type filter hook output priority 0; policy accept;
    }
}
EOF

systemctl enable nftables && systemctl restart nftables && systemctl status nftables
