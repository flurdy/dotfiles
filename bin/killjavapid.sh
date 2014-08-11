#!/bin/bash

findjavacmd(){
	echo "ps aux  | grep java | grep $process | grep -v $0"
	javacmd=`ps aux  | grep java | grep $process | grep -v "$0"`
	echo "process: $javacmd"
}
findjavapid(){
	findjavacmd
	javapid=`echo $javacmd | awk '{print $2}'`
	echo "pid: $javapid"
}
if [ -z "$1" ]; then
	Usage "$0 [javaprocesskeyword]"
	exit 1
fi
process=$1
echo "Finding and Killing all PIDS with [$1] in it"
findjavapid
if [ -z "$javapid" ]; then
	echo "No processes running with [$1]"
	exit 0
fi
echo "Closing $javapid ..."
echo "kill -15 $javapid"
sleep 5
findjavapid
if [ -n "$javapid" ]; then
	echo "Killing $javapid"
	echo "kill -9 $javapid"
	sleep 1
fi
findjavacmd
if [ -n "$javapid" ]; then
	echo "Still running: $javacmd"
fi

exit 0

