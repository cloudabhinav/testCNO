#!/bin/bash

set -x

mkdir -p /scripts
cp -r /etc/scripts/* /scripts/

if [ -z "$DR_ROLE" ]; then
    echo -e "\e[31mEnsure that dr.role is given in values.yaml during helm install/upgrade \e[0m"
    exit 1
fi

if [ -z "$RCLONE_SCHEDULE" ]; then
    echo -e "\e[31mThe env RCLONE_SCHEDULE is not given in artifactory-dr-env configMap\e[0m"
    exit 1
fi

if [ -z "$MINIO_ACCESS_KEY_ID" ]; then
    echo -e "\e[31mThe env MINIO_ACCESS_KEY_ID is not given in artifactory-dr-env configMap\e[0m"
    exit 1
fi

if [ -z "$MINIO_SECRET_ACCESS_KEY" ]; then
    echo -e "\e[31mThe env MINIO_SECRET_ACCESS_KEY is not given in artifactory-dr-env configMap\e[0m"
    exit 1
fi

if [ -z "$MINIO_ENDPOINT" ]; then
    echo -e "\e[31mThe env MINIO_ENDPOINT is not given in artifactory-dr-env configMap\e[0m"
    exit 1
fi

if [ -z "$MINIO_REGION" ]; then
    echo -e "\e[31mThe env MINIO_REGION is not given in artifactory-dr-env configMap\e[0m"
    exit 1
fi

if [ -z "$MINIO_BUCKET_NAME" ]; then
    echo -e "\e[31mThe env MINIO_BUCKET_NAME is not given in artifactory-dr-env configMap\e[0m"
    exit 1
fi

export RCLONE_NO_CHECK_CERTIFICATE=true

DR_ROLE_lower=$(echo "$DR_ROLE" | tr '[:upper:]' '[:lower:]')

rclone_conf_file='/scripts/config/artifactory-dr-rclone.config'
rclone_log_file='/var/log/cron_rclone.log'
crontab_conf_file='/scripts/cron.conf'
rclone_cron_handler_file='/scripts/artifactory-dr-rclone-cron-handler.sh'
rclone_binary_path='/root/mdcapbin/rclone'

# Update the rclone config with minio details
sed -i "s|^endpoint =.*|endpoint = ${MINIO_ENDPOINT}|" "$rclone_conf_file"
sed -i "s|^region =.*|region = ${MINIO_REGION}|" "$rclone_conf_file"
sed -i "s|^secret_access_key =.*|secret_access_key = ${MINIO_SECRET_ACCESS_KEY}|" "$rclone_conf_file"
sed -i "s|^access_key_id =.*|access_key_id = ${MINIO_ACCESS_KEY_ID}|" "$rclone_conf_file"

# Update the rclone command in rclone_cron_handler_file depending upon DR_ROLE_lower, $RCLONE_LOG_VERBOSITY and $MINIO_BUCKET_NAME
if [ "$DR_ROLE_lower" == "standby" ]; then
    rclone_cmd="${rclone_binary_path} --config ${rclone_conf_file} copy minio:${MINIO_BUCKET_NAME} /data"

elif [ "$DR_ROLE_lower" == "primary" ]; then
    rclone_cmd="${rclone_binary_path} --config ${rclone_conf_file} copy /data minio:${MINIO_BUCKET_NAME}"

else
    echo -e "\e[31mIncorrect dr.role value. It should be one of ['primary', 'standby']\e[0m"
    exit 1
fi

if ! [[ $RCLONE_LOG_VERBOSITY =~ ^-v+$ ]]; then
  echo -e "\e[31mInvalid Verbosity string given\e[0m"
  echo "RCLONE_LOG_VERBOSITY env should start with '-' followed by number of 'v's. Example: '-v', '-vvv', '-vvvvv'"
  exit 1
fi

rclone_cmd="${rclone_cmd} $RCLONE_LOG_VERBOSITY"

sed -i "s|.*rclone --config.*|${rclone_cmd}|" "$rclone_cron_handler_file"

# Put the cron schedule in crontab config file
echo "$RCLONE_SCHEDULE $rclone_cron_handler_file >> $rclone_log_file 2>&1" > $crontab_conf_file

# launch the crontab service
crontab $crontab_conf_file
service cron start
sleep infinity
