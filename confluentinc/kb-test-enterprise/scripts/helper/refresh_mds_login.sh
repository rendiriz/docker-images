#!/bin/bash

################################## SETUP VARIABLES #############################
MDS_URL=https://kafka1:8091

SUPER_USER=superuser
SUPER_USER_PASSWORD=superuser

docker-compose exec tools bash -c ". /tmp/helper/functions.sh ; mds_login $MDS_URL ${SUPER_USER} ${SUPER_USER_PASSWORD}"
