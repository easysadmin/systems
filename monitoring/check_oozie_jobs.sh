#!/bin/bash
#set -x
#------------------------------------------------------------------------------
# [Syspixel] Check Oozie Jobs
# 	     Nagios check for Oozie Jobs
#
# 
#
# 
#------------------------------------------------------------------------------
VERSION=2.1

# Exit codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

# Print help
usage() {
echo "Usage: check_oozie_jobs.sh [-h help] -H <host> -U <url> -A <name-job> 

  -h	Print this help message
  -H	Host where is oozie
  -U	URL oozie endpoint
  -A	Name of job (App Name)
  
  Exit status:
  0  if OK
  1  if minor problems (e.g., cannot create a temp file)
  2  if serious trouble (e.g., cannot access command-line argument)
  3  unknown"
}

# Arguments
while getopts ":H:U:A:l:h" opt; do
	case $opt in
		h) usage; exit $STATE_OK;;
		H) HOST=$OPTARG;;
		U) URL=$OPTARG;;
		A) NAME=$OPTARG;;
		\?) echo "Invalid option: -$OPTARG" >&2; usage; exit $STATE_CRITICAL;;
		:) echo "Requiere an argument: -$OPTARG" >&2; usage; exit $STATE_CRITICAL;;
	esac
done

# Check empty arguments
if [[ -z "$HOST" || -z "$URL" || -z "$NAME" ]]; then
        echo "Empty obligatory arguments"
        usage
        exit $STATE_WARNING
fi

# Number of days
datediff(){
        D1=$(date -d "$1" +%s)
        D2=$(date -d "$2" +%s)
        DIFF=$(( ($D1 - $D2) / 86400 ))
	echo $DIFF
}

# Vars
SSH="ssh $HOST"
NOW=$(date '+%s')
NUM_JOBS=1
NAME_URL=$(echo $NAME | sed -e 's/ /%20/g')
JOB=$($SSH curl -s "${URL}/v1/jobs?filter=name%3D${NAME_URL}&len=${NUM_JOBS}" | jq '.workflows[0] | { status, createdTime }')
JOB_CREATED=$(echo $JOB | jq -r '.createdTime')
JOB_STATUS=$(echo $JOB | jq -r '.status')
JOB_DAY=$(date -d"${JOB_CREATED}" '+%Y-%m-%d')
JOB_HOUR=$(date -d"${JOB_CREATED}" '+%H:%M')
JOB_SECONDS=$(date -d"${JOB_CREATED}" '+%s')

# Si el chequeo es antes de la hora de la creación del job se comprobará ayer
# si es después se comprobará hoy
if [[ $NOW -ge $JOB_SECONDS ]]; then
	# Hoy
	TODAY=$(date '+%Y-%m-%d')

	# Job
	# Con esto nos aseguramos que se ha ejecutado el de hoy. Chequeamos el día.
	DAYDIFF=$(datediff "$JOB_DAY" "$TODAY") # Devuelve el número de días de diferencia

	# Desde ayer a hoy
	if [[ $DAYDIFF -ge -1 && (${JOB_STATUS} == "SUCCEEDED" || ${JOB_STATUS} == "RUNNING") ]]; then
		RESULT="${JOB_STATUS}"
		DESC="$JOB_STATUS (Created: $JOB_DAY $JOB_HOUR)"
	else
		RESULT="FAILED"
	fi
fi

# Main #####################################################
if [[ -z "$RESULT" ]]; then
	echo "Don't found name's job"
	exit $STATE_CRITICAL
fi

if [[ "$RESULT" == "SUCCEEDED" || "$RESULT" == "RUNNING" ]]; then
	echo "JOB $NAME - $DESC"
	exit $STATE_OK
else
	echo "JOB $NAME - FAILED"
	exit $STATE_CRITICAL
fi
