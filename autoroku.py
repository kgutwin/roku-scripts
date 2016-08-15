#!/usr/bin/env python

from MythTV import MythDB

mythdb = MythDB()

for record in mythdb.searchRecord():
    if record['autouserjob1'] == 0:
        record.update(autouserjob1=1)

