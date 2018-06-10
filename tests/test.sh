#!/bin/bash

CURL=$(which curl 2> /dev/null)
NC=$(which nc 2> /dev/null)
NC_OPTS="-z"


inspect() {

  echo "inspect needed containers"
  for d in etcd
  do
    # docker inspect --format "{{lower .Name}}" ${d}
    docker inspect --format '{{with .State}} {{$.Name}} has pid {{.Pid}} {{end}}' ${d}
  done
}

api_request() {

  node=$1

  code=$(curl \
    --silent \
    http://localhost:2379/health)

  if [[ $? -eq 0 ]]
  then
    echo "api request are successfull"

    health=$(echo "${code}" | jq --raw-output .health)

    code=$(curl \
      --silent \
      --location\
      http://127.0.0.1:2379/version)

    etcd_server=$(echo "${code}" | jq --raw-output .etcdserver)
    etcd_cluster=$(echo "${code}" | jq --raw-output .etcdcluster)

    if [[ "${health}" = "true" ]]
    then
      echo "version of etcd server ${etcd_server} and etcd cluster ${etcd_cluster}"
    else
      echo "unhealty "
    fi

  else
    echo ${code}
    echo "api request failed"
  fi
}

inspect
api_request

exit 0
