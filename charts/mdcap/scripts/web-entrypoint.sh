#!/bin/sh

# go to the path where dashboard build is ready
cd /root/gui

# enable the build based on deployment type
if [ "$BASIC_AUTH" == "1" ]
then
    mv robin_dist dist
else
    mv rcp_dist dist
fi

#MDCAP_NGINX_HOST=${ROBINHOST}
#MDCAP_PLAYGROUND_HOST=${MDCAP_NGINX_HOST}
MDCAP_PLAYGROUND_PORT=${MDCAP_NGINX_PLAYGROUND_PORT}

mkdir -p ${MDCAP_SSL_CERTS_DIR}
cp /.robin/scripts/certs/* ${MDCAP_SSL_CERTS_DIR}

if getent hosts $HOSTNAME | cut -d ' ' -f1 |  grep -q ':';then
    host=0::0
else
	host=0.0.0.0
fi

# wetty (>= 3.0.4) refuses to start without at least one allowed browser origin (ALLOWEDORIGINS,
# comma separated, set from the helm chart), and the dashboard probes need wetty listening on 3000.
# Without a configured origin fall back to one no browser will use, so the port stays up but the
# console rejects browser connections until externalIp or dashboard.env.allowed_origins is set.
if [ -z "$ALLOWEDORIGINS" ]
then
    echo "ALLOWEDORIGINS is not set, the wetty console will not accept browser connections"
    export ALLOWEDORIGINS="https://localhost"
fi
wetty --title "WeTTy" --force-ssh --base "/plgconsole/" --host $host --port 3000 --ssh-host ${MDCAP_PLAYGROUND_HOST} --ssh-port ${MDCAP_PLAYGROUND_PORT} --ssl-key ${MDCAP_SSL_CERTS_DIR}/key.pem --ssl-cert ${MDCAP_SSL_CERTS_DIR}/cert.pem &
node server/server.mjs --host $host --sslkey ${MDCAP_SSL_CERTS_DIR}/key.pem --sslcert ${MDCAP_SSL_CERTS_DIR}/cert.pem
