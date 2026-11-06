#!/bin/bash

set -x
export RUST_BACKTRACE=1
export RUST_LOG=debug,sqlx_todo=info,actix=info,actix_web=debug,actix_server=debug

cp /etc/mdcap/certs/* /mdcap

exec /mdcap/estore