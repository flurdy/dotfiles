#!/bin/bash

if [ -z "$1" ]; then
	Usage "$0 [javaprocesskeyword]"
	exit 1
fi
process=$1
echo "Finding and Killing all PIDS with [$1] in it"

for pid in `ps aux  | grep java | grep -v "$0" | awk '{print $2}'`; do
	folder=`lsof -a -p $pid -d cwd | awk '{print $9}' | tail -n 1 | grep $process`
	if [ -n "$folder" ]; then
		echo "Closing $pid ..."
		kill -15 $pid
		sleep 4
	fi		
done
for pid in `ps aux  | grep java | grep -v "$0" | awk '{print $2}'`; do
	folder=`lsof -a -p $pid -d cwd | awk '{print $9}' | tail -n 1 | grep $process`
	if [ -n "$folder" ]; then
		echo "Process $pid still not dead, nuking it..."
		kill -9 $pid
		sleep 1
	fi		
done

exit 0

