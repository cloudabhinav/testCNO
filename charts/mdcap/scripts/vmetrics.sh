#!/bin/sh

mkdir -p /victoria-metrics-data/victoria_metrics
mkdir -p /victoria-metrics-data/kubeconfigs

CONFIG=/victoria-metrics-data/config.yaml
FILE=/victoria-metrics-data/victoria_metrics/mdcap.yaml

# Prepare main vmetrics config file
if [ -f $CONFIG ]; then
    echo "File exits $CONFIG"
else
    echo '
scrape_config_files:
- /victoria-metrics-data/victoria_metrics/*.yaml
' > ${CONFIG}
fi

# Prepare mdcap vmetrics config file
if [ -f $FILE ]; then
    echo "File exits $FILE"
else
    echo '
- job_name: mdcap-engine
  scrape_interval: 60s
  scrape_timeout: 60s
  metrics_path: /api/v1/metrics
  scheme: https
  static_configs:
    - targets:
      - "MDCAP_NAME-engine.MDCAP_NS.svc.cluster.local:8000"
  tls_config:
    insecure_skip_verify: true

- job_name: mdcap-dashboard
  scrape_interval: 60s
  scrape_timeout: 60s
  metrics_path: /metrics
  scheme: https
  static_configs:
    - targets:
      - "MDCAP_NAME-dashboard.MDCAP_NS.svc.cluster.local:8000"
  tls_config:
    insecure_skip_verify: true

- job_name: mdcap-logstore
  scrape_interval: 60s
  scrape_timeout: 60s
  metrics_path: /metrics
  scheme: https
  static_configs:
    - targets:
      - "MDCAP_NAME-logstore.MDCAP_NS.svc.cluster.local:8000"
  tls_config:
    insecure_skip_verify: true

- job_name: mdcap-nginx
  scrape_interval: 60s
  scrape_timeout: 60s
  metrics_path: /metrics
  scheme: http
  static_configs:
    - targets:
      - "MDCAP_NAME-nginx-np-0.MDCAP_NS.svc.cluster.local:9113"

- job_name: mdcap-grafana
  scrape_interval: 60s
  scrape_timeout: 60s
  metrics_path: /metrics
  scheme: https
  static_configs:
    - targets:
      - "MDCAP_NAME-grafana.MDCAP_NS.svc.cluster.local:3000"
  tls_config:
    insecure_skip_verify: true

- job_name: mdcap-vmetrics
  scrape_interval: 60s
  scrape_timeout: 60s
  metrics_path: /metrics
  scheme: https
  static_configs:
    - targets:
      - "MDCAP_NAME-vmetrics.MDCAP_NS.svc.cluster.local:8428"
  tls_config:
    insecure_skip_verify: true

- job_name: mdcap-artifactory
  scrape_interval: 60s
  scrape_timeout: 60s
  metrics_path: /metrics
  scheme: https
  static_configs:
    - targets:
      - "MDCAP_NAME-artifactory.MDCAP_NS.svc.cluster.local:8443"
  tls_config:
    insecure_skip_verify: true

- job_name: mdcap-eventmgr
  scrape_interval: 60s
  scrape_timeout: 60s
  metrics_path: /metrics
  scheme: https
  static_configs:
    - targets:
      - "MDCAP_NAME-eventmgr.MDCAP_NS.svc.cluster.local:8000"
  tls_config:
    insecure_skip_verify: true
' > ${FILE}
fi

# replace placeholders
sed -i "s/MDCAP_NAME/${MDCAP_NAME}/g" ${FILE}
sed -i "s/MDCAP_NS/${MDCAP_NS}/g" ${FILE}

if getent hosts $HOSTNAME | cut -d ' ' -f1 |  grep -q ':';then
    /victoria-metrics-prod -enableTCP6 -retentionPeriod ${METRICS_RETENTION_PERIOD} -tls -tlsCertFile /etc/mdcap/certs/cert.pem -tlsKeyFile /etc/mdcap/certs/key.pem -promscrape.config ${CONFIG} -promscrape.configCheckInterval ${CONFIG_CHECK_INTERVAL} -http.connTimeout 5m
else
    /victoria-metrics-prod -retentionPeriod ${METRICS_RETENTION_PERIOD} -tls -tlsCertFile /etc/mdcap/certs/cert.pem -tlsKeyFile /etc/mdcap/certs/key.pem -promscrape.config ${CONFIG} -promscrape.configCheckInterval ${CONFIG_CHECK_INTERVAL} -http.connTimeout 5m
fi

