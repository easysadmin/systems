#!/usr/bin/env bash
#------------------------------------------------------------------------------
# [Syspixel] Check Varnish Stats
# 	     Nagios check for Varnish API Agent with perfdata
#
# Dependencies: https://www.varnish-cache.org/
#  		https://stedolan.github.io/jq/
#
# TODO
# - Clean code
# - Check flag 'b'
#------------------------------------------------------------------------------
VERSION=1.2.4

# Debug (activate: 1)
DEBUG=0
DIR_LOG="/var/log/varnish_log/"

# Exit codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

# Print help
_usage() {
echo "Usage: check_varnish_stats.sh [-h help] -H <host> [-P port] -u <user> -p <password> -f <field> [-t type] -w <warning> -c <critical>

  -h	Print this help message
  -H	Host where is Varnish API Agent
  -P	Port where Varnish Agent listen
  -u	Varnish Agent
  -p	Varnish Agent password
  -f	Field of Varnish API to check (see with command \"varnishstat -l\") or HIT_RATE
  -t	Specific type flag
  -w	Warning value
  -c	Critical value
  
  Exit status:
  0  if OK
  1  if minor problems (e.g., cannot create a temp file)
  2  if serious trouble (e.g., cannot access command-line argument)
  3  unknown"
}

# Save debug
_debug() {
	if [ ! -d $DIR_LOG ]; then
		mkdir -p $DIR_LOG
		chown nagios: $DIR_LOG
	fi
}

# Save temp value for counters
_persistanceValue() {
	if [ ! -f /tmp/${HOST}_${FIELD} ]; then
		echo $VALUE > /tmp/${HOST}_${FIELD}
	fi
}

# Calculate the result
_calcResult() {
	OPERATION=$(expr $VALUE - $(</tmp/${HOST}_${FIELD}))
	if [ $OPERATION -lt 0 ]; then
 		OPERATION=0
		echo $OPERATION
	else
		echo $OPERATION
	fi
}

# HIT Rate value
_hitrate() {
	if [[ $HIT -eq 0 && $MISS -eq 0 ]]; then
		VALUE=0
	else
		VALUE=$(( ($HIT * 100) / ($HIT + $MISS) ))
	fi
	echo $VALUE
}

# Return the result
_returnValue() {
	if [ $FLAG == "c" ]; then
		_persistanceValue
		VALUE_TEMP=$(_calcResult)

		# Debug
		if [ $DEBUG == 1 ]; then
			_debug
			echo "$VALUE - $(cat /tmp/${HOST}_${FIELD}) = $VALUE_TEMP [$(date)]" >> ${DIR_LOG}${HOST}_${FIELD}
		fi

		echo $VALUE > /tmp/${HOST}_${FIELD}
		echo $VALUE_TEMP
	else
		# Debug
		if [ $DEBUG == 1 ]; then
			_debug
			echo "$VALUE [$(date)]" >> ${DIR_LOG}${HOST}_${FIELD}
		fi

		echo $VALUE
	fi
}

# Nagios check
_main() {
	if [[ $RESULT -ge $CRITICAL ]]; then
		echo "VARNISH $FIELD CRITICAL - $RESULT $PERF_DATA"
		exit $STATE_CRITICAL
	elif [[ $RESULT -ge $WARNING ]]; then
		echo "VARNISH $FIELD WARNING - $RESULT $PERF_DATA"
		exit $STATE_WARNING
	else
		echo "VARNISH $FIELD OK - $RESULT $PERF_DATA"
		exit $STATE_OK
	fi
}

_mainhit() {
	if [[ $RESULT -le $CRITICAL ]]; then
		echo "VARNISH $FIELD CRITICAL - $RESULT $PERF_DATA"
		exit $STATE_CRITICAL
	elif [[ $RESULT -le $WARNING ]]; then
		echo "VARNISH $FIELD WARNING - $RESULT $PERF_DATA"
		exit $STATE_WARNING
	else
		echo "VARNISH $FIELD OK - $RESULT $PERF_DATA"
		exit $STATE_OK
	fi
}

# Arguments
while getopts ":H:u:p:f:t:w:c:P:h" opt; do
	case $opt in
		h) 
			_usage 
			exit $STATE_OK
			;;
		H) 
			HOST=$OPTARG
			;;
		u)
		       	USER=$OPTARG
			;;
		p) 
			PASS=$OPTARG
			;;
		f) 
			FIELD=$OPTARG
			;;
		w) 
			WARNING=$OPTARG
			;;
		c) 
			CRITICAL=$OPTARG
			;;
		t)
			if [ ! -z "$OPTARG" ]; then
				FLAG=$OPTARG
			fi
			;;
		P) 
			if [ ! -z "$OPTARG" ]; then
				PORT=$OPTARG
			fi
			;;
		\?) 
			echo "Invalid option: -$OPTARG" >&2
			_usage
			exit $STATE_CRITICAL
			;;
		:) 
			echo "Requiere an argument: -$OPTARG" >&2
			_usage
			exit $STATE_CRITICAL
			;;
	esac
