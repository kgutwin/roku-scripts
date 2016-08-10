#!/bin/bash

cd /video

for i in *.png; do
    vidf=${i:0:19}
    if [ ! -f $vidf.mp[4g] ]; then
	rm -f $vidf.mp*png
    fi
done
