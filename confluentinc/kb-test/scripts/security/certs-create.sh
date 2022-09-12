#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source ${DIR}/config.env

#set -o nounset \
#    -o errexit \
#    -o verbose \
#    -o xtrace

# Cleanup files
rm -f *.crt *.csr *_creds *.jks *.srl *.key *.pem *.der *.p12 *.log

# Generate CA key
CA="${SERVER_NAME}-${STATE,,}-${SERVER_NO}"

openssl req -new -x509 -keyout ${CA}.key -out ${CA}.crt -days 3650 -subj '/CN=wj1.test.kitabikin.com/OU=KBTEST/O=KITABIKIN/L=BANDUNG/ST=WJ/C=ID' -passin pass:${SSL_PASSWORD} -passout pass:${SSL_PASSWORD}

# ksqlDB Server (ksqldb-server) and Control Center (control-center) share a commom certificate; a separate certificate is not generated for ksqldb-server
# this shared certificate has a self-signed WJ - when control-center presents the certificate to a browser visiting control-center at https://localhost:9092 ,
# it can be accepted without importing and trusting the self-signed WJ, and this acceptance will also apply later to WebSockets requests to wss://localhost:8089
# (port-forwarded to ksqldb-server:8089), serving the same certificate from ksqldb-server.
#
# This is necessary as browsers never prompt to trust certificates for this kind of wss:// connection, see https://stackoverflow.com/a/23036270/452210 .
#
users=(zookeeper kafka1 kafka2 mds client connect schemaregistry restproxy ksqlDBServer ksqlDBUser)
echo "Creating certificates"
printf '%s\0' "${users[@]}" | xargs -0 -I{} -n1 -P15 sh -c './certs-create-per-user.sh "$1" > "certs-create-$1.log" 2>&1 && echo "Created certificates for $1"' -- {}
echo "Creating certificates completed"

