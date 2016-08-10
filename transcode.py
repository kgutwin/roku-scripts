#!/usr/bin/env python

from MythTV import Job, Recorded, System, MythDB, mythproto, MythError, MythLog

from optparse import OptionParser
import sys
import os

################################
#### adjust these as needed ####
transcoder = '/video/roku/transcode.sh'
flush_commskip = True
build_seektable = True
################################

def runjob(jobid=None, chanid=None, starttime=None):
    db = MythDB()
    if jobid:
        job = Job(jobid, db=db)
        chanid = job.chanid
        starttime = job.starttime
    rec = Recorded((chanid, starttime), db=db)

    sg = mythproto.findfile(rec.basename, rec.storagegroup, db=db)
    if sg is None:
        print 'Local access to recording not found.'
        sys.exit(1)

    infile = os.path.join(sg.dirname, rec.basename)
    #### list of segments to be cut
    # rec.markup.gencutlist()
    #### list of segments to keep
    # rec.markup.genuncutlist()

    task = System(path=transcoder, db=db)
    try:
        outfile = task(infile).strip()
        if not os.path.exists(outfile):
            raise OSError('output file %s not found' % repr(outfile))
    except MythError, e:
        print 'Transcode failed with output:\n%s' % e.stderr
        sys.exit(e.returncode)
    except OSError, e:
        print 'Transcode failed to produce an output file:\n%s' % repr(e)
        sys.exit(1)

    rec.basename = os.path.basename(outfile)
    os.remove(infile)
    rec.filesize = os.path.getsize(outfile)
    rec.transcoded = 1
    rec.seek.clean()

    if flush_commskip:
        for index,mark in reversed(list(enumerate(rec.markup))):
            if mark.type in (rec.markup.MARK_COMM_START, rec.markup.MARK_COMM_END):
                del rec.markup[index]
        rec.bookmark = 0
        rec.cutlist = 0
        rec.markup.commit()

    if build_seektable:
        task = System(path='mythcommflag')
        task.command('--chanid %s' % chanid,
                     '--starttime %s' % starttime,
                     '--rebuild')

    rec.update()

    if jobid:
        job.update({'status':272, 'comment':'Transcode Completed'})

def main():
    parser = OptionParser(usage="usage: %prog [options] [jobid]")

    parser.add_option('--chanid', action='store', type='int', dest='chanid',
            help='Use chanid for manual operation')
    parser.add_option('--starttime', action='store', type='int', dest='starttime',
            help='Use starttime for manual operation')
    MythLog.loadOptParse(parser)
    MythLog._optparseinput()

    opts, args = parser.parse_args()

    if len(args) == 1:
        runjob(jobid=args[0])
    elif opts.chanid and opts.starttime:
        runjob(chanid=opts.chanid, starttime=opts.starttime)
    else:
        print 'Script must be provided jobid, or chanid and starttime.'
        sys.exit(1)

if __name__ == '__main__':
    main()
