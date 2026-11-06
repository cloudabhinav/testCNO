# Copyright (C) 2021 Robin.io All Rights Reserved.

#!/bin/sh

GRAFANA_PATH=/etc/grafana/provisioning
mkdir -p ${GF_PATHS_DATA}
mkdir -p ${GRAFANA_PATH}/datasources

# copy dashboards
mkdir -p ${GRAFANA_PATH}/dashboards/mdcap
mkdir -p ${GRAFANA_PATH}/dashboards/bm
mkdir -p ${GRAFANA_PATH}/dashboards/vm
mkdir -p ${GRAFANA_PATH}/dashboards/rc
cp /etc/grafana/mdcap/dashboards/* ${GRAFANA_PATH}/dashboards/mdcap

# copy datasource and providers
cp /etc/grafana/mdcap/configs/datasource.yaml ${GRAFANA_PATH}/datasources
cp /etc/grafana/mdcap/configs/provider.yaml ${GRAFANA_PATH}/dashboards

# replace placeholders
sed -i "s/MDCAP_NAME/${MDCAP_NAME}/g" ${GRAFANA_PATH}/datasources/datasource.yaml
sed -i "s/MDCAP_NS/${MDCAP_NS}/g" ${GRAFANA_PATH}/datasources/datasource.yaml

# run grafana cli to change admin password
output=$(grafana cli --config ${GF_PATHS_CONFIG} admin reset-admin-password ${GF_SECURITY_ADMIN_PASSWORD})
if [[ echo $? == 0 ]]; then
  echo "Grafana admin password updated successfully"
else
  echo "Failed to update Grafana admin password: $output"
fi

# launch grafana
/run.sh

