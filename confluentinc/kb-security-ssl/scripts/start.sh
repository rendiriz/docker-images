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