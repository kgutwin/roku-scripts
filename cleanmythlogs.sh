#!/bin/bash

cd /var/log/mythtv

TARF=mythlogs-$(date +%Y%m%d%H%M%S).tar
find . -type f -ctime +60 -print0 | xargs -0 tar --remove-files -rf $TARF
gzip $TARF
