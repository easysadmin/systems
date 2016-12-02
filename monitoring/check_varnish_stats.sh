#!/bin/bash
#------------------------------------------------------------------------------
# [Syspixel] Check Varnish Stats
# 	     Nagios check for Varnish API Agent with perfdata
#
# Dependences: https://www.varnish-cache.org/
#
# TODO
# [] getopts arguments
# [] check flag 'b'
#------------------------------------------------------------------------------
VERSION=1.1

# Print help
_usage() {
echo "Usage: check_varnish_stats.sh [-h help] -H <host> [-P port] -u <user> -p <password> -f <field> -w <warning> -c <critical>

  -h, --help	Print this help message
  host		Host where is Varnish API Agent
  port		Port where Varnish Agent listen
  user		Varnish Agent
  pass		Varnish Agent password
  field		Field of Varnish API to check (see with command \"varnishstat -l\")
  warning	Warning value
  critical	Critical value
  
  Exit status:
  0  if OK
  1  if minor problems (e.g., cannot create a temp file)
  2  if serious trouble (e.g., cannot access command-line argument)
  3  unknown
  "
	exit 0;
}

# Save value_tmp for counters
_persistanceValue() {
	if [[ ! -f /tmp/${HOST}_${FIELD} ]]; then
		touch /tmp/${HOST}_${FIELD}
		echo $VALUE > /tmp/${HOST}_${FIELD}
	fi
}

# Calculate the result
_returnValue() {
	if [[ $FLAG == "c" ]]; then
		_persistanceValue
		VALUE_TEMP=$(expr $VALUE - $(</tmp/${HOST}_${FIELD}))
		echo $VALUE > /tmp/${HOST}_${FIELD}
		echo $VALUE_TEMP
	else
		echo $VALUE
	fi
}

# Alarm
_main() {
	if [[ $RESULT -ge $CRITICAL ]]; then
		# STATE_CRITICAL
		echo "VARNISH $FIELD CRITICAL - $RESULT $PERF_DATA"
		exit $STATE_CRITICAL
	elif [[ $RESULT -ge $WARNING ]]; then
		# Warning
		echo "VARNISH $FIELD WARNING - $RESULT $PERF_DATA"
		exit $STATE_WARNING
	else
		# Correcto
		echo "VARNISH $FIELD OK - $RESULT $PERF_DATA"
		exit $STATE_OK
	fi
}

# Checks
if [[ ! $(which jq) ]]; then
	echo "jq isn't installed. Please install it."
	exit 1;
fi

# Arguments
while getopts ":H:u:p:f:w:c:P:h" opt; do
  case $opt in
    h)
      _usage
      echo "help"
      exit 1
      ;;
    H)
      HOST=$OPTARG;;
    u)
      USER=$OPTARG;;
    p)
      PASS=$OPTARG;;
    f)
      FIELD=$OPTARG;;
    w)
      WARNING=$OPTARG;;
    c)
      CRITICAL=$OPTARG;;
    P)
      if [[ ! -z "$OPTARG" ]]; then
              PORT=$OPTARG
      fi
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      _usage
      exit 2
      ;;
    :)
      echo "Requiere an argument: -$OPTARG" >&2
      _usage
      exit 2
      ;;
  esac
done

# Check arguments
if [[ -z "$HOST" || -z "$USER" || -z "$PASS" || -z "$FIELD" || -z "$WARNING" || -z "$CRITICAL" ]]; then
        echo "Empty obligatory arguments."
        _usage
        exit 1
elif [[ -z "$PORT" ]]; then
	PORT=6085
fi

# Vars
JSON=$(curl -s -u ${USER}:${PASS} http://${HOST}:${PORT}/stats/ | jq -S ".\"${FIELD}\"")
FLAG=$(echo ${JSON} | jq '.flag' | sed -e 's/"//g')
VALUE=$(echo ${JSON} | jq '.value')
DESCRIPTION=$(echo ${JSON} | jq '.description' | sed -e 's/ /_/g')
RESULT=$(_returnValue)
PERF_DATA="| ${DESCRIPTION}=${RESULT};${WARNING};${CRITICAL};0"

# Exit codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3


# Main #####################################################

if [[ -z "$JSON" ]]; then
	exit 2
fi

if [[ "$FLAG" == "b" ]]; then
	echo $STATE_UNKNOWN
else
	_main
fi
