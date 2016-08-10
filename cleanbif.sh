#!/bin/bash

cd /var/www/html/mythtvroku/bif

for i in *.bif; do
    vidf=$(basename "$i" .bif)
    if [ ! -f /video/$vidf ]; then
	rm -f "$i"
    fi
done
