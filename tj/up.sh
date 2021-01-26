#!/bin/sh

while true; do
	sh sync.sh && sh collect.sh && sh purge.sh
	sleep 60s
done
