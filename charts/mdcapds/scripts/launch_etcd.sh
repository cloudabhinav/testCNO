# Copyright (C) 2021 Robin.io All Rights Reserved.

#!/bin/sh -x

# Determine ipv4/ipv6 to set ETCD_LISTEN_PEER_URLS and ETCD_LISTEN_CLIENT_URLS
if hostname -i | grep -q ':'; then
    echo "IPV6 setup detected"
    IP_SETUP="IPV6"
    export ETCD_LISTEN_PEER_URLS=https://[::]:2380
    export ETCD_LISTEN_CLIENT_URLS=https://[::]:2379
else
    echo "IPV4 setup detected"
    IP_SETUP="IPV4"
    export ETCD_LISTEN_PEER_URLS=https://0.0.0.0:2380
    export ETCD_LISTEN_CLIENT_URLS=https://0.0.0.0:2379
fi

# Supporting multiple replicas
# Use the right control and data port
# Take the base port and add (2 * ordinal) to it
ORDINAL=`echo $HOSTNAME | rev | cut -d'-' -f 1`
NEW_CONTROL_PORT=$(( $((2 * ORDINAL)) + CONTROL_PORT ))
NEW_DATA_PORT=$(( $((2 * ORDINAL)) + DATA_PORT ))

# Use service DNS or pod IP when multiCluster is false, external IP when true
if [ "${MULTI_CLUSTER}" = "false" ]; then
    # For single cluster mode, use the hostname which resolves to pod IP
    # Or construct service DNS name for this specific pod
    ADVERTISE_IP=$HOSTNAME
else
    if [ "${IP_SETUP}" = "IPV6" ]; then
        ADVERTISE_IP="["$IP"]"
    else
        ADVERTISE_IP=$IP
    fi
fi

export ETCD_NAME=${ETCD_NAME}-${ORDINAL}
export ETCD_ADVERTISE_CLIENT_URLS=https://${ADVERTISE_IP}:${NEW_DATA_PORT}
export ETCD_INITIAL_ADVERTISE_PEER_URLS=https://${ADVERTISE_IP}:${NEW_CONTROL_PORT}


if [ "${INSTALL_MODE}" = "install" ]; then
    # If 1 site, form initial cluster with same peer and computed ports
    echo "Number of sites: ${NUM_SITES}"
    if [ ${NUM_SITES} -eq "1" ]; then
        if [ "${MULTI_CLUSTER}" = "false" ]; then
            # Use hostnames for single cluster mode - construct etcd hostnames
            # Extract the base hostname (remove ordinal suffix)
            BASE_HOSTNAME=`echo $HOSTNAME | rev | cut -d'-' -f 2- | rev`
            HOSTNAME_0="${BASE_HOSTNAME}-0"
            HOSTNAME_1="${BASE_HOSTNAME}-1"
            HOSTNAME_2="${BASE_HOSTNAME}-2"
            INITIAL_CLUSTER=mdcapds-site0-0=https://${HOSTNAME_0}:${CONTROL_PORT},mdcapds-site0-1=https://${HOSTNAME_1}:$(( $((2)) + CONTROL_PORT )),mdcapds-site0-2=https://${HOSTNAME_2}:$(( $((4)) + CONTROL_PORT ))
        else
            # Use external IP for multi cluster mode
            if [ "${IP_SETUP}" = "IPV6" ]; then
                CLUSTER_IP="["$IP"]"
            else
                CLUSTER_IP=$IP
            fi
            INITIAL_CLUSTER=mdcapds-site0-0=https://${CLUSTER_IP}:${CONTROL_PORT},mdcapds-site0-1=https://${CLUSTER_IP}:$(( $((2)) + CONTROL_PORT )),mdcapds-site0-2=https://${CLUSTER_IP}:$(( $((4)) + CONTROL_PORT ))
        fi
        echo "Using initial cluster configuration of ${INITIAL_CLUSTER}"
        export ETCD_INITIAL_CLUSTER=${INITIAL_CLUSTER}
    elif [ ${NUM_SITES} -eq "3" ]; then
        PEER1=`echo $PEERS | cut -d ',' -f 1`
        PEER2=`echo $PEERS | cut -d ',' -f 2`
        PEER3=`echo $PEERS | cut -d ',' -f 3`
        INITIAL_CLUSTER=mdcapds-site0-0=https://${PEER1}:${CONTROL_PORT},mdcapds-site1-0=https://${PEER2}:${CONTROL_PORT},mdcapds-site2-0=https://${PEER3}:${CONTROL_PORT}
        export ETCD_INITIAL_CLUSTER=${INITIAL_CLUSTER}
    else
        echo "Unsupport number of sites, max of 3 supported"
        exit 1
    fi
else
    # If 1 site, form initial cluster with same peer and computed ports
    echo "Number of sites: ${NUM_SITES}"
    if [ ${NUM_SITES} -eq "1" ]; then
        echo "For scaling the sites, there could be 2 or 3 peers"
        exit 1
    elif [ ${NUM_SITES} -eq "2" ]; then
        PEER1=`echo $PEERS | cut -d ',' -f 1`
        PEER2=`echo $PEERS | cut -d ',' -f 2`
        PEER3=`echo $PEERS | cut -d ',' -f 3`
        INITIAL_CLUSTER=mdcapds-site0-0=https://${PEER1}:${CONTROL_PORT},mdcapds-site0-1=https://${PEER1}:$(( $((2)) + CONTROL_PORT )),mdcapds-site0-2=https://${PEER1}:$(( $((4)) + CONTROL_PORT )),mdcapds-site1-0=https://${PEER2}:${CONTROL_PORT}
        export ETCD_INITIAL_CLUSTER=${INITIAL_CLUSTER}
    elif [ ${NUM_SITES} -eq "3" ]; then
        PEER1=`echo $PEERS | cut -d ',' -f 1`
        PEER2=`echo $PEERS | cut -d ',' -f 2`
        PEER3=`echo $PEERS | cut -d ',' -f 3`
        INITIAL_CLUSTER=mdcapds-site0-0=https://${PEER1}:${CONTROL_PORT},mdcapds-site0-1=https://${PEER1}:$(( $((2)) + CONTROL_PORT )),mdcapds-site0-2=https://${PEER1}:$(( $((4)) + CONTROL_PORT )),mdcapds-site1-0=https://${PEER2}:${CONTROL_PORT},mdcapds-site2-0=https://${PEER3}:${CONTROL_PORT}
        export ETCD_INITIAL_CLUSTER=${INITIAL_CLUSTER}
    else
        echo "Unsupport number of sites, max of 3 supported"
        exit 1
    fi
fi


# Copy the self signed certs from secret mount to where etcd reads them.
# Use peer auto tls and client auto tls to tell etcd to not complain about IP address checks
mkdir -p /data/fixtures/client
mkdir -p /data/fixtures/peer
cp /etc/etcd/certs/peer.crt /data/fixtures/peer/cert.pem
cp /etc/etcd/certs/peer.key /data/fixtures/peer/key.pem
cp /etc/etcd/certs/client.crt /data/fixtures/client/cert.pem
cp /etc/etcd/certs/client.key /data/fixtures/client/key.pem

# Launch etcd
etcd --auto-tls --peer-auto-tls
