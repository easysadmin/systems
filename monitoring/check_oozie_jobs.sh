#!/bin/bash
#------------------------------------------------------------------------------
# [Syspixel] Check Oozie Jobs
# 	     Nagios check for Oozie Jobs
#
# 
#
# 
#------------------------------------------------------------------------------
VERSION=1.0

# Exit codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

# Print help
_usage() {
echo "Usage: check_oozie_jobs.sh [-h help] -H <host> -U <url> -A <name-job> [-l len-jobs]

  -h	Print this help message
  -H	Host where is oozie
  -U	URL oozie endpoint
  -A	Name of job (App Name)
  -l	Jobs amount to check. Default: 1.
  
  Exit status:
  0  if OK
  1  if minor problems (e.g., cannot create a temp file)
  2  if serious trouble (e.g., cannot access command-line argument)
  3  unknown"
}

# Arguments
while getopts ":H:U:A:l:h" opt; do
	case $opt in
		h) _usage; exit $STATE_OK;;
		H) HOST=$OPTARG;;
		U) URL=$OPTARG;;
		A) NAME=$OPTARG;;
		l) if [[ ! -z "$OPTARG" ]]; then
			LEN=$OPTARG
		   fi;;
		\?) echo "Invalid option: -$OPTARG" >&2; _usage; exit $STATE_CRITICAL;;
		:) echo "Requiere an argument: -$OPTARG" >&2; _usage; exit $STATE_CRITICAL;;
	esac
done

# Check empty arguments
if [[ -z "$HOST" || -z "$URL" || -z "$NAME" ]]; then
        echo "Empty obligatory arguments"
        _usage
        exit $STATE_WARNING
elif [ -z $LEN ]; then
	LEN=1
fi

# Comprobe if jobs come from various workflows
function _checkjobs {
	for i in `seq 1 $(expr $LEN "*" 3)`; do # 3 => amounts of stats to show (status, date created and time created)
		if ! (( $i % 3 )); then
			STAT1=$(echo $1 | cut -d" " -f$(expr $i - 2))
			POS1=$(expr $i - 2)
			POS2=$(expr $i - 1)
			if [[ "$STAT1" == "SUCCEEDED" || "$STAT1" == "RUNNING" ]]; then
				STATUS=$(echo $1 | cut -d" " -f$POS1,$POS2,$i)
			else
				STATUS=$(echo $1 | cut -d" " -f$POS1,$POS2,$i)
				echo "$STATUS"
				break
			fi
		fi
	done

	# If done without problems, correct response
	echo "$STATUS"
}

# Vars
SSH="ssh $HOST"
JOBS=$($SSH "oozie jobs -oozie $URL -localtime -verbose -len $LEN -filter name=$NAME" | awk '{ print $14, $15, $16 }' | sed '1d;$d;/^\s*$/d')
STATUS=$(_checkjobs "$JOBS")
RESULT=$(echo $STATUS | awk '{ print $1 }')
DESC=$(echo $STATUS | awk '{ print $1 " (Started: " $2, $3 ")" }')


# Main #####################################################
if [ -z $RESULT ]; then
	echo "Don't found name's job"
	exit $STATE_CRITICAL
fi

if [[ "$RESULT" == "SUCCEEDED" || "$RESULT" == "RUNNING" ]]; then
	echo "OOZIE'S JOB $NAME OK - $DESC"
	exit $STATE_OK
else
	echo "OOZIE'S JOB $NAME FAILED - $DESC"
	exit $STATE_CRITICAL
fi
