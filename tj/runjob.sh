#!/bin/sh

leitungtjdir=`dirname $0`
cd $leitungtjdir

jobinputpath=$1

source $PWD/config.sh

getlocalip() {
        #/sbin/ifconfig |perl -ne'if(/inet addr:(\d+\.\d+\.\d+\.\d+)/) {print $1; exit}' 
        /sbin/ifconfig |fgrep eth0 -A 1 |perl -ne'if(/inet.*?(\d+\.\d+\.\d+\.\d+)/) {print $1; exit}'
}

if [ ! -e "$jobinputpath" ]; then
	localip=`getlocalip`
	#wget -t 2 -T 2 -q "${SMSREQ}TRACKJOB newjob.sh $localip:$jobinputpath is not a directory" -O /dev/null
	wget -t 2 -T 2 -q "${SMSREQ}TRACKJOB newjob.sh $localip:$jobinputpath does not exist" -O /dev/null
	exit 1
fi

if [ -d "$jobinputpath" ]; then
	jobpath=$jobinputpath
else
	jobpath=`dirname $jobinputpath`
fi

#find $jobpath -maxdepth 1 -type f -name "x*.sh" |perl -ne'chomp;/\/x\d+\.sh$/ and print $_, "\n"'

suffix=`date +%Y%m%d/%H%M%S`
ym=${suffix:0:6}
suffix=$ym/$suffix

jobname=`basename $jobpath`
jobexecpath=job/$suffix/$jobname

if mkdir -p $jobexecpath; then
	cp package/* $jobexecpath
	mkdir -p var
	[ -s var/JOBSRC ] && fgrep $jobpath var/JOBSRC > $jobexecpath/JOBSRC
	cd $jobexecpath && nohup bash tj.sh "$@" 2>&1 |tee PROGRESS >tj.log 2>&1 
else
	localip=`getlocalip`
	wget -t 2 -T 2 -q "${SMSREQ}TRACKJOB newjob.sh $localip:$jobexecpath cannot be made" -O /dev/null
	exit 1
fi

