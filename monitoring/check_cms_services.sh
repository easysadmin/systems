#!/usr/bin/env bash
#------------------------------------------------------------------------------
# [Syspixel] Check Cloudera Manager Services status
# 	     Nagios check for Cloudera Manager API 
#
# Dependencies: https://stedolan.github.io/jq/
#  		
#
# TODO
# Fix case sensitive in service's name
#------------------------------------------------------------------------------
VERSION=0.1

# Exit codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

# Print help
_usage() {
echo "Usage: check_cms_services.sh [-h help] -H <host> [-P port] -u <user> -p <password> -c <cluster> -s <service>

  -h	Print this help message
  -H	Host where is Cloudera Manager API
  -c	Cloudera Manager cluster's name
  -P	Port where Cloudera Manager listen
  -u	Cloudera Manager user
  -p	Cloudera Manager password
  -s	Service of Cloudera Manager API to check 
  
  Exit status:
  0  if OK
  1  if minor problems (e.g., cannot create a temp file)
  2  if serious trouble (e.g., cannot access command-line argument)
  3  unknown"
}

# Arguments
while getopts ":H:u:c:p:s:P:h" opt; do
	case $opt in
		h) _usage; exit $STATE_OK;;
		H) HOST=$OPTARG;;
		u) USER=$OPTARG;;
		c) CLUSTER=$OPTARG;;
		p) PASS=$OPTARG;;
		s) SERVICE=$OPTARG;;
		P) if [ ! -z "$OPTARG" ]; then
			PORT=$OPTARG
		   fi;;
		\?) echo "Invalid option: -$OPTARG" >&2; _usage; exit $STATE_CRITICAL;;
		:) echo "Requiere an argument: -$OPTARG" >&2; _usage; exit $STATE_CRITICAL;;
	esac
done

# Check empty arguments
if [[ -z $HOST || -z $USER || -z $PASS || -z $SERVICE || -z "$CLUSTER" ]]; then
        echo "Empty obligatory arguments"
        _usage
        exit $STATE_WARNING
elif [ -z $PORT ]; then
	PORT=7180
fi

# Check if jq is installed
if [ ! $(which jq) ]; then
	echo "jq isn't installed. Please install it"
	exit $STATE_CRITICAL
fi

# Validate field
REQUEST=$(curl -sI -u ${USER}:${PASS} http://${HOST}:${PORT}/api/v2/clusters/${CLUSTER}/services/${SERVICE} | head -1) #jq -e -S ".\"${FIELD}\"")
STATUS_CODE=$(echo $REQUEST | awk '{ print $2 }')
if [ $STATUS_CODE != 200 ]; then
	echo "Something has gone wrong. $REQUEST"
	exit $STATE_CRITICAL
fi

# Vars
JSON=$(curl -sN -u ${USER}:${PASS} http://${HOST}:${PORT}/api/v2/clusters/${CLUSTER}/services/${SERVICE})
VALUE=$(echo $JSON | jq '.healthSummary' | sed -e 's/"//g')
DESCRIPTION=$(echo $JSON | jq '.type' | sed -e 's/"//g') 

# Main #####################################################
if [ $VALUE == "BAD" ]; then
	echo "CM SERVICE $SERVICE CRITICAL - $DESCRIPTION $VALUE"
	exit $STATE_CRITICAL
else
	echo "CM SERVICE $SERVICE OK - $DESCRIPTION $VALUE"
	exit $STATE_OK
fi
