#!/bin/sh

if [[ $1 == "monitor" ]]; then
    LAST_MTIME=0
    while true; do
        if [ -f /etc/nginx/robinclusters/reload ]; then
            CURR_MTIME=$(stat -c '%Y' /etc/nginx/robinclusters/reload)
            if [ $CURR_MTIME -gt $LAST_MTIME ]; then
                echo "Reloading nginx config"
                nginx -s reload
                LAST_MTIME=$CURR_MTIME
            fi
        fi
        sleep 5
    done
fi

set -x

IPTYPE=$( nslookup $MDCAP_ENGINE_HOST | grep Server | awk '{ print $2 }')

if [[ $(expr match "$IPTYPE" "\(.*:.*\)" ) ]];
then
    LISTEN_PORT="[::]:443 ssl"
    PL_LISTEN_PORT="[::]:22"
    NGX_EXPORTER_LISTEN_PORT="[::]:8080"
    MDCAP_ENGINE_HOST=${MDCAP_ENGINE_HOST}
else
    LISTEN_PORT="443 ssl"
    PL_LISTEN_PORT="22"
    NGX_EXPORTER_LISTEN_PORT="8080"
fi

MDCAP_DASHBOARD_URL="https://${MDCAP_DASHBOARD_HOST}:8000"
MDCAP_EVENTMGR_URL="https://${MDCAP_EVENTMGR_HOST}:8000"
MDCAP_ENGINE_URL="https://${MDCAP_ENGINE_HOST}:8000"
MDCAP_LOG_URL="https://${MDCAP_LOG_HOST}:8000"
MDCAP_CLIENTPOD_URL="https://${MDCAP_CLIENTPOD_HOST}:8000"
MDCAP_CLIENTPOD_WETTY_URL="https://${MDCAP_CLIENTPOD_WETTY_HOST}:8001"
WORKER_PROCESSES="auto"
WORKER_CONNECTIONS="32768"
PROXY_CONNECT_TIMEOUT="3600"
PROXY_SEND_TIMEOUT="3600"
PROXY_READ_TIMEOUT="3600"
SEND_TIMEOUT="3600"
CLIENT_MAX_BODY_SIZE="100M"
WORKER_RLIMIT_NOFILE="65536"

apiversion=v1
api_url="api/${apiversion}"

if [[ ! -d /etc/nginx/robinclusters ]]; then
    mkdir -p /etc/nginx/robinclusters
fi

cat << EOF > /etc/nginx/conf.d/default.conf
server {
    listen ${NGX_EXPORTER_LISTEN_PORT};
    server_tokens off;

    location /stub_status {
        add_header X-Frame-Options SAMEORIGIN always;
        index index.html;
        stub_status on;
    }
EOF

if [ ! -z $MDCAP_CDN_HTTP_URL ]
then
cat << EOF >> /etc/nginx/conf.d/default.conf
location /artifact/${api_url} {
        add_header X-Frame-Options SAMEORIGIN always;
        client_max_body_size 20G;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_request_buffering off;
        proxy_http_version 1.1;
        proxy_pass ${MDCAP_CDN_HTTP_URL};
    }
}
EOF
else
cat << EOF >> /etc/nginx/conf.d/default.conf
}
EOF
fi

