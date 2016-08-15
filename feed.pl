#!/usr/bin/perl -w

use strict;

use Fcntl;
use MythTV;
use MP4::Info;
use HTML::Entities qw(encode_entities_numeric); 
 
# A link to the folder where your feed and recordings are
# located. Make sure you do NOT end the link with a "/"
# (i.e. http://www.example.com/recordings instead of
# http://www.example.com/recordings/)
my $BASEURL = "http://mythbackend.gutwin.org/mythtvroku";
 
# Update below if your MythTV recordings are saved to a different
# location
my $XMLDIR = "/var/www/html/mythtvroku";
 
# Update below to your MythTV recordings directory if different
my $VIDDIR = "/video";
my $BIFDIR = "/var/www/html/mythtvroku/bif";
 
####

# Connect to mythbackend
my $Myth = new MythTV();

sub get_show_info {
    my ($fn) = @_;
    my $r = {};

    # Get data from mp4 file
    $r->{vidfile} = "$VIDDIR/$fn";
    my $mp4info = get_mp4info($r->{vidfile});
    $r->{length} = $mp4info->{SECS};
    $r->{bitrate} = $mp4info->{BITRATE};

    # Connect to the database
    $fn =~ s/\.mp4$//;
    $r->{basename} = $fn;
    my $show = $Myth->new_recording($fn);
    if (defined $show) {
	$r->{title} = $show->format_name('%T', ' ', ' ', 1, 0, 1);
	$r->{episode} = $show->format_name('%S', ' ', ' ', 1, 0, 1);
	if ($r->{episode} eq "Untitled") { 
	    #$r->{episode} = $r->{title}; 
	    # apparently we have to format this name ourselves
	    my ($spsecond, $spminute, $sphour, $spday, $spmonth, $spyear, $spwday) = localtime($show->{'starttime'});
	    my @abwday = qw(Sun Mon Tue Wed Thu Fri Sat);
	    my @abmonth = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	    $spyear += 1900;
	    $r->{episode} = "$abwday[$spwday] $abmonth[$spmonth] $spday $spyear";
	}
	$r->{summary} = $show->format_name('%R', ' ', ' ', 1, 0, 1);
	$r->{chan} = $show->format_name('%cn %cc', ' ', ' ', 1, 0, 1);
	$r->{progtime} = $show->format_name('%m-%d-%Y %g:%i %A', ' ', ' ', 1, 0, 1);
	$r->{hdsd} = $show->{'hdtv'} ? "HD" : "SD";
	$r->{chanid} = $show->{'chanid'};
	$r->{starttime} = $show->{'starttime'};
	$r->{recgroup} = $show->{'recgroup'};

	# some format changes
	$r->{chan} =~ s/_/-/g;
	
	# and derived
	$r->{recent} = ((time - $show->{'recstartts'}) < 7*24*60*60) ? 1 : 0;
	$r->{unwatched} = ! $show->{'is_watched'};

    } else {
	# not found in mythtv database, fake some values
	($r->{episode}, $r->{title}) = split(/[ _]*-[ _]*/, $fn);
	$r->{title} = $r->{title} // "Unknown";
	$r->{summary} = $fn;

	# fix underscores
	$r->{episode} =~ s/_/ /g;
	$r->{title} =~ s/_/ /g;
	$r->{summary} =~ s/_/ /g;

	# set blanks
	$r->{chan} = $r->{progtime} = $r->{hdsd} = $r->{chanid} = "";
	$r->{starttime} = $r->{recgroup} = "";
	$r->{recent} = 0;
	$r->{unwatched} = 0;
    }

    
    return $r;
}

sub find_img($) {
    my ($id) = @_;

    my $img = "";
    if (-f "$VIDDIR/$id.mpg.png") {
	$img = "$id.mpg.png";
    } elsif (-f "$VIDDIR/$id.mp4.png") {
	$img = "$id.mp4.png";
    } else {
	# try a quick extraction
	system("ffmpeg -i '$VIDDIR/$id.mp4' -ss 00:00:25 -s 320x180" . 
	       " -vframes 1 '$VIDDIR/$id.mp4.png' >/dev/null 2>&1");
	$img = "$id.mp4.png" if (-f "$VIDDIR/$id.mp4.png");
    }

    return $img;
}

