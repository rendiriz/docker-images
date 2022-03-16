#!/bin/bash

retry() {
  local -r -i max_wait="$1"; shift
  local -r cmd="$@"

  local -i sleep_interval=5
  local -i curr_wait=0

  until $cmd
  do
    if (( curr_wait >= max_wait ))
    then
      echo "ERROR: Failed after $curr_wait seconds. Please troubleshoot and run again. For troubleshooting instructions see https://docs.confluent.io/platform/current/tutorials/cp-demo/docs/troubleshooting.html"
      return 1
    else
      printf "."
      curr_wait=$((curr_wait+sleep_interval))
      sleep $sleep_interval
    fi
  done

  PRETTY_PASS="\e[32m✔ \e[0m"
  printf "${PRETTY_PASS}%s\n\n"
}

verify_installed()
{
  local cmd="$1"
  if [[ $(type $cmd 2>&1) =~ "not found" ]]; then
    echo -e "\nERROR: This script requires '$cmd'. Please install '$cmd' and run again.\n"
    exit 1
  fi
  return 0
}

preflight_checks()
{
  # Verify appropriate tools are installed on host
  for cmd in curl jq docker-compose keytool docker openssl xargs awk; do
    verify_installed $cmd || exit 1
  done

  # Verify Docker daemon is running
  docker ps -q || exit 1

  # Verify Docker memory is at least 8 GB
  if [[ $(docker system info --format '{{.MemTotal}}') -lt 8000000000 ]]; then
    echo -e "\nWARNING: Memory available to Docker should be at least 8 GB (default is 2 GB), otherwise cp-demo may not work properly.\n"
    if [[ "$VIZ" == "true" ]]; then
      echo -e "ERROR: Cannot proceed with Docker memory less than 8 GB when 'VIZ=true' (enables Elasticsearch and Kibana).  Either increase memory available to Docker or restart cp-demo with 'VIZ=false' (see https://docs.confluent.io/platform/current/tutorials/cp-demo/docs/index.html#start)\n"
      exit 1
    fi
    sleep 3
  fi

  # Verify Docker CPU cores is increased to at least 2
  if [[ $(docker system info --format '{{.NCPU}}') -lt 2 ]]; then
    echo -e "\nWARNING: Number of CPU cores available to Docker must be at least 2, otherwise cp-demo may not work properly.\n"
    sleep 3
  fi

  return 0
}

clean_env()
{
  local DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

  echo "CLEAN=true -> deleting existing certificates and local Connect Docker image"

  # Remove existing keys and certificates
  (cd ${DIR}/../security && ./certs-clean.sh)
}

create_certificates()
{
  local DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

  # Generate keys and certificates used for SSL
  echo -e "Generate keys and certificates used for SSL (see ${DIR}/security)"
  # Install findutils to be able to use 'xargs' in the certs-create.sh script
  docker run -v ${DIR}/../security/:/etc/kafka/secrets/ -u0 $REPOSITORY/cp-server:${CONFLUENT_DOCKER_TAG} bash -c "yum -y install findutils; cd /etc/kafka/secrets && ./certs-create.sh && chown -R $(id -u $USER):$(id -g $USER) /etc/kafka/secrets"
  
  # Generating public and private keys for token signing
  echo "Generating public and private keys for token signing"
  docker run -v ${DIR}/../security/:/etc/kafka/secrets/ -u0 $REPOSITORY/cp-server:${CONFLUENT_DOCKER_TAG} bash -c "mkdir -p /etc/kafka/secrets/keypair; openssl genrsa -out /etc/kafka/secrets/keypair/keypair.pem 2048; openssl rsa -in /etc/kafka/secrets/keypair/keypair.pem -outform PEM -pubout -out /etc/kafka/secrets/keypair/public.pem && chown -R $(id -u $USER):$(id -g $USER) /etc/kafka/secrets/keypair"

  # Enable Docker appuser to read files when created by a different UID
  echo -e "Setting insecure permissions on some files in ${DIR}/../security for demo purposes\n"
  chmod 644 ${DIR}/../security/keypair/keypair.pem
  chmod 644 ${DIR}/../security/*.key
}