#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source ${DIR}/helper/functions.sh
source ${DIR}/env.sh

#-------------------------------------------------------------------------------

# Do preflight checks
preflight_checks || exit

# Stop existing Docker containers
${DIR}/stop.sh

# Regenerate certificates and the Connect Docker image if any of the following conditions are true
if [[ "$CLEAN" == "true" ]] || \
 ! [[ -f "${DIR}/security/controlCenterAndKsqlDBServer-wj1-signed.crt" ]] || \
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
  create_ldap_user
  create_certificates
fi

#-------------------------------------------------------------------------------

# Bring up openldap
docker-compose up -d openldap
sleep 5
if [[ $(docker-compose ps openldap | grep Exit) =~ "Exit" ]] ; then
  echo "ERROR: openldap container could not start. Troubleshoot and try again. For troubleshooting instructions see https://docs.confluent.io/platform/current/tutorials/cp-demo/docs/troubleshooting.html"
  exit 1
fi

# Bring up base cluster and Confluent CLI
docker-compose up -d zookeeper kafka1 kafka2 tools

# Verify MDS has started
MAX_WAIT=120
echo "Waiting up to $MAX_WAIT seconds for MDS to start"
retry $MAX_WAIT host_check_mds_up || exit 1
sleep 5

# Add root CA to container (obviates need for supplying it at CLI login '--ca-cert-path')
docker-compose exec tools bash -c "cp /etc/kafka/secrets/snakeoil-wj-1.crt /usr/local/share/ca-certificates && /usr/sbin/update-ca-certificates"

echo "Creating role bindings for principals"
docker-compose exec tools bash -c "USERNAME=${SUPER_USER} PASSWORD=${SUPER_PASSWORD} /tmp/helper/create-role-bindings.sh" || exit 1

# Workaround for setting min ISR on topic _confluent-metadata-auth
docker-compose exec kafka1 kafka-configs \
   --bootstrap-server kafka1:12091 \
   --entity-type topics \
   --entity-name _confluent-metadata-auth \
   --alter \
   --add-config min.insync.replicas=1

#-------------------------------------------------------------------------------

# Build custom Kafka Connect image with required jars
if [[ "$CLEAN" == "true" ]] ; then
  build_connect_image || exit 1
fi

# Bring up more containers
docker-compose up -d schemaregistry connect control-center

echo
echo -e "Create topics in Kafka cluster:"
docker-compose exec tools bash -c "USERNAME=${SUPER_USER} PASSWORD=${SUPER_PASSWORD} /tmp/helper/create-topics.sh" || exit 1

# Verify Confluent Control Center has started
MAX_WAIT=300
echo
echo "Waiting up to $MAX_WAIT seconds for Confluent Control Center to start"
retry $MAX_WAIT host_check_control_center_up || exit 1

echo -e "\nConfluent Control Center modifications:"
USERNAME=${CONTROLCENTERADMIN_USER} PASSWORD=${CONTROLCENTERADMIN_PASSWORD} ${DIR}/helper/control-center-modifications.sh
echo

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

echo
docker-compose up -d ksqldb-server ksqldb-cli restproxy
echo "..."

# Verify Docker containers started
if [[ $(docker-compose ps) =~ "Exit 137" ]]; then
  echo -e "\nERROR: At least one Docker container did not start properly, see 'docker-compose ps'. Did you increase the memory available to Docker to at least 8 GB (default is 2 GB)?\n"
  exit 1
fi

#-------------------------------------------------------------------------------

# Verify ksqlDB server has started
echo
echo
MAX_WAIT=120
echo -e "\nWaiting up to $MAX_WAIT seconds for ksqlDB server to start"
retry $MAX_WAIT host_check_ksqlDBserver_up || exit 1

#-------------------------------------------------------------------------------

echo
echo -e "\nAvailable LDAP users:"
#docker-compose exec openldap ldapsearch -x -h localhost -b dc=confluentdemo,dc=io -D "cn=admin,dc=confluentdemo,dc=io" -w admin | grep uid:
curl -u ${MDS_USER}:${MDS_PASSWORD} -X POST "https://localhost:8091/security/1.0/principals/User%3Amds/roles/UserAdmin" \
  -H "accept: application/json" -H "Content-Type: application/json" \
  -d "{\"clusters\":{\"kafka-cluster\":\"does_not_matter\"}}" \
  --cacert scripts/security/snakeoil-wj-1.crt --tlsv1.2
curl -u ${MDS_USER}:${MDS_PASSWORD} -X POST "https://localhost:8091/security/1.0/rbac/principals" --silent \
  -H "accept: application/json"  -H "Content-Type: application/json" \
  -d "{\"clusters\":{\"kafka-cluster\":\"does_not_matter\"}}" \
  --cacert scripts/security/snakeoil-wj-1.crt --tlsv1.2 | jq '.[]'

# Do poststart_checks
poststart_checks

cat << EOF

----------------------------------------------------------------------------------------------------
DONE! From your browser:

  Confluent Control Center (login superuser/entersuperuser for full access):
     $C3URL

EOF