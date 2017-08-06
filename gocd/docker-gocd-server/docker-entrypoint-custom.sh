#!/bin/bash
function stop()
{
	echo "Stopping GoCD Server..."
	kill $gocd_pid
	kill $tail_pid
	echo "Stopped."
	exit 0
}

function start() {
	echo "Starting GoCD Server..."
	./docker-entrypoint.sh &	
	gocd_pid=$!

	echo "Started (GoCD: $gocd_pid)."
}

trap stop TERM INT SIGHUP
start

sleep 2
./know_git-server.sh

wait $gocd_pid