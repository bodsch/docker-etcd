#!/bin/sh

set -x

IP=$(ip -o a |grep eth0 | awk -F ' ' '{print($4)}' | awk -F '/' '{print($1)}')


if [ "${1:0:1}" = '-' ]; then
  set -- etcd "$@"
fi

exec $@ --listen-client-urls http://${IP}:2379 --advertise-client-urls http://${IP}:2380
