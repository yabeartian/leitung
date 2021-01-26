#!/bin/sh

tf=`mktemp tf.XXXXXX`
for f in `find job/ -name "JOBSRC" | sort -r`; do
	cat $f >> $tf
done
if [ -s var/JOBSRC ]; then
	jtf=`mktemp jtf.XXXXXX`
	awk '++c[$1] == 1' $tf var/JOBSRC > $jtf
	mv -f $jtf var/JOBSRC
	chmod 644 var/JOBSRC
else
	awk '++c[$1] == 1' $tf > var/JOBSRC
fi
rm -rf $tf
