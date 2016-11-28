#!/bin/bash

################################################################################
# Author: Ivan Alejandro						       #
# Version: 1.0								       #
################################################################################
#
# Alarmas para los stats de Varnish
#

# ARGUMENTS
HOST="$1"
USER="$2"
PASS="$3"
FIELD="$4"
WARNING="$5"
CRITICAL="$6"

# VARS
PORT=6085
JSON=$(curl -s -u ${USER}:${PASS} http://${HOST}:${PORT}/stats/ | jq -S ".\"${FIELD}\"")
VALUE=$(echo ${JSON} | jq '.value')
DESCRIPTION=$(echo ${JSON} | jq '.description' | sed -e 's/ /_/g')
PERF_DATA="| $DESCRIPTION=$VALUE;$WARNING;$CRITICAL;0"


# EXIT CODES
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

# Main #####################################################

if [ $VALUE -ge $CRITICAL ]; then
	# STATE_CRITICAL
	echo "VARNISH $FIELD CRITICAL - $VALUE $PERF_DATA"
	exit $STATE_CRITICAL
elif [ $VALUE -ge $WARNING ]; then
	# Warning
	echo "VARNISH $FIELD WARNING - $VALUE $PERF_DATA"
	exit $STATE_WARNING
else
	# Correcto
	echo "VARNISH $FIELD OK - $VALUE $PERF_DATA"
	exit $STATE_OK
fi