sub output_show($) {
    my ($show) = @_;

    # convenience extractions
    my $f = $show->{basename};
    my $episode = encode_entities_numeric($show->{episode});
    my $id = $show->{basename};
    $id =~ s/[^0-9]//g;
    my $hdsd = $show->{hdsd};
    my $bitrate = $show->{bitrate};
    my $progtime = encode_entities_numeric($show->{progtime});
    my $summary = encode_entities_numeric($show->{summary});
    my $chan = $show->{chan};
    my $length = $show->{length};
    my ($chanid, $starttime) = ($show->{chanid}, $show->{starttime});

    my $img = "$BASEURL/video/" . find_img($f);

    # Adds the item information for each .MP4 file to the a string
    # using the information pulled from the file name above
    my $item = "  <item sdImg=\"$img\" hdImg=\"$img\">\n";
    $item .= "    <title>$episode</title>\n";
    $item .= "    <contentId>$id</contentId>\n";
    $item .= "    <contentType>TV</contentType>\n";
    $item .= "    <contentQuality>$hdsd</contentQuality>\n";
    if (-e "$BIFDIR/$f.mp4.bif") {
	$item .= "      <hdBifUrl>$BASEURL/bif/$f.mp4.bif</hdBifUrl>\n";
    }
    $item .= "    <media>\n";
    $item .= "      <streamFormat>mp4</streamFormat>\n";
    $item .= "      <streamQuality>$hdsd</streamQuality>\n";
    $item .= "      <streamBitrate>$bitrate</streamBitrate>\n";
    $item .= "      <streamUrl>$BASEURL/video/$f.mp4</streamUrl>\n";
    $item .= "    </media>\n";
    $item .= "    <synopsis>$progtime - $summary</synopsis>\n";
    $item .= "    <genres>$chan</genres>\n";
    $item .= "    <runtime>$length</runtime>\n";
    $item .= "    <chanid>$chanid</chanid><starttime>$starttime</starttime>\n";
    $item .= "  </item>\n\n";
    
    return $item;
}



 
# Deletes the current feed if it already exists. Always starts a new
# feed from scratch to account for deleted recordings
#unlink("$XMLDIR/roku.xml");
unlink glob "$XMLDIR/*.xml";
 
##
# Iterate through the directory picking out all the .mp4 files and add them to a Roku XML list - brute force style
##
 
# Get a list of the files
opendir(DIR, $VIDDIR);
my @Files1 = readdir(DIR);
closedir(DIR);
 
# Loop thru each of these files
my @Files;
foreach my $File (@Files1) {
    # Get information (including last modified date) about file
    my @FileData = stat($VIDDIR."/".$File);
    
    # Push this into a new array with date at front
    push(@Files, $FileData[9]."&&".$File);
}

# Sort this array
@Files = reverse(sort(@Files));
 
# Loop thru the files
my %cats;
foreach my $File (@Files) {
    
    # Get the filename back from the string
    my (undef, $f) = split(/\&\&/,$File);
    
    if ( $f =~ /\.mp4$/ ){
	my $show = get_show_info($f);
	next unless $show->{bitrate};
	next if $show->{recgroup} eq "Deleted";
	
	my $item = output_show($show);

	my $cat = crypt($show->{title},"ab");
	$cat =~ s,/,-,g;

	if (!exists $cats{$cat}) {
	    $cats{$cat} = { 
		title => encode_entities_numeric($show->{title}),
		eps => 0,
		img => "$BASEURL/video/" . find_img($show->{basename}),
		feed => "$BASEURL/$cat",
		xml => "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<feed>\n",
		'r.xml' => "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<feed>\n",
		'u.xml' => "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<feed>\n",
	    };
	}
	$cats{$cat}->{eps} ++;
	$cats{$cat}->{xml} .= $item;

	$cats{$cat}->{"r.xml"} .= $item if $show->{recent};
	$cats{$cat}->{"u.xml"} .= $item if $show->{unwatched};
	
    }
}

# Creates a new file and fills in the headers of the feed using the information above
sysopen (MAINXML, "$XMLDIR/roku.xml", O_RDWR|O_EXCL|O_CREAT, 0644);
printf MAINXML "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n";
printf MAINXML "<categories>\n";
 
# output all categories
foreach my $h (values %cats) {
    my $s = ($h->{'eps'} > 1 ? "s" : "");
    print MAINXML "  <category title=\"$h->{'title'}\" description=\"$h->{'eps'} episode$s\"";
    print MAINXML " sd_img=\"$h->{'img'}\" hd_img=\"$h->{'img'}\">\n";
    print MAINXML "    <categoryLeaf title=\"All\" description=\"\" feed=\"$h->{'feed'}.xml\" />\n";
    print MAINXML "    <categoryLeaf title=\"Recent\" description=\"\" feed=\"$h->{'feed'}.r.xml\" />\n";
    print MAINXML "    <categoryLeaf title=\"Unwatched\" description=\"\" feed=\"$h->{'feed'}.u.xml\" />\n";
    print MAINXML "  </category>\n";
}

# Adds the closing tags for the feed and closes out the file
printf MAINXML "</categories>\n";
close(MAINXML);

foreach my $cat (keys %cats) {
    foreach my $t ("xml", "r.xml", "u.xml") {
	$cats{$cat}->{$t} .= "</feed>\n";

	open CATXML, ">$XMLDIR/$cat.$t";
	print CATXML $cats{$cat}->{$t};
	close CATXML;
    }
}

system("/usr/bin/xsltproc --output '$XMLDIR/roku.html' '$XMLDIR/feedstyle.xsl' '$XMLDIR/roku.xml'");

