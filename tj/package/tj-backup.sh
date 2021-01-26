#!/bin/sh

SHSELF=$0
bakdir="$1"
baksrc="$2"
XX="$3"

[ ! -s "$XX" ] && XX=XX.txt

altbakdir=history/`date +%Y%m%d/%H%M%S`
if [ -z "$bakdir" ]; then
	bakdir=$altbakdir
fi
ff=`find . -maxdepth 1 -type f -newer $SHSELF -size -500M |awk 'length($1) > 1 {s = $1; gsub(/^\.\//, "", s); print s}' |fgrep -v .`
mkdir -p $bakdir

for f in $ff; do
	rsync -a $f $bakdir
done

if [ -d history -a "$altbakdir" != "$bakdir" ]; then
	mkdir -p $altbakdir
	for f in $ff; do
		rsync -a $f $altbakdir/
	done
	rsync -a $XX $altbakdir/
	for x in `cat $XX`; do
		rsync -a ${x%.*}.log $altbakdir/
	done
fi

if [ -s "$baksrc" ]; then
	awk -v p=$PWD '{if (index($1, p) == 1) {print substr($1, length(p) + 2);}}' $baksrc | while read f ; do
		rsync -aR $f $bakdir
	done
fi
