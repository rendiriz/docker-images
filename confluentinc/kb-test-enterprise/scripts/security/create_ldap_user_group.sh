#!/bin/bash

CA_PATH=$( dirname ${BASH_SOURCE[0]})

command | tee -a ${CA_PATH}/ldap_users/999_group_add.ldif <<EOF
dn: cn=KafkaDevelopers,ou=groups,{{ LDAP_BASE_DN }}
changetype: modify
add: memberuid
memberuid: cn=${USERNAME},ou=users,{{ LDAP_BASE_DN }}

EOF