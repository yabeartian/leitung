#!/bin/sh

uppid=`pgrep -f $PWD/up.sh`

if [ -z "$uppid" ]; then
	sh start.sh
fi
