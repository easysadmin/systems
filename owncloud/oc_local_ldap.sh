#! /bin/bash
set -e -u

# COLOR MESSAGES
OK=$(tput setaf 2)
ERR=$(tput setaf 1)
NC=$(tput sgr0)

# PARAMS
HOST=''
DATABASE=''
USER=''
PASS=''
MYSQL_COMMAND="mysql -h "${HOST}" -u"${USER}" --password="${PASS}" -h "${HOST}" -D "${DATABASE}" --disable-column-names -s -r -e"
MYSQL_COMMAND_FORMAT="mysql -u"${USER}" -D "${DATABASE}" -e"

# VARS
USER_ID="${1}"

update_accounts() {
        BACKEND="OCA\\\User_LDAP\\\User_Proxy"
        ${MYSQL_COMMAND} "UPDATE oc_accounts SET backend = \"${BACKEND}\" WHERE user_id = \"${USER_ID}\";"

        echo -e "[${OK}OK${NC}] Table OC_ACCOUNTS upgrade"
        ${MYSQL_COMMAND_FORMAT} "SELECT * FROM oc_accounts WHERE user_id = \"${USER_ID}\";"
}

update_ldap_user_mapping() {
        ${MYSQL_COMMAND} "UPDATE oc_ldap_user_mapping SET owncloud_name = \"${USER_ID}\" WHERE directory_uuid = \"${USER_ID}\";"

        echo -e "\n[${OK}OK${NC}] Table OC_LDAP_USER_MAPPING upgrade"
        ${MYSQL_COMMAND_FORMAT} "SELECT * FROM oc_ldap_user_mapping WHERE owncloud_name = \"${USER_ID}\" AND directory_uuid = \"${USER_ID}\";"
}

delete_user() {
        ${MYSQL_COMMAND} "DELETE FROM oc_users WHERE uid = \"${USER_ID}\";"

        COUNT_USER=$(${MYSQL_COMMAND} "SELECT COUNT(*) FROM oc_users WHERE uid = \"${USER_ID}\";")
        if [ "${COUNT_USER}" -eq "0" ]; then
                echo -e "\n[${OK}OK${NC}] Table OC_USERS upgrade [${OK}CORRECTO${NC}]"
		exit 0
        else
                echo -e "\n[${ERR}ERROR${NC}] Table OC_USERS couldn't upgrade [${ERR}ERROR${NC}]"
		exit 1
        fi
}

# Check user in LDAP
COUNT_USER=$(${MYSQL_COMMAND} "SELECT COUNT(*) FROM oc_accounts WHERE user_id = \"${USER_ID}\";")
if [ "${COUNT_USER}" -eq "1" ]; then
        update_accounts
        update_ldap_user_mapping
        delete_user
	exit 0
else
        echo -e "\n[${ERR}ERROR${NC}] You must upgrade ("${USER_ID}") manually"
	exit 1
fi
