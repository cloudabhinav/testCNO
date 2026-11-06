#!/bin/bash

IAM_DIR="/var/run/secrets/iams"
MAX_AGE="${IAM_GC_MAX_AGE:-30}"

mkdir -p "$IAM_DIR"

while true; do
    sleep 5
    now=$(date +%s)
    for f in "$IAM_DIR"/*; do
        [ -f "$f" ] || continue
        mtime=$(stat -c %Y "$f" 2>/dev/null) || continue
        age=$(( now - mtime ))
        if [ "$age" -gt "$MAX_AGE" ]; then
            unlink "$f"
            echo "GC: unlinked stale IAM file $f (age ${age}s)"
        fi
    done
done
