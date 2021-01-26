#!/bin/sh

RESULTLIST=`find job -type f |awk -F/ '$NF == "SUCCESS" || $NF == "FAILED" || $NF == "ABORTED"'`

for r in $RESULTLIST; do
	dirpath=`dirname $r`
	rm -rf $dirpath
done

# rm -rf `find job/ -empty |xargs`
# find job/ -mindepth 3 -maxdepth 3 -type d -empty |xargs rm -rf
find job -mindepth 1 -type d -empty |xargs rm -rf
