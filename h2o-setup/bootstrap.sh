#!/usr/bin/env bash
set -eu

RELEASE="3.10.4.1"

# USER/GROUP
USER="h2o"
GROUP="h2o"

# H2O CONFIG
H2O_BASE_PATH="/opt/h2o"
H2O_CONFIG_PATH="/etc/h2o"
H2O_FLOW_DIR="/var/lib/h2o/flows"
H2O_LOG_DIR="/var/log/h2o"
H2O_CLUSTER_NAME="MyCloud"
H2O_LEVEL_LOG="INFO" # TRACE, DEBUG, INFO, WARN, ERRR, FATAL
H2O_PORT=54321

# JAVA CONFIG
JAVA_MEMORY="1g" # Max memory

# Verify running as root user
if [ "$(id -u)" != "0" ]; then
    if [ $# -ne 0 ]; then
        echo "Failed running with sudo. Exiting." 1>&2
        exit 1
    fi
fi

# Ask vars
REGEXNUMBER='^[0-9]+$'
REGEXLETTER='^[a-zA-Z]+$'
read -p "Java max memory? (Gb) [default: 1]: " JAVA_MEM
read -p "Cluster's name? [default: MyCloud]: " CLUSTER_NAME
read -p "Listen port? [default: 54321]: " PORT

if [[ ! -z "$JAVA_MEM" && "$JAVA_MEM" =~ $REGEXNUMBER ]]; then
	JAVA_MEMORY=${JAVA_MEM}g
fi

#TODO Accepts number
if [[ ! -z "$CLUSTER_NAME" && "$CLUSTER_NAME" =~ $REGEXLETTER ]]; then
	H2O_CLUSTER_NAME=$CLUSTER_NAME
fi

# Check if port is busy
PORT_EXIST=$(ss -laputen | grep LISTEN | grep :$PORT >/dev/null; echo $?)
if [[ ! -z "$PORT" && "$PORT" =~ $REGEXNUMBER && $PORT_EXIST != 0 ]]; then
	H2O_PORT=$PORT
else
	echo "The listen port is: $H2O_PORT"
fi

# Install JAVA
if [ ! $(which java) ]; then
	apt-get update && apt-get install -y oracle-java7-installer 
fi

# Create user/group
if [ ! $(cat /etc/group | grep "^$GROUP\:") ]; then
	addgroup $GROUP
fi
if [ ! $(cat /etc/passwd | grep "^$USER\:") ]; then
	adduser --system --no-create-home --ingroup $GROUP --disabled-login --gecos "" $USER
fi

# Check if exist release
STATUS_CODE=$(curl -sI http://h2o-release.s3.amazonaws.com/h2o/rel-ueno/1/h2o-${RELEASE}.zip | head -1 | awk '{ print $2 }')
if [ "$STATUS_CODE" == "200" ]; then
	mkdir -p $H2O_BASE_PATH
	mkdir -p $H2O_FLOW_DIR
	mkdir -p $H2O_LOG_DIR
	mkdir -p $H2O_CONFIG_PATH
	chown ${USER}:${GROUP} $H2O_BASE_PATH $H2O_FLOW_DIR $H2O_LOG_DIR $H2O_CONFIG_PATH

	cd /tmp
	wget http://h2o-release.s3.amazonaws.com/h2o/rel-ueno/1/h2o-${RELEASE}.zip
	unzip h2o-${RELEASE}.zip
	cd h2o-${RELEASE}
	mv * $H2O_BASE_PATH
	rm -rf /tmp/h2o-${RELEASE}*
	cd $H2O_BASE_PATH
else
	echo "Failed download. Exiting." 1>&2
	exit 1
fi

# File config
cat <<EOF > ${H2O_CONFIG_PATH}/params.conf
JAVA_MEMORY=${JAVA_MEMORY}
H2O_BASE_PATH=${H2O_BASE_PATH}
H2O_FLOW_DIR=${H2O_FLOW_DIR}
H2O_LOG_DIR=${H2O_LOG_DIR}
# TRACE,DEBUG,INFO,WARN,ERRR,FATAL
H2O_LEVEL_LOG=${H2O_LEVEL_LOG}

# Name of cluster
H2O_CLUSTER_NAME=${H2O_CLUSTER_NAME}

# Listen port (default)
H2O_PORT=${H2O_PORT}
EOF

# system.d
cat <<EOF > /lib/systemd/system/h2o.service
[Unit]
Description=H2O service
Wants=basic.target
After=basic.target network.target

[Service]
Type=simple
User=${USER}
EnvironmentFile=-${H2O_CONFIG_PATH}/params.conf
ExecStart=/usr/bin/java -Xmx\${JAVA_MEMORY} -jar \${H2O_BASE_PATH}/h2o.jar -flow_dir \${H2O_FLOW_DIR} -log_dir \${H2O_LOG_DIR} -log_level \${H2O_LEVEL_LOG} -name \${H2O_CLUSTER_NAME} -port \${H2O_PORT}

[Install]
WantedBy=multi-user.target
EOF

# Reload systemctl
systemctl daemon-reload
systemctl start h2o.service
systemctl enable h2o.service
