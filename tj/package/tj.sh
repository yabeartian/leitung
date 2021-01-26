#!/bin/bash

techo() {
	message="$1"
	echo `date +%Y-%m-%d.%H:%M:%S` $message
}

getlocalip() {
	#/sbin/ifconfig |perl -ne'if(/inet addr:(\d+\.\d+\.\d+\.\d+)/) {print $1; exit}' 
	/sbin/ifconfig |fgrep eth0 -A 1 |perl -ne'if(/inet.*?(\d+\.\d+\.\d+\.\d+)/) {print $1; exit}' 
}

export LC_ALL=C

jobinputpath=$1
[ ! -e "$jobinputpath" ] && exit 1
basedir=$PWD

source $basedir/tj-config.sh
[ -z "$MAXI" ] && MAXI=100
[ -z "$DASHBOARDSERVER" ] && exit 1;

INFO=$basedir/INFO

rm -rf $INFO
localip=`getlocalip`
echo IP: $localip >> $INFO
echo LOCALUSER: $USER >> $INFO
echo JOBEXECPATH: $basedir >> $INFO
echo SSH_CONNECTION: $SSH_CONNECTION >> $INFO

jobsubdir=`echo $basedir | perl -ne'/\/job\/\d{6}\/\d{8}\/\d{6}\/.*/ and print $&'`
echo PORTAL: ${DASHBOARDSERVER}${jobsubdir} >> $INFO

if [ -d "$jobinputpath" ]; then
	jobpath=$jobinputpath
	INPUTXX=$jobpath/XX.txt
else
	jobpath=`dirname $jobinputpath`
	INPUTXX=$jobinputpath
fi
echo XX: $INPUTXX >> $INFO

cd $jobpath
if [ $? != "0" ]; then
	echo "cd $jobpath FAILED"
	touch $basedir/ABORTED
	sh warning.sh $DEFAULT_SMSTO "$localip: cd $jobpath FAILED"
	exit 1
fi
echo JOBPATH: $jobpath >> $INFO

if [ ! -s "$jobpath/mailto.txt" ]; then
	echo "$jobpath/mailto.txt is not a file which size is greater than zero" > $basedir/EMPTYMAILTO
	jobmailto=$DEFAULT_MAILTO
else
	jobmailto=`cat $jobpath/mailto.txt`
fi
echo MAILTO: $jobmailto >> $INFO

XX=$basedir/XX
> $XX
if [ -e "$INPUTXX" ]; then
	#cp -f $INPUTXX $XX
	cut -f1 -d"#" $INPUTXX |awk 'length($1) > 0 {print $1}' > $XX
else
	i=1
	while [ $i -lt "$MAXI" ]; do
		x=$jobpath/x$i.sh
		if [ -e $x ]; then
			echo x$i.sh >> $XX
		fi
		let i=$i+1
	done
fi

ARGS=("$@")
unset ARGS[0]
echo ARGS: ${ARGS[@]} >> $INFO

