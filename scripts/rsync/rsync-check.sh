#!/usr/bin/env bash

#http://chriscase.cc/2013/12/automatically-check-rsync-and-restart-if-stopped/

echo "checking for active rsync process"
COUNT=`ps ax | grep rsync | grep -v grep | grep -v rsync_check.sh | wc -l` # see how many are running
echo "there are $COUNT rsync related processes running";
if [ $COUNT -eq 0 ] 
then
	echo "no rsync processes running, restarting process"
	killall rsync  # prevent RSYNCs from piling up, if by some unforeseen reason there are already processes running
	rsync --verbose --progress --stats --compress--recursive --times --perms --links -ave ssh $argv
fi
