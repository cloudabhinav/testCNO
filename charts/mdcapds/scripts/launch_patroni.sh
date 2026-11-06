# Copyright (C) 2021 Robin.io All Rights Reserved.

#!/bin/bash

# Copy certs to postgres home location
# This is needed because postgres can't access mounted secrets because ownership is (root:root)
# https://github.com/zalando/patroni/issues/1009#issuecomment-475586977

cp /etc/etcd/certs/ca.crt /home/postgres/ca.pem
cp /etc/etcd/certs/client.crt /home/postgres/cert.pem
cp /etc/etcd/certs/client.key /home/postgres/key.pem

mkdir -p /home/postgres/patroni
cp /etc/postgresql/certs/cert.pem /home/postgres/patroni
cp /etc/postgresql/certs/key.pem /home/postgres/patroni

# MinIO certs only when DR is enabled (minio-certs volume is mounted)
mkdir -p /home/postgres/minio
if [ -f /etc/minio/certs/ca.crt ]; then
  cp /etc/minio/certs/ca.crt /home/postgres/minio
  chown postgres:root /home/postgres/minio/ca.crt
fi

# provide permissions to postgres user
chown postgres:root /home/postgres/ca.pem /home/postgres/cert.pem /home/postgres/key.pem
chown postgres:root /home/postgres/patroni/cert.pem /home/postgres/patroni/key.pem

# Turn off huge page support
# https://github.com/zalando/patroni/issues/1393
# https://github.com/kubernetes/kubernetes/issues/71233#issuecomment-447472125

echo "huge_pages = off" >> /usr/share/postgresql/15/postgresql.conf.sample

# Supporting multiple replicas
# Use the right control and data port
# Take the base port and add (2 * ordinal) to it
ORDINAL=`echo $HOSTNAME | rev | cut -d'-' -f 1`
NEW_CONTROL_PORT=$(( $((2 * ORDINAL)) + CONTROL_PORT ))
NEW_DATA_PORT=$(( $((2 * ORDINAL)) + DATA_PORT ))
NEW_SPILO_CONFIGURATION=`sed "s/${CONTROL_PORT}/${NEW_CONTROL_PORT}/g" <<< $SPILO_CONFIGURATION`
NEW_SPILO_CONFIGURATION=`sed "s/${DATA_PORT}/${NEW_DATA_PORT}/g" <<< $NEW_SPILO_CONFIGURATION`
# Substitute POD_IP placeholder with actual pod IP for single cluster mode
# Using bash string replacement to avoid sed escaping issues
NEW_SPILO_CONFIGURATION="${NEW_SPILO_CONFIGURATION//\$\{POD_IP\}/${POD_IP}}"
export SPILO_CONFIGURATION=${NEW_SPILO_CONFIGURATION}

# Patroni doesnt have an option for disabling cert check for ETCD
sed  -i "s# match_hostname(cert, asserted_hostname)# print('ignoring hostname check')#" /usr/lib/python3/dist-packages/urllib3/connection.py

# Prevent sslError in logs (local self-call, inconsequential)
sed -i -e 's/curl/curl -k/g' /scripts/patroni_wait.sh
sed -i -e 's/http:/https:/g' /scripts/patroni_wait.sh  
# Launch Patroni

/usr/bin/dumb-init -c --rewrite 1:0 -- /bin/sh /launch.sh
