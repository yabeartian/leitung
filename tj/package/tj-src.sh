#!/bin/sh

SELF="$0"
JOBSRC="$1"
XX="$2"

if [ -z "$XX" ]; then
	XX=XX.txt
fi

p="$PWD"

tf=`mktemp tf.XXXXXX`
chmod 644 $tf
if [ -s "$XX" ]; then
    awk -v p=$p '{print p "/" $1}' $XX >> $tf
    xx=`cat $XX`
else
    i=1;
    xi=x$i.sh
    while [ $i -lt 100 -a -s $xi ]; do
        echo $p/$xi >> $tf
        xx="$xx $xi"
        let i=$i+1
        xi=x$i.sh
    done
fi
for x in $xx; do
    for y in `awk '{gsub(/[,=\x27\x22\x60]/, " "); print $0}' $x |awk '{for(i=1;i<=NF;++i){if(index($i,"*") <= 0)print $i}}'`; do
        f=$p/${y#./}
        if [ -s "$f" -a -f "$f" -a $SELF -nt $f ]; then
            echo $f >> $tf
        fi
    done
done

jsrc=`mktemp jsrc.XXXXXX`
chmod 644 $jsrc
t=`date +%s`
sort -u $tf \
| while read f; do
    digest=`md5sum $f`
    fst=`stat -c "%s"$'\t'"%Z" $f`
    echo -e "$f\t$fst\t${digest% *}" >> $jsrc
done 
rm -rf $tf

if [ ! -z "$JOBSRC" ]; then
    if [ -s "$JOBSRC" ]; then
        awk 'ARGIND == 1 {c[$1] = $NF} ARGIND > 1 && (c[$1] != $NF || $2 < 512000) {print $1}' $JOBSRC $jsrc
        tf=`mktemp tf.XXXXXX`
        awk '++c[$1] == 1' $jsrc $JOBSRC |sort -k3,3nr > $tf
        rm -rf $jsrc
        mv -f $tf $JOBSRC
    else
        awk '{print $1}' $jsrc
        mv -f $jsrc $JOBSRC
    fi
fi
