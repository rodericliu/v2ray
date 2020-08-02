#!/bin/bash

V2RAY_ID=""
WEBSOCKET_PATH=""
SERVER_NAME=""
YOUR_EMAIL=""

if [ "`id -u -n`" != "root" ] ; then
    echo -e "this should be run as root only, please switch to root user by running [\e[0;32;1msudo bash\e[0m]"
    exit 1
fi

cat <<EOF> /etc/yum.repos.d/nginx.repo
[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/7/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
EOF

sed -i s#enforcing#disabled#g /etc/selinux/config

yum -y install nginx certbot python2-certbot-nginx psmisc wget unzip >/dev/null 2>&1

echo "install v2ray"
bash <(curl -L -s https://install.direct/go.sh)

cat <<EOF> /etc/v2ray/config.json
{
  "inbounds": [
    {
      "port": 9990,
      "listen":"127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${V2RAY_ID}",
            "alterId": 64
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
        "path": "/${WEBSOCKET_PATH}"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

systemctl enable v2ray
systemctl start v2ray

certbot certonly --non-interactive --agree-tos --nginx --email "${YOUR_EMAIL}" -d "${SERVER_NAME}"

cat <<EOF>> /etc/nginx/conf.d/default.conf

    server {
        server_name ${SERVER_NAME}; 
        root         /usr/share/nginx/html;

        listen 443 ssl; 
        ssl_certificate /etc/letsencrypt/live/${SERVER_NAME}/fullchain.pem; 
        ssl_certificate_key /etc/letsencrypt/live/${SERVER_NAME}/privkey.pem;
        include /etc/letsencrypt/options-ssl-nginx.conf;
        ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

        location / {
            return 444;
        }

        location /${WEBSOCKET_PATH} {
            proxy_redirect off;
            proxy_pass http://127.0.0.1:9990;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$http_host;

            # Show realip in v2ray access.log
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
    }
EOF

killall -9 nginx
sed -i s#/var/run#/tmp#g /etc/nginx/nginx.conf
sed -i s#/var/run#/tmp#g /usr/lib/systemd/system/nginx.service
systemctl enable nginx
systemctl daemon-reload 
systemctl start nginx

wget --quiet "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh"
chmod +x tcp.sh

echo -e "Please execute [\e[0;32;1m./tcp.sh\e[0m] and choose [\e[0;32;1m2\e[0m] to install BBR plus kernel. Reboot the system after that and execute [\e[0;32;1m./tcp.sh\e[0m] again and choose [\e[0;32;1m7\e[0m] to enable the BBRplus acceleration"
