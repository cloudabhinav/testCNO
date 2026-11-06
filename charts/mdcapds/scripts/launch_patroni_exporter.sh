# Copyright (C) 2021 Robin.io All Rights Reserved.

#!/bin/sh

# Supporting multiple replicas
# Use the right control
# Take the base port and add (2 * ordinal) to it
ORDINAL=`echo $HOSTNAME | rev | cut -d'-' -f 1`
NEW_CONTROL_PORT=$(( $((2 * ORDINAL)) + CONTROL_PORT ))

# Use localhost when multiCluster is false, external IP when true
if [ "${MULTI_CLUSTER}" = "false" ]; then
    # Connect to localhost (same pod)
    URL=https://localhost:8008/patroni
else
    URL=https://[${IP}]:${NEW_CONTROL_PORT}/patroni
fi

# Launch Patroni exporter
patroni_exporter --patroni-url ${URL} --port $PATRONI_EXPORTER_PORT --address-family $PATRONI_EXPORTER_ADDRESS_FAMILY --timeout $PATRONI_EXPORTER_TIMEOUT --requests-verify $PATRONI_EXPORTER_REQUEST_VERIFY
