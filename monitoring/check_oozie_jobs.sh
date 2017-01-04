#!/bin/bash
#------------------------------------------------------------------------------
# [Syspixel] Check Oozie Jobs
# 	     Nagios check for Oozie Jobs
#
# 
#
# TODO
# 
#------------------------------------------------------------------------------
VERSION=0.1

# Exit codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

# Print help
_usage() {
echo "Usage: check_oozie_jobs.sh [-h help] -H <host> -U <url> -A <name-job>

  -h		Print this help message
  -H		Host where is oozie
  -U		URL oozie endpoint
  -A		Name of job (App Name)
  
  Exit status:
  0  if OK
  1  if minor problems (e.g., cannot create a temp file)
  2  if serious trouble (e.g., cannot access command-line argument)
  3  unknown
  "
}

# Arguments
while getopts ":H:U:A:h" opt; do
	case $opt in
		h) _usage; exit $STATE_OK;;
		H) HOST=$OPTARG;;
		U) URL=$OPTARG;;
		A) NAME=$OPTARG;;
		\?) echo "Invalid option: -$OPTARG" >&2; _usage; exit $STATE_CRITICAL;;
		:) echo "Requiere an argument: -$OPTARG" >&2; _usage; exit $STATE_CRITICAL;;
	esac
done

# Check arguments
if [[ -z "$HOST" || -z "$URL" || -z "$NAME" ]]; then
        echo "Empty obligatory arguments"
        _usage
        exit $STATE_WARNING;
fi

# Vars
SSH="ssh $HOST"
RESULT=$($SSH "oozie jobs -oozie $URL -localtime -verbose -len 1 -filter name=$NAME" | awk '{ print $14 }' | sed '1d;$d;/^\s*$/d')

# Main #####################################################

if [[ -z "$RESULT" ]]; then
	echo "Don't found name's job"
	exit $STATE_CRITICAL
fi

if [[ "$RESULT" == "SUCCEEDED" || "$RESULT" == "RUNNING" ]]; then
	echo "OOZIE'S JOB $NAME OK - $RESULT"
	exit $STATE_OK
else
	echo "OOZIE'S JOB $NAME FAILED - $RESULT"
	exit $STATE_CRITICAL
fi
