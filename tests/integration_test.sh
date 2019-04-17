#!/bin/bash

wait_for_service() {

  echo -e "\nwait for the etcd service"

  RETRY=35
  # wait for the running certificate service
  #
  until [[ ${RETRY} -le 0 ]]
  do
    timeout 1 bash -c "cat < /dev/null > /dev/tcp/localhost/2379" 2> /dev/null
    result=${?}
    if [ ${result} -eq 0 ]
    then
      break
    else
      sleep 10s
      RETRY=$(( RETRY - 1))
    fi
  done

  if [[ $RETRY -le 0 ]]
  then
    echo "Could not connect to the etcd service"
    exit 1
  fi
}


cluster_state() {

  node=$1

  code=$(curl \
    --silent \
    http://localhost:2379/health)

  health=$(echo "${code}" | jq --raw-output .health 2> /dev/null)

  if [ $? -eq 0 ] && [ "${health}" = "true" ]
  then
    echo -e "etcd cluster are healthy\n"

    code=$(curl \
      --silent \
      --location\
      http://127.0.0.1:2379/version)

    etcd_server=$(echo "${code}" | jq --raw-output .etcdserver)
    etcd_cluster=$(echo "${code}" | jq --raw-output .etcdcluster)

    echo -e "version of etcd server ${etcd_server} and etcd cluster ${etcd_cluster}\n"

    curl \
      --silent \
      --location\
      http://127.0.0.1:2379/v2/members | jq

  else
    echo "etcd cluster are unhealty "
    echo "'${code}' - '${health}'"
  fi
}

random_string() {
  < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-128} ; echo
}

use_key_value() {

  local key="message"
  local value1="Hello world"
  local value2="Hello etcd"

  echo -e "\nSetting the value of a key"
  curl \
    --silent \
    --request PUT \
    --data value="${value1}" \
    "http://127.0.0.1:2379/v2/keys/${key}" | jq

  echo -e "\nGet the value of a key"
  curl \
    --silent \
    "http://127.0.0.1:2379/v2/keys/${key}" | jq

  echo -e "\nChanging the value of a key"
  curl \
    --silent \
    --request PUT \
    --data value="${value2}" \
    "http://127.0.0.1:2379/v2/keys/${key}" | jq

  echo -e "\nVerify the value of a key"
  curl \
    --silent \
    "http://127.0.0.1:2379/v2/keys/${key}" | jq

  echo -e "\nDeleting a key"
  curl \
    --silent \
    --request DELETE \
    "http://127.0.0.1:2379/v2/keys/${key}" | jq

  echo -e "\nusing key TTL"
  curl \
    --silent \
    --request PUT \
    --data value="${value1}" \
    --data ttl=5 \
    "http://127.0.0.1:2379/v2/keys/${key}" | jq

  echo -e "\nAtomically Creating In-Order Keys"
  curl \
    --silent \
    --request PUT \
    --data value=Job1 \
    http://127.0.0.1:2379/v2/keys/queue | jq

  curl \
    --silent \
    --request PUT \
    --data value=Job2 \
    http://127.0.0.1:2379/v2/keys/queue | jq

  curl \
    --silent \
    "http://127.0.0.1:2379/v2/keys/queue?recursive=true&sorted=true" | jq

  echo -e "\nlist directory"
  curl \
    --silent \
    http://127.0.0.1:2379/v2/keys/ | jq

  test_file="/tmp/etcd_teststring_$(date +%Y%m%d_%H%M)"

  random_string  > ${test_file}
  random_string >> ${test_file}
  random_string >> ${test_file}

  CHECKSUM_1=$(md5sum ${test_file})

  echo -e "\nupload file"
  curl \
    --silent \
    --request PUT \
    --data-urlencode value@${test_file} \
    http://127.0.0.1:2379/v2/keys/integration_test | jq

  echo -e "\ndownload file"
  data=$(curl \
    --silent \
    http://127.0.0.1:2379/v2/keys/integration_test)

  echo "${data}" | jq

  # remove trailing newline from string
  echo "${data}" | jq --raw-output '.node.value' | head -c -1  > ${test_file}_saved

  CHECKSUM_2=$(md5sum ${test_file}_saved)

  echo -e "\nverify"
  echo -e "$(cat ${test_file}) - ${CHECKSUM_1}"
  echo -e "\n$(cat ${test_file}_saved) - ${CHECKSUM_2}"

  rm -f /tmp/etcd_teststring*
}

inspect() {

  echo ""
  echo "inspect needed containers"
  for d in $(docker ps | tail -n +2 | awk  '{print($1)}')
  do
    # docker inspect --format "{{lower .Name}}" ${d}
    c=$(docker inspect --format '{{with .State}} {{$.Name}} has pid {{.Pid}} {{end}}' "${d}")
    s=$(docker inspect --format '{{json .State.Health }}' "${d}" | jq --raw-output .Status)

    printf "%-40s - %s\n"  "${c}" "${s}"
  done
}

inspect
wait_for_service
cluster_state
use_key_value

exit 0

