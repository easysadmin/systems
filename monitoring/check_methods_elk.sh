#!/bin/bash
#------------------------------------------------------------------------------
# [Syspixel] Check ELK Methods 
# 	     Nagios check for ELK API 
#
# Dependencies: https://stedolan.github.io/jq/
#  		
#
#------------------------------------------------------------------------------
VERSION=0.2

# Exit codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

# Print help
_usage() {
echo "Usage: check_cms_services.sh [-h help] -H <host> [-P port] -m <method> -w <warning> -c <critical> [-p path]

  -h	Print this help message
  -H	Host where is ELK API
  -m	HTTP's method (GET, POST...)
  -P	Port where ELK listen
  -p 	Path for GET method
  -w	Warning value
  -c	Critical value
  
  Exit status:
  0  if OK
  1  if minor problems (e.g., cannot create a temp file)
  2  if serious trouble (e.g., cannot access command-line argument)
  3  unknown"
}

# Arguments
while getopts "h:P:p:H:m:w:c:" opt; do
	case $opt in
		h)
			_usage 
			exit $STATE_OK
			;;
		H)
			HOST=$OPTARG
			;;
		m)
			METHOD=$OPTARG
			;;
		p)
			GET_PATH=$OPTARG
			;;
		c)
			CRITICAL=$OPTARG
			;;
		w)
			WARNING=$OPTARG
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

# Save temp value for counters
_persistanceValue() {
	if [ "$METHOD" == "POST" ]; then
		if [ ! -f /tmp/${HOST}_${METHOD} ]; then
			echo $VALUE > /tmp/${HOST}_${METHOD}
		fi
	else
		if [ ! -f /tmp/${HOST}_${METHOD}_${CLEAN_PATH} ]; then
			echo $VALUE > /tmp/${HOST}_${METHOD}_${CLEAN_PATH}
		fi
	fi
}

# Less than zero
_lessZero() {
	if [ "$METHOD" == "POST" ]; then
		OPERATION=$(expr $VALUE - $(</tmp/${HOST}_${METHOD}))
	else
		OPERATION=$(expr $VALUE - $(</tmp/${HOST}_${METHOD}_${CLEAN_PATH}))
	fi

        if [ $OPERATION -lt 0 ]; then
                OPERATION=0
                echo $OPERATION
        else
                echo $OPERATION
        fi
}

# Calculate the result
_returnValue() {
	_persistanceValue
	VALUE_TEMP=$(_lessZero)
	if [ "$METHOD" == "POST" ]; then
		echo $VALUE > /tmp/${HOST}_${METHOD}
	else
		echo $VALUE > /tmp/${HOST}_${METHOD}_${CLEAN_PATH}
	fi
	echo $VALUE_TEMP
}

_main(){
	if [ "$RESULT" -ge "$CRITICAL" ]; then
		echo "METHOD $METHOD CRITICAL - $RESULT $METHOD $PERF_DATA"
		exit $STATE_CRITICAL
	elif [ "$RESULT" -ge "$WARNING" ]; then
		echo "METHOD $METHOD WARNING - $RESULT $METHOD $PERF_DATA"
		exit $STATE_WARNING
	else
		echo "METHOD $METHOD OK - $RESULT $METHOD $PERF_DATA"
		exit $STATE_OK
	fi
}

# Check empty arguments
if [[ -z $HOST || -z $METHOD || -z $WARNING || -z $CRITICAL ]]; then
        echo "Empty obligatory arguments"
        _usage
        exit $STATE_WARNING
elif [ -z $PORT ]; then
	PORT=9200
fi

# Check if jq is installed
if [ ! $(which jq) ]; then
	echo "jq isn't installed. Please install it"
	exit $STATE_CRITICAL
fi

# Clean path for GET methods
if [ ! -z "$GET_PATH" ]; then 
	CLEAN_PATH=$(echo ${GET_PATH##*/})
fi

# Vars
if [ "$METHOD" == "POST" ]; then
	JSON=$(curl -sN -X$METHOD http://${HOST}:${PORT}/_search -d "{\"query\":{\"bool\":{\"must\":[{\"match_phrase\":{\"method\":{\"query\":\"$METHOD\"}}},{\"match_phrase\":{\"http.request.headers.content-type\":{\"query\":\"application/json\"}}},{\"match_phrase\":{\"port\":{\"query\":\"8181\"}}}]}}}")
else
	JSON=$(curl -sN -X$METHOD http://${HOST}:${PORT}/_search -d "{\"query\":{\"bool\":{\"must\":[{\"match_phrase\":{\"method\":{\"query\":\"$METHOD\"}}},{\"match_phrase\":{\"path\":{\"query\":\"$GET_PATH\"}}}]}}}")
fi
VALUE=$(echo $JSON | jq '.hits.total')
RESULT=$(_returnValue)
DESCRIPTION="requests"
PERF_DATA="$DESCRIPTION| $METHOD $DESCRIPTION=$RESULT;$WARNING;$CRITICAL;0"


# Main #####################################################
if [ -z "$JSON" ]; then
	exit $STATE_CRITICAL
else
	_main
fi
