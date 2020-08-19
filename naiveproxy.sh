#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
# Usage:  debian 9/10 one_key naiveproxy： https://github.com/klzgrad/naiveproxy
# install: bash <(curl -s https://raw.githubusercontent.com/mixool/script/debian-9/naiveproxy.sh) my.domain.com my@gmail.com
# uninstall: apt purge caddy -y; rm -rf /etc/apt/sources.list.d/caddy-fury.list
## Tips: 个人使用，仅供参考

########
[[ $# != 2 ]] && echo Err !!! Useage: bash this_script.sh my.domain.com my@gmail.com && exit 1
domain="$1" && email="$2"
########

# install caddy
apt update && apt install apt-transport-https ca-certificates -y
rm -rf /etc/apt/sources.list.d/caddy-fury.list
echo "deb [trusted=yes] https://apt.fury.io/caddy/ /" | tee -a /etc/apt/sources.list.d/caddy-fury.list
apt update && apt install caddy -y

## 替换apt安装版本的caddy为按照naiveproxy说明编译的版本
rm -rf /usr/bin/caddy
naivecaddyURL="https://github.com/mixool/script/raw/source/naivecaddy.gz"
wget  -O - $naivecaddyURL | gzip -d > /usr/bin/caddy && chmod +x /usr/bin/caddy
sed -i "s/caddy\/Caddyfile$/caddy\/Caddyfile\.json/g" /lib/systemd/system/caddy.service

# secrets
username="$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)"
password="$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)"
probe_resistance="$(tr -dc 'a-z0-9' </dev/urandom | head -c 32).com"

# config caddy
cat <<EOF >/etc/caddy/Caddyfile.json
{
    "apps": {
        "http": {
            "servers": {
                "srv0": {
                    "listen": [":443"],
                    "routes": [{
                        "handle": [{
                            "handler": "forward_proxy",
                            "hide_ip": true,
                            "hide_via": true,
                            "auth_user": "$username",
                            "auth_pass": "$password",
                            "probe_resistance": {"domain": "$probe_resistance"}
                        }]
                    }, {
                    "match": [{"host": ["$domain"]}],
                    "handle": [{
                        "handler": "file_server",
                        "root": "/usr/share/caddy"
                    }],
                    "terminal": true
                    }],
                    "tls_connection_policies": [{
                        "match": {"sni": ["$domain"]}
                    }]
                }
            }
        },
        "tls": {
            "automation": {
                "policies": [{
                    "subjects": ["$domain"],
                    "issuer": {
                        "email": "$email",
                        "module": "acme"
                    }
                }]
            }
        }
    }
}
EOF

# systemctl service info
echo; echo $(date) caddy status:
systemctl daemon-reload && systemctl enable caddy && systemctl restart caddy && sleep 1 && systemctl status caddy | more | grep -A 2 "caddy.service"

# info
echo; echo $(date); echo probe_resistance: $probe_resistance; echo username: $username; echo password: $password; echo proxy: https://$username:$password@$domain
# done
