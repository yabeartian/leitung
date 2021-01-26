#!/bin/sh

leitungtjdir=`dirname $0`
cd $leitungtjdir && sh runjob.sh "$@" &

