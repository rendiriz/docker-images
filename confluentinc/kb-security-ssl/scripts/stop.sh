#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source ${DIR}/security/config.env
source ${DIR}/env.sh

docker-compose down --volumes