done

# Check empty arguments
if [[ -z $HOST || -z $USER || -z $PASS || -z $FIELD || -z $WARNING || -z $CRITICAL ]]; then
        echo "Empty obligatory arguments"
        _usage
        exit $STATE_WARNING
elif [ -z $PORT ]; then
	PORT=6085
fi

# Check if jq is installed
if [ ! $(which jq) ]; then
	echo "jq isn't installed. Please install it"
	exit $STATE_CRITICAL
fi

# Validate request
REQUEST=$(curl -sI -u ${USER}:${PASS} http://${HOST}:${PORT}/status/ | head -1)
STATUS_CODE=$(echo $REQUEST | awk '{ print $2 }')
if [[ -z $REQUEST ]]; then
	echo "Request failed"
	exit $STATE_CRITICAL
elif [[ $STATUS_CODE != 200 ]]; then
	echo "Something has gone wrong. $REQUEST"
	exit $STATE_CRITICAL
fi

# Validate field
if [ $FIELD != "HIT_RATE" ]; then
	JSON=$(curl -sN -u ${USER}:${PASS} http://${HOST}:${PORT}/stats/ | jq -e -S ".\"${FIELD}\"")
else
	JSON=$(curl -sN -u ${USER}:${PASS} http://${HOST}:${PORT}/stats/)
fi

if [ $? != 0 ]; then
	echo "Something has gone wrong. jq says: $JSON"
	exit $STATE_CRITICAL
fi

# Vars
if [ -z $FLAG ]; then
	FLAG=$(echo $JSON | jq '.flag' | sed -e 's/"//g')
fi

# Main ##########################################

if [[ -z "$JSON" ]]; then
	exit $STATE_CRITICAL

elif [[ $FIELD == "HIT_RATE" ]]; then
	# Change flag to save values 
	FLAG="c"

	# Save hit
	VALUE=$(echo $JSON | jq -e -S ".\"MAIN.cache_hit\".value")
	FIELD="MAIN.cache_hit_hr"
	HIT=$(_returnValue)
	
	# Save miss
	VALUE=$(echo $JSON | jq -e -S ".\"MAIN.cache_miss\".value")
	FIELD="MAIN.cache_miss_hr"
	MISS=$(_returnValue)

	# Main value
	FIELD="HIT_RATE"
	DESCRIPTION="hit rate"
	RESULT=$(_hitrate)
	PERF_DATA="$DESCRIPTION| $DESCRIPTION=$RESULT;$WARNING;$CRITICAL;0"
	_mainhit


elif [[ $FLAG == "c" || $FLAG == "g" ]]; then 
	VALUE=$(echo $JSON | jq '.value')
	DESCRIPTION=$(echo $JSON | jq '.description' | sed -e 's/"//g' | sed -e 's/ /_/g')
	RESULT=$(_returnValue)
	PERF_DATA="$DESCRIPTION| $DESCRIPTION=$RESULT;$WARNING;$CRITICAL;0"
	_main

else
	exit $STATE_UNKNOWN
fi
