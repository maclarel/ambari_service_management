#!/bin/bash

# Exit on error
set -e

# Set defaults
AMBARI_HOST=
AMBARI_CLUSTER=
SERVICE_NAME=
USER=
PASS=
PROTOCOL=

# Grab variables from arguments to override default settings above
for i in "$@"; do
	case $i in
	    -h=*|--ambariHost=*)
	    AMBARI_HOST="${i#*=}"
	    shift # past argument=value
	    ;;
	    -c=*|--ambariCluster=*)
	    AMBARI_CLUSTER="${i#*=}"
	    shift # past argument=value
	    ;;
	    -s=*|--serviceName=*)
		SERVICE_NAME="${i#*=}"
		shift
		;;
		-u=*|--user=*)
		USER="${i#*=}"
		shift
		;;
		-p=*|--pass=*)
		PASS="${i#*=}"
		shift
		;;
		-t=*|--protocol=*)
		PROTOCOL="${i#*=}"
		shift
		;;
	    *)
	          # unknown option
	    ;;
	esac
done

# Prompt for values if not provided
if [ -z "$PROTOCOL" ]; then
	read -p "Protocol (HTTP or HTTPS): " PROTOCOL
fi

if [ -z "$AMBARI_HOST" ]; then
	read -p "Ambari Hostname: " AMBARI_HOST
fi

if [ -z "$AMBARI_CLUSTER" ]; then
	read -p "Ambari Cluster Name: " AMBARI_CLUSTER
fi

if [ -z "$SERVICE_NAME" ]; then
	read -p "Service Name (ALL CAPS!): " SERVICE_NAME
fi

if [ -z "$USER" ]; then
	read -p "Username: " USER
fi

if [ -z "$PASS" ]; then
	read -p "Password: " PASS
fi

# Get current status of the service (e.g. STARTED|STOPPED|INSTALLED)
function get_current_state() {
        CURRENT_STATE=`curl -k -s -u $USER:$PASS -H "X-Requested-By: ambari" -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$AMBARI_CLUSTER/services/$SERVICE_NAME?fields=ServiceInfo/state | grep \"state\" | awk '{print $3}' | sed 's/"//g'`
}

function stop_service() {
	curl -k -s -u $USER:$PASS -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Stop '$SERVICE_NAME' (scripted)"}, "Body": {"ServiceInfo": {"state": "INSTALLED"}}}' http://$AMBARI_HOST:8080/api/v1/clusters/$AMBARI_CLUSTER/services/$SERVICE_NAME
}

function start_service() {
	curl -k -s -u $USER:$PASS -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Start '$SERVICE_NAME' (scripted)"}, "Body": {"ServiceInfo": {"state": "STARTED"}}}' http://$AMBARI_HOST:8080/api/v1/clusters/$AMBARI_CLUSTER/services/$SERVICE_NAME
}

function monitor_status() {
	sleep 10
	get_current_state
	reset_counter
	while [[ "$CURRENT_STATE" != "$1" ]] && [ $i -lt 60 ]; do
	    	get_current_state
	    	echo "Waiting for request to complete..."
	    	sleep 10
	    	i=$[$i+1]
	done
	
	if [[ "$CURRENT_STATE" != "$1" ]]; then
		    echo "Request timed out!"
		    exit 1
	fi
}

function reset_counter() {
	i=0
}

# Stop Service
echo "Stopping $SERVICE_NAME..."
stop_service

# Get state of the service and do not progress until Service is stopped. Time out after 10 min of waiting.
monitor_status "INSTALLED"

# Start Service
echo "Starting $SERVICE_NAME..."
start_service

# Confirm that Service was started
monitor_status "STARTED"
echo $SERVICE_NAME "restarted successfully!"

exit 0