cat << EOF >> /etc/nginx/conf.d/default.conf
server {
    listen  ${LISTEN_PORT};
    server_name localhost;
    server_tokens off;
    ssl_certificate ${MDCAP_SSL_CERTS_DIR}/cert.pem;
    ssl_certificate_key ${MDCAP_SSL_CERTS_DIR}/key.pem;
    ssl_session_timeout 60m;
    keepalive_timeout   70;

    include /etc/nginx/robinclusters/*.conf;

    location /engine/${api_url} {
        add_header X-Frame-Options SAMEORIGIN always;
        client_max_body_size 1G;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_pass ${MDCAP_ENGINE_URL}/${api_url};
    }
    location /static {
        add_header X-Frame-Options SAMEORIGIN always;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_pass ${MDCAP_ENGINE_URL}/static;
    }
    location /log/${api_url} {
        rewrite /log/${api_url}/(.*) /\$1  break;
        add_header X-Frame-Options SAMEORIGIN always;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_pass ${MDCAP_LOG_URL};
    }
EOF

if false && [ ! -z $MDCAP_MCP_HOST ]
then
MDCAP_MCP_URL="http://${MDCAP_MCP_HOST}:8002"
cat << EOF >> /etc/nginx/conf.d/default.conf
    location /mcp/ {
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Connection '';
        proxy_buffering off;
        proxy_cache off;
        chunked_transfer_encoding on;
        proxy_read_timeout 3600;
        # Cookie-based session affinity — pins each MCP client to one pod.
        # The upstream Kubernetes Service uses sessionAffinity: ClientIP,
        # so nginx just needs to consistently hash the cookie value.
        set \$mcp_cookie \$cookie_mcp_session;
        if (\$mcp_cookie = "") {
            set \$mcp_cookie \$request_id;
        }
        proxy_set_header X-MCP-Session \$mcp_cookie;
        add_header Set-Cookie "mcp_session=\$mcp_cookie; Path=/mcp/; HttpOnly; SameSite=Lax" always;
        proxy_pass ${MDCAP_MCP_URL}/;
    }
EOF
fi

if [ ! -z $METRICS_GRAFANA_IP ]
then
METRICS_GRAFANA_URL="https://${METRICS_GRAFANA_IP}:3000"
cat << EOF >> /etc/nginx/conf.d/default.conf
    location /grafana {
        add_header X-Frame-Options SAMEORIGIN always;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_pass ${METRICS_GRAFANA_URL};
    }
    location /grafana/api/live {
        add_header X-Frame-Options SAMEORIGIN always;
        proxy_set_header Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_pass ${METRICS_GRAFANA_URL};
    }
EOF
fi

if [ ! -z $METRICS_IP ]
then
METRICS_URL="https://${METRICS_IP}:8428"
cat << EOF >> /etc/nginx/conf.d/default.conf
    location ^~ /vmetrics/api/v1/write {
        rewrite /vmetrics(.*) /\$1 break;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_pass ${METRICS_URL};
    }

    location /vmetrics {
        rewrite /vmetrics(.*) /\$1 break;
        add_header X-Frame-Options SAMEORIGIN always;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_pass ${METRICS_URL};
    }
EOF
fi

if [ ! -z $MDCAP_COCKPIT_BASEURL ]
then
cat << EOF >> /etc/nginx/conf.d/default.conf
    location ${MDCAP_COCKPIT_URLROOT}/ {
        proxy_buffering     off;
        proxy_http_version  1.1;
        proxy_pass          ${MDCAP_COCKPIT_BASEURL}${MDCAP_COCKPIT_URLROOT}/;
        proxy_set_header    Host \$host;
        proxy_set_header    X-Forwarded-Proto \$scheme;
        proxy_set_header    X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header    Upgrade \$http_upgrade;
        proxy_set_header    Connection "upgrade";
    }
EOF
fi

if [ ! -z $MDCAP_DASHBOARD_HOST ]
then
cat << EOF >> /etc/nginx/conf.d/default.conf
location / {
        add_header X-Frame-Options SAMEORIGIN always;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_pass ${MDCAP_DASHBOARD_URL};
    }
EOF
fi


if [ ! -z $MDCAP_CDN_URL ]
then
cat << EOF >> /etc/nginx/conf.d/default.conf
location /artifact/${api_url} {
        add_header X-Frame-Options SAMEORIGIN always;
        client_max_body_size 20G;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_request_buffering off;
        proxy_http_version 1.1;
        proxy_pass ${MDCAP_CDN_URL};
    }
EOF
fi

if [ ! -z $MDCAP_REGISTRY_URL ]
then
cat << EOF >> /etc/nginx/conf.d/default.conf
    location /v2/ {
        client_max_body_size    0;
        proxy_request_buffering off;
        proxy_set_header Host              \$http_host;
        proxy_set_header X-Real-IP         \$remote_addr;
        proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Port  \$server_port;
        proxy_pass ${MDCAP_REGISTRY_URL};
    }
EOF
fi

if [ ! -z $MDCAP_EVENTMGR_URL ]
then
cat << EOF >> /etc/nginx/conf.d/default.conf
    location /eventmgr/${api_url} {
        rewrite /eventmgr/${api_url}/(.*) /\$1  break;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_pass ${MDCAP_EVENTMGR_URL};
    }
EOF
fi

if [ ! -z $MDCAP_CLIENTPOD_URL ]
then
cat << EOF >> /etc/nginx/conf.d/default.conf
    location /client/${api_url} {
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_ssl_verify off;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_pass ${MDCAP_CLIENTPOD_URL};
    }
EOF
fi

if [ ! -z $MDCAP_CLIENTPOD_HOST ]
then
cat << EOF >> /etc/nginx/conf.d/default.conf
    location ^~ /plgconsole1 {
        add_header X-Frame-Options SAMEORIGIN always;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 43200000;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$http_host;
        proxy_set_header X-NginX-Proxy true;
        proxy_pass ${MDCAP_CLIENTPOD_WETTY_URL};
    }
EOF
fi

if [ ! -z $KEYCLOAK_ENABLED ]
then
cat << EOF >> /etc/nginx/conf.d/default.conf
    location /keycloak {
        proxy_pass ${KEYCLOAK_URL}/keycloak;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto "https";
        proxy_set_header X-Forwarded-Host \$host;
EOF
if [ ! -z $KEYCLOAK_PORT_FORWARD ]
then
cat << EOF >> /etc/nginx/conf.d/default.conf
        proxy_set_header X-Forwarded-Port 9443;
EOF
fi
cat << EOF >> /etc/nginx/conf.d/default.conf
    }
EOF
fi

cat << EOF >> /etc/nginx/conf.d/default.conf
}
EOF

cat << EOF > /etc/nginx/nginx.conf
user  nginx;
worker_processes  ${WORKER_PROCESSES};
worker_rlimit_nofile ${WORKER_RLIMIT_NOFILE};

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;


events {
    worker_connections  ${WORKER_CONNECTIONS};
    multi_accept on;
    use epoll;
}


http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    client_max_body_size ${CLIENT_MAX_BODY_SIZE};

    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;
    proxy_connect_timeout ${PROXY_CONNECT_TIMEOUT};
    proxy_read_timeout ${PROXY_READ_TIMEOUT};
    proxy_send_timeout ${PROXY_SEND_TIMEOUT};
    send_timeout ${SEND_TIMEOUT};

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    #gzip  on;

    include /etc/nginx/conf.d/*.conf;
}
EOF

if [ ! -z $MDCAP_CLIENTPOD_HOST ]
then
cat << EOF >> /etc/nginx/nginx.conf
stream {
    server {
        listen ${PL_LISTEN_PORT};
        proxy_pass ${MDCAP_CLIENTPOD_HOST}:22;
    }
}
EOF
fi

set -x
/bin/sh /scripts/nginx-entrypoint.sh monitor &
"$@"