tjrootdir=${basedir%/*/*/*/*/*}
mkdir -p $tjrootdir/tmp
tmphadoopconf=`mktemp -d --tmpdir=$tjrootdir/tmp hadoop_conf.XXXXXX`
if [ -d /etc/hadoop/conf ]; then
	if [ $? -ne 0 ]; then
		sh warning.sh $DEFAULT_SMSTO "$localip: mkdir -p $tmphadoopconf FAILED"
		exit 1
	fi
	cp -r -f /etc/hadoop/conf/* $tmphadoopconf/
	rm -rf $tmphadoopconf/mapred-site.xml

	addontmp=`mktemp --tmpdir=$tjrootdir/tmp addon.XXXXXX`
	> $addontmp
	echo "<property>" >> $addontmp
	echo "<name>com.github.yabeartian.leitung.trackjob.portal</name>" >> $addontmp
	echo "<value>${DASHBOARDSERVER}${jobsubdir}</value>" >> $addontmp
	echo "</property>" >> $addontmp
	awk 'ARGIND == 1 { s = s $0 "\n"} ARGIND > 1 && $1 ~ /<\/configuration>/ {print s} ARGIND > 1 {print $0}' $addontmp /etc/hadoop/conf/mapred-site.xml > $tmphadoopconf/mapred-site.xml.template
	rm -rf $addontmp
	usetmphadoopconf=Y
else
	usetmphadoopconf=N
fi

techo "$jobpath STARTED"
OK=OK
> $basedir/stopenedfiles
while read xi; do
	x=$jobpath/$xi
	if [ -e $x ]; then
		techo "$x STARTED"
		basedirlog=$basedir/${xi%.*}.log
		jobpathlog=$jobpath/${xi%.*}.log
		if [ "$usetmphadoopconf" == "Y" ]; then
			rm -rf $tmphadoopconf/mapred-site.xml
			addontmp=`mktemp --tmpdir=$tjrootdir/tmp addon.XXXXXX`
			echo "<property>" >> $addontmp
			echo "<name>com.github.yabeartian.leitung.trackjob.submitexecutable</name>" >> $addontmp
			echo "<value>$USER@$localip:$x</value>" >> $addontmp
			echo "</property>" >> $addontmp
			awk 'ARGIND == 1 { s = s $0 "\n"} ARGIND > 1 && $1 ~ /<\/configuration>/ {print s} ARGIND > 1 {print $0}' $addontmp $tmphadoopconf/mapred-site.xml.template > $tmphadoopconf/mapred-site.xml
			rm -rf $addontmp
			export HADOOP_CONF_DIR=$tmphadoopconf
		fi
		for w in `grep /hadoop $x |grep -w hadoop |awk '{gsub(/[,=\x27\x22\x60]/, " ", $0);print $0}' | awk '{for(i=1;i<=NF;++i){print $i}}' |grep -v "*"`; do
			if [ -x "$w" ]; then
				if [ "$usetmphadoopconf" == "Y" ]; then
					unset HADOOP_CONF_DIR
				fi
				break
			fi
		done
		if fgrep -q $x -e DO_NOT_USE_STRACE; then
			cd $jobpath && sh -xv $x "${ARGS[@]}" 2>&1 | tee $basedirlog > $jobpathlog
			ret=${PIPESTATUS[0]}
			cd $basedir
		else
			stracetmp=`mktemp --tmpdir=$tjrootdir/tmp strace.XXXXXX`
			cd $jobpath && strace -e trace=open,chdir,clone -f -o $stracetmp sh -xv $x "${ARGS[@]}" 2>&1 | tee $basedirlog > $jobpathlog
			ret=${PIPESTATUS[0]}
			perl $basedir/tj-stopenedfiles.pl < $stracetmp |fgrep $jobpath |awk '{print $1}' | sort -u >> $basedir/stopenedfiles
			rm -rf $stracetmp
			cd $basedir
			ln=`awk 'END {print NR}' $basedirlog`
			if [ $ln -eq 1 ]; then
				lx=`cat $basedirlog`
				if [ "$lx" == 'strace: ptrace(PTRACE_TRACEME, ...): Operation not permitted' ]; then
					sh warning.sh "$DEFAULT_SMSTO" "TRACKJOB strace not permitted: $USER@$localip:$x"
					cd $jobpath && sh -xv $x "${ARGS[@]}" 2>&1 | tee $basedirlog > $jobpathlog
					ret=${PIPESTATUS[0]}
					cd $basedir
				fi
			fi
		fi
		if [ $ret != "0" ]; then
			techo "$x FAILED"
			XFAILED=$(basename $x)
			OK=""
			break
		else
			techo "$x SUCCESS"
		fi
	else
		techo "$x NOTFOUND"
		OK=""
		break
	fi
done < $XX

if [ -d /etc/hadoop/conf ]; then
	export HADOOP_CONF_DIR=/etc/hadoop/conf
fi
rm -rf $tmphadoopconf

d=$jobpath/clean.sh
if [ -s "$d" ]; then
	techo "$d STARTED"
	basedirlog=$basedir/clean.log
	jobpathlog=$jobpath/clean.log
	cd $jobpath && sh -xv $d 2>&1 | tee $basedirlog > $jobpathlog
	ret=${PIPESTATUS[0]}
	cd $basedir
	if [ "$ret" != "0" ]; then
		techo "$d FAILED"
	else
		techo "$d SUCCESS"
	fi
fi

> $basedir/BAKSRC
while read w; do
	[ -f "$w" -a "$w" -ot $basedir/tj.sh ] && echo $w >>$basedir/BAKSRC
done < $basedir/stopenedfiles
b=$basedir/tj-src.sh
techo "$b STARTED"
cd $jobpath && sh -xv $b $basedir/JOBSRC $INPUTXX >>$basedir/BAKSRC 2>$basedir/src.log
ret=$?
cd $basedir
if [ "$ret" != "0" ]; then
	techo "$b FAILED"
else
	techo "$b SUCCESS" 
fi
baksrctmp=`mktemp --tmpdir=$tjrootdir/tmp baksrc.XXXXXX`
awk '++c[$1] == 1' $basedir/BAKSRC > $baksrctmp
/bin/mv -f $baksrctmp $basedir/BAKSRC
chmod 644 $basedir/BAKSRC

b=$basedir/tj-backup.sh
techo "$b STARTED"
cd $jobpath && sh -xv $b $basedir $basedir/BAKSRC $INPUTXX > $basedir/backup.log 2>&1
ret=$?
cd $basedir
if [ "$ret" != "0" ]; then
	techo "$b FAILED"
else
	techo "$b SUCCESS"
fi

if [ "$OK" == "OK" ]; then
	RESULT=SUCCESS
else
	RESULT=FAILED
fi

techo "$jobpath $RESULT"

echo RESULT: $RESULT >> $INFO
if [ ! -z "$jobmailto" ]; then
	mailto=`echo $jobmailto|perl -ne'chomp;print join(";",split/\s+/)'`
	mailfrom=`echo $jobmailto|awk '{print $1}'`
	mailtitle="TRACKJOB $USER@$localip:$jobpath $RESULT"
	mailbody=`fgrep -e PORTAL: $INFO`
	sh mail.sh "$mailfrom" "$mailto" "$mailtitle" "$mailbody" 
	if [ "$OK" != "OK" ]; then
		smsto=`echo $jobmailto|perl -ne'chomp;print join(",",split/\s+/)'`
		[ ! -z "$XFAILED" ] && mailtitle="$mailtitle $XFAILED"
		sh warning.sh "$smsto" "$mailtitle"
	fi
	[ ! -s $basedir/MAILOUT ] && rm -rf $basedir/MAILOUT
	[ ! -s $basedir/MAILERR ] && rm -rf $basedir/MAILERR
fi

touch $RESULT
if [ "$OK" != "OK" ]; then
	exit 1
fi

exit 0
