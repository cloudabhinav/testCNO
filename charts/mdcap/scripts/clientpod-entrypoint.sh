#!/bin/bash

cp /.robin/scripts/certs/* /app
cd /app

if getent hosts $HOSTNAME | cut -d ' ' -f1 |  grep -q ':';then
    host=0::0
else
	host=0.0.0.0
fi

if [[ $(expr match "$MDCAP_ENGINE_HOST" "\(.*:.*\)" ) ]];
then
    MDCAP_ENGINE_HOST='['${MDCAP_ENGINE_HOST}']'
fi

mkdir /var/run/sshd
echo "root:${PLAYGROUND_ROOT_PASSWORD}" | chpasswd
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
file=/etc/ssh/sshd_config
sed -i "/#UsePrivilegeSeparation/a UsePrivilegeSeparation no" $file

echo "export MDCAP_LOG_HOST=\"${MDCAP_LOG_HOST}\"" >> /etc/profile
echo "export MDCAP_ENGINE_HOST=\"${MDCAP_ENGINE_HOST}\"" >> /etc/profile
echo "export MDCAP_ARTIFACTORY_HOST=\"${MDCAP_ARTIFACTORY_HOST}\"" >> /etc/profile

echo "export MDCAP_LOG_URL=\"https://${MDCAP_LOG_HOST}:8000\"" >> /etc/profile
echo "export MDCAP_ENGINE_URL=\"https://${MDCAP_ENGINE_HOST}:8000\"" >> /etc/profile
echo "export MDCAP_ARTIFACTORY_URL=\"https://${MDCAP_ARTIFACTORY_HOST}:8443\"" >> /etc/profile
echo "export MDCAP_DEFAULT_CONTEXT=${MDCAP_DEFAULT_CONTEXT}" >> /etc/profile
echo "export LC_ALL=C.UTF-8" >> /etc/profile
echo "export LANG=C.UTF-8" >> /etc/profile
mdcap server-context set default "${MDCAP_DEFAULT_CONTEXT}" -d

export WETTY_BASE="/plgconsole1/"

if [ "$DR_ROLE" = "primary" ]; then
    # Enable sync replication for mdcapds
    mdcapds enable-sync-replication --force
    # Check the exit code of the command
    if [ $? -eq 0 ]; then
        echo "Sync Replication Enabled Sucessfully"
    else
        echo "Sync Replication Failed"
    fi
fi

wetty \
    --bypasshelmet --allow-remote-hosts \
    --title "WeTTy" --force-ssh \
    --base $WETTY_BASE --host $host --port 8001 \
    --ssh-user ${MDCAP_CLIENTPOD_UDP_USER} \
    --ssh-host ${MDCAP_CLIENTPOD_UDP_HOST} \
    --ssh-port ${MDCAP_CLIENTPOD_UDP_PORT} \
    --ssl-key /app/key.pem --ssl-cert /app/cert.pem &\
/app/client_pod & /usr/sbin/sshd -D
