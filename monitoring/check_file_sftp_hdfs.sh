#!/bin/bash
#------------------------------------------------------------------------------
# [Syspixel] Check File SFTP HDFS
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
echo "Usage: check_file_sftp_hdfs.sh [-h help] -H <host> -f <file>

  -h		Print this help message
  -H		Host where's log
  -f		Path log's file to read result
  
  Exit status:
  0  if OK
  1  if minor problems (e.g., cannot create a temp file)
  2  if serious trouble (e.g., cannot access command-line argument)
  3  unknown
  "
}

# Arguments
while getopts ":H:f:h" opt; do
	case $opt in
		h) _usage; exit $STATE_OK;;
		H) HOST=$OPTARG;;
		f) FILE=$OPTARG;;
		\?) echo "Invalid option: -$OPTARG" >&2; _usage; exit $STATE_CRITICAL;;
		:) echo "Requiere an argument: -$OPTARG" >&2; _usage; exit $STATE_CRITICAL;;
	esac
done

# Check arguments
if [[ -z "$HOST" || -z "$FILE" ]]; then
        echo "Empty obligatory arguments"
        _usage
        exit $STATE_WARNING;
fi

# Vars
SSH="ssh $HOST"
LINE=$($SSH tail -1 "$FILE")
RESULT=$(echo -e "$LINE" | awk '{ print $2 }' | sed 's/://')
MESSAGE=$(echo -e "$LINE" | awk '{ print substr($0, index($0,$3)) }')

# Main #####################################################

if [[ -z "$RESULT" ]]; then
	echo "UPLOAD WEBORAMA DATA UNKNOWN - $MESSAGE"
	exit $STATE_UNKNOWN
fi

if [[ "$RESULT" == "INFO" ]]; then
	echo "UPLOAD WEBORAMA DATA OK - $MESSAGE"
	exit $STATE_OK
else
	echo "UPLOAD WEBORAMA DATA FAILED - $MESSAGE"
	exit $STATE_CRITICAL
fi
