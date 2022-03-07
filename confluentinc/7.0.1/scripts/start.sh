#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source ${DIR}/helper/functions.sh
source ${DIR}/env.sh

#-------------------------------------------------------------------------------

# Do preflight checks
preflight_checks || exit

# Stop existing Docker containers
# ${DIR}/stop.sh

# Regenerate certificates and the Connect Docker image if any of the following conditions are true
if [[ "$CLEAN" == "true" ]] || \
 ! [[ -f "${DIR}/security/controlCenterAndKsqlDBServer-ca1-signed.crt" ]] || \
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