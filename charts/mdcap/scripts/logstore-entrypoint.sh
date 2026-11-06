#!/bin/bash

set -x
export RUST_BACKTRACE=1
export RUST_LOG=debug,sqlx_todo=info,actix=info,actix_web=debug,actix_server=debug

if [ -d /logstore-binary ]; then
    cp /logstore-binary/* /mdcap/
fi

cp /.robin/scripts/certs/* /mdcap

exec /mdcap/logstore