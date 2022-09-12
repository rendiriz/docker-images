#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source ${DIR}/helper/functions.sh
source ${DIR}/env.sh

CA="${SERVER_NAME}-${STATE,,}-${SERVER_NO}"

#-------------------------------------------------------------------------------

# Do preflight checks
preflight_checks || exit

# Stop existing Docker containers
${DIR}/stop.sh

if [[ "$CLEAN" == "true" ]] ; then
  CLEAN=true
  clean_env
else
  CLEAN=false
fi

if [[ "$CLEAN" == "true" ]] ; then
  create_certificates
fi

#-------------------------------------------------------------------------------

# Bring up base cluster and Confluent CLI
docker-compose up -d zookeeper kafka1 kafka2 tools

# Add root CA to container (obviates need for supplying it at CLI login '--ca-cert-path')
docker-compose exec tools bash -c "cp /etc/kafka/secrets/${CA}.crt /usr/local/share/ca-certificates && /usr/sbin/update-ca-certificates"

#-------------------------------------------------------------------------------

# Build custom Kafka Connect image with required jars
if [[ "$CLEAN" == "true" ]] ; then
  build_connect_image || exit 1
fi

# Bring up more containers
# docker-compose up -d schemaregistry connect control-center
docker-compose up -d schemaregistry connect kafka-ui

echo
echo -e "Create topics in Kafka cluster:"
docker-compose exec tools bash -c "USERNAME=admin PASSWORD=admin-secret /tmp/helper/create-topics.sh" || exit 1

# Verify Kafka Connect Worker has started
MAX_WAIT=240
echo -e "\nWaiting up to $MAX_WAIT seconds for Connect to start"
retry $MAX_WAIT host_check_connect_up "connect" || exit 1
sleep 2 # give connect an exta moment to fully mature

NUM_CERTS=$(docker-compose exec connect keytool --list --keystore /etc/kafka/secrets/kafka.connect.truststore.jks --storepass $SSL_PASSWORD | grep trusted | wc -l)
if [[ "$NUM_CERTS" -eq "1" ]]; then
  echo -e "\nERROR: Connect image did not build properly.  Expected ~147 trusted certificates but got $NUM_CERTS. Please troubleshoot and try again."
  exit 1
fi