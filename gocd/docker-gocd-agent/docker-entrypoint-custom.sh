#!/bin/bash
function stop()
{
	echo "Stopping GoCD Agent..."
	kill $gocd_pid
	kill $tail_pid
	echo "Stopped."
	exit 0
}

function start() {
	echo "Starting GoCD Agent..."
	./docker-entrypoint.sh &	
	gocd_pid=$!

	sleep 1
	echo "Done waiting, starting to tail log"
	# Change this to a different log file if theres something else you want to log
	tail -f /go/go-agent-bootstrapper.out.log &
	tail_pid=$!

	echo "Started (GoCD: $gocd_pid, LogTail: $tail_pid)."
}

trap stop TERM INT SIGHUP
start

sleep 2
./know_git-server.sh

wait $gocd_pid