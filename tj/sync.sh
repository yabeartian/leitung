#!/bin/sh

source $PWD/config.sh
rsync -rltD job $DASHBOARD_RSYNCTO

