#!/bin/bash

set -x

rm -rf /etc/vector/vector.yaml

vector_config_file_path="/etc/vector/vector.toml"

# Checking if the required ENVs are provided in the config map
if [ -z "$DR_ROLE" ]; then
    echo -e "\e[31mEnsure that dr.role is given in values.yaml during helm install/upgrade \e[0m"
    exit 1
fi

if [ -z "$KAFKA_BOOTSTRAP_SERVER" ]; then
    echo -e "\e[31mThe env KAFKA_BOOTSTRAP_SERVER is not given in logstore-dr-env configMap\e[0m"
    exit 1
fi

if [ -z "$LOGSTORE_TOPIC_NAME" ]; then
    echo -e "\e[31mThe env LOGSTORE_TOPIC_NAME is not given in logstore-dr-env configMap\e[0m"
    exit 1
fi

# Converting DR_ROLE to lower to make it case-insensitive
DR_ROLE_lower=$(echo "$DR_ROLE" | tr '[:upper:]' '[:lower:]')

# Put the respective vector file in desired location based on DR_ROLE_lower
if [ "$DR_ROLE_lower" == "primary" ]; then
    cp /etc/mdcap/vector-config/logstore-vector-primary.toml $vector_config_file_path

    # Update topic name in vector config file as per envs
    sed -i "/topic/c\topic = \"$LOGSTORE_TOPIC_NAME\"" "$vector_config_file_path"

elif [ "$DR_ROLE_lower" == "standby" ]; then

    if [ -z "$CONSUMER_GROUP_ID" ]; then
        echo -e "\e[31mThe env CONSUMER_GROUP_ID is not given in configMap\e[0m"
        exit 1
    fi
    
    cp /etc/mdcap/vector-config/logstore-vector-standby.toml $vector_config_file_path
    # Update topic name in vector config file as per envs
    sed -i "/topics/c\topics = [ \"$LOGSTORE_TOPIC_NAME\" ]" "$vector_config_file_path"

else
    echo -e "\e[31mIncorrect dr.role value. It should be one of ['primary', 'standby']\e[0m"
    exit 1
fi

# Update bootstrap_servers in vector config file as per envs
sed -i "/bootstrap_servers/c\bootstrap_servers = \"$KAFKA_BOOTSTRAP_SERVER\"" "$vector_config_file_path"

# start vector
vector -c $vector_config_file_path