#!/usr/bin/env python

from MythTV import Job, Recorded, System, MythDB, mythproto, MythError, MythLog
from MythTV.static import LOGMASK, LOGLEVEL

from optparse import OptionParser
import sys
import os

################################
#### adjust these as needed ####
TRANSCODER = '/video/roku/transcode.sh'
flush_commskip = True
build_seektable = True
################################

class TranscodeJob:
    def __init__(self):
        self.l = MythLog('transcode.py', db=self.db())

    def db(self):
        return MythDB()

    def log(self, message, level=LOGLEVEL.INFO, detail=None):
        return self.l.log(LOGMASK.GENERAL, level, message, detail)
    
    def logTB(self):
        return self.l.logTB(LOGMASK.GENERAL)

    def run(self, jobid=None, chanid=None, starttime=None):
        if jobid:
            job = Job(jobid, db=self.db())
            chanid = job.chanid
            starttime = job.starttime
        rec = Recorded((chanid, starttime), db=self.db())

        sg = mythproto.findfile(rec.basename, rec.storagegroup, db=self.db())
        if sg is None:
            self.log('Local access to recording not found.', LOGLEVEL.ERR)
            sys.exit(1)

        infile = os.path.join(sg.dirname, rec.basename)
        #### list of segments to be cut
        # rec.markup.gencutlist()
        #### list of segments to keep
        # rec.markup.genuncutlist()
        del(rec)

        task = System(path=TRANSCODER, db=self.db())
        try:
            outfile = task(infile).strip()
            if not os.path.exists(outfile):
                raise OSError('output file %s not found' % repr(outfile))
        except MythError, e:
            self.log('Transcode failed with output:', LOGLEVEL.ERR,
                     task.stderr)
            sys.exit(task.returncode)
        except OSError, e:
            self.log('Transcode failed to produce an output file:',
                     LOGLEVEL.ERR, repr(e))
            sys.exit(1)

        rec = Recorded((chanid, starttime), db=self.db())
        rec.basename = os.path.basename(outfile)
        os.remove(infile)
        rec.filesize = os.path.getsize(outfile)
        rec.transcoded = 1
        rec.seek.clean()

        if flush_commskip:
            for index,mark in reversed(list(enumerate(rec.markup))):
                if mark.type in (rec.markup.MARK_COMM_START, 
                                 rec.markup.MARK_COMM_END):
                    del rec.markup[index]
            rec.bookmark = 0
            rec.cutlist = 0
            rec.markup.commit()

        rec.update()

        if build_seektable:
            try:
                task = System(path='mythcommflag', db=self.db())
                task.command('--chanid %s' % chanid,
                             '--starttime %s' % starttime)
            except MythError, e:
                self.log('Mythcommflag --chanid %s --starttime %s failed: %s' %
                         (chanid, starttime, str(e)), LOGLEVEL.ERR)

        if jobid:
            job.update({'status':272, 'comment':'Transcode Completed'})

def main():
    parser = OptionParser(usage="usage: %prog [options] [jobid]")

    parser.add_option('--chanid', action='store', type='int', dest='chanid',
                      help='Use chanid for manual operation')
    parser.add_option('--starttime', action='store', type='int', 
                      dest='starttime',
                      help='Use starttime for manual operation')
    #MythLog.loadOptParse(parser)
    #MythLog._optparseinput()
    MythLog._setpath('/tmp')

    opts, args = parser.parse_args()

    j = TranscodeJob()
    try:
        if len(args) == 1:
            j.run(jobid=args[0])
        elif opts.chanid and opts.starttime:
            j.run(chanid=opts.chanid, starttime=opts.starttime)
        else:
            print 'Script must be provided jobid, or chanid and starttime.'
            sys.exit(1)
    except:
        j.logTB()
        sys.exit(1)

if __name__ == '__main__':
    main()
