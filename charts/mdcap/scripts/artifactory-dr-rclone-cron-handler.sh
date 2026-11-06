#!/bin/bash

echo "Initiating Rclone copy"
# Following line will be changed based on the site type(primary or standby), log verbosity level and bucket name
rclone --config $rclone_conf_file copy minio:$bucket /data -vvvvvvv
echo "Finished Rclone copy"
echo "----------------------------------------------------------------------"