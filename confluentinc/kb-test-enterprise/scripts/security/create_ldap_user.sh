#!/bin/bash

CA_PATH=$( dirname ${BASH_SOURCE[0]})

index=$1
uidNumber=$( expr $index + 10000 )

touch ${CA_PATH}/ldap_users/${index}_${USERNAME}.ldif

tee ${CA_PATH}/ldap_users/${index}_${USERNAME}.ldif <<EOF
dn: cn=${USERNAME},ou=users,{{ LDAP_BASE_DN }}
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: ${USERNAME}
sn: ${ORGANIZATION^}
givenName: ${USERNAME^^}
cn: ${USERNAME}
displayName: ${USERNAME^^} ${ORGANIZATION^}
uidNumber: ${uidNumber}
gidNumber: 5000
userPassword: ${PASSWORD}
gecos: ${USERNAME}
loginShell: /bin/bash
homeDirectory: /home/${USERNAME}

EOF