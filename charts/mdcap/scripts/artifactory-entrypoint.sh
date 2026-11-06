#!/bin/bash

set -x
export RUST_LOG=info
MDCAP_DATA_DIR="/data/"
MDCAPBIN_DIR="/data/artifact/api/v1/mdcapbin/"
VECTOR_DIR="/data/artifact/api/v1/vector/"
VMAAS_DIR="/data/artifact/api/v1/vmaas/"

VMAAS_SCRIPT_PATH="/root/vmaas/vmaas-script-generic.sh"

if [ ! -e key.pem ];then
    cp /.robin/scripts/certs/* .
fi
cp -R /mdcap/readonly_fns/* $MDCAP_DATA_DIR || { echo "Could not copy scripts from /mdcap/readonly_fns to $MDCAP_DATA_DIR"; exit 1; }

if [ -d /artifactory-binary ]; then
    cp /artifactory-binary/* /mdcap/
fi

while [ 1 ]; do
    test -d /data &&  mkdir -p $MDCAPBIN_DIR && 
        cp /root/mdcapbin/* ${MDCAPBIN_DIR} && 
        mkdir -p ${VECTOR_DIR} &&
        cp -n /vector ${VECTOR_DIR} &&
        chmod +x ${VECTOR_DIR}/vector &&
        cp -n /vector.service ${VECTOR_DIR} &&
        mkdir -p ${VMAAS_DIR} &&
        chmod +x ${VMAAS_SCRIPT_PATH} &&
        cp -f ${VMAAS_SCRIPT_PATH} /data/artifact/api/v1/vmaas/vmaas-script-generic.sh  &&
        break
    echo "Waiting for directory /data"
    sleep 1

done
exec /mdcap/artifactory