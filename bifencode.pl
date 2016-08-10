#!/usr/bin/perl -w
 
use strict;

use File::Basename;
use File::Copy;
use File::Path;
 
if ($#ARGV != 1 ) {
        print "Scriptname Path File";
        exit;
}
 
my $directory=$ARGV[0];
my $file=$ARGV[1];

my $bifdir="/var/www/html/mythtvroku/bif";
my $SCRIPTDIR="/video/roku";
 
unless (-e $directory."/".$file) {
        print "File Doesn't Exist!\n";
        exit;
}
 
# create the directories that we'll put the sequential images
mkdir "/tmp/$file";
 
# for 4:3 SD Only
system ("ffmpeg -i $directory/$file -r .1 -s 240x180 /tmp/$file/%08d.jpg >> /dev/null 2>&1");
 
# Renumber images in directories to a zero-based index, required because
# ffmpeg number starting from #1 which would put timing out by 10 secs
opendir(DIR, "/tmp/$file");
my @bifs = grep(/\.jpg$/,readdir(DIR));
closedir(DIR);
 
# Number of created frames to drop
my $dropnum = 3;
for (my $image_num = 0; $image_num < ($#bifs + 1) - $dropnum; $image_num++) {
    my $oldnum = sprintf("%08d",($image_num+1) + $dropnum);
    my $newnum = sprintf("%08d",$image_num);
    move("/tmp/$file/$oldnum.jpg","/tmp/$file/$newnum.jpg");
}
chdir("/tmp");

# now use biftool to create the bif files
system("$SCRIPTDIR/biftool -t 10000 /tmp/$file");
 
# delete the directories and the files in them
rmtree(["/tmp/$file"]);

# install bif in proper location
move("/tmp/$file.bif", "$bifdir/$file.bif");
