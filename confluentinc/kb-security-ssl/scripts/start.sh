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

if [[ "$CLEAN" == "true" ]] || \
  ! [[ $(docker images --format "{{.Repository}}:{{.Tag}}" localbuild/connect:${CONFLUENT_DOCKER_TAG}-${CONNECTOR_VERSION}) =~ localbuild ]] ;
then
  if [[ -z $CLEAN ]] || [[ "$CLEAN" == "false" ]] ; then
    echo "INFO: Setting CLEAN=true because minimum conditions (existing certificates and existing Docker image localbuild/connect:${CONFLUENT_DOCKER_TAG}-${CONNECTOR_VERSION}) not met"
  fi
  CLEAN=true
  clean_env
else
  CLEAN=false
fi

echo
echo "Environment parameters"
echo "  REPOSITORY=$REPOSITORY"
echo "  CONNECTOR_VERSION=$CONNECTOR_VERSION"
echo "  CLEAN=$CLEAN"
echo "  VIZ=$VIZ"
echo "  C3_KSQLDB_HTTPS=$C3_KSQLDB_HTTPS"
echo

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
docker-compose up -d schemaregistry connect

echo
echo -e "Create topics in Kafka cluster:"
docker-compose exec tools bash -c "/tmp/helper/create-topics.sh" || exit 1
