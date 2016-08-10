#!/bin/bash
 
set -e

FILENAME=$1
SCRIPTDIR=/video/roku
 
# make sure there is videodir and filename entered and it exists
if [ -z "$FILENAME" ]; then
        echo "Usage: $0 <FileName>"
        exit 5
fi
if [ ! -f "$FILENAME" ]; then
        echo "File does not exist: $FILENAME"
        exit 6
fi
 
BASENAME=$(basename "$FILENAME" .mpg)
BASENAME=$(basename "$BASENAME" .mp4) # trim mp4 extension if needed
VIDEODIR=$(dirname "$FILENAME")
OUTFILE="$VIDEODIR/$BASENAME.mp4"

# in-place transcode
if [ "$FILENAME" -ef "$OUTFILE" ]; then
        NEWFILENAME="$(basename "$FILENAME" .mp4).orig.mp4"
        mv "$FILENAME" "$NEWFILENAME"
	FILENAME="$NEWFILENAME"
fi

# remove the output file if it already exists
if [ -f "$OUTFILE" ]; then
        rm -f "$OUTFILE"
fi
 
TRANSCODELOG="$SCRIPTDIR/logs/$BASENAME.log"
rm -f "$TRANSCODELOG"
echo $(date) start >> "$TRANSCODELOG"

## Flag commercials, generate cutlist, copy cutlist, transcode, clear cutlist
#/usr/bin/nice -n 19 mythcommflag --gencutlist -f $VIDEODIR/$FILENAME
#ERROR=$?
#if [ $ERROR -ne 0 ]; then
#        echo "Copying cutlist failed for ${FILENAME} with error $ERROR"
#        exit $ERROR
#else
#        echo "Copying cutlist successful for ${FILENAME}."
#fi
# 
#CUTLIST=$(mythcommflag --getcutlist -f $VIDEODIR/$FILENAME | tail -n 1 | awk '{print $2}' | sed 's/,/ /g')
#ERROR=$?
#if [ $ERROR -ne 0 ]; then
#        echo "Copying cutlist failed for ${FILENAME} with error $ERROR"
#        exit $ERROR
#fi
# 
#/usr/bin/nice -n 19 mythtranscode --mpeg2 -i $VIDEODIR/$FILENAME --honorcutlist "$CUTLIST" -o $VIDEODIR/$FILENAME.tmp
# 
#ERROR=$?
#if [ $ERROR -ne 0 ]; then
#        echo "Transcoding failed for ${FILENAME} with error $ERROR"
#        exit $ERROR
#fi
# 
#mythcommflag --clearcutlist -f $VIDEODIR/$FILENAME
#ERROR=$?
#if [ $ERROR -ne 0 ]; then
#        echo "Clearing cutlist failed for ${FILENAME} with error $ERROR"
#        rm /usr/video/$FILENAME.tmp
#        exit $ERROR
#fi
 
 
 
 
# Create the MP4
 
#/usr/bin/nice -n 19 ffmpeg -i "${VIDEODIR}/${FILENAME}.tmp" -s 640x480 -deinterlace -vcodec libx264 -coder 1 -flags +loop -cmp +chroma -partitions +parti8x8+parti4x4+partp8x8+partb8x8 -me_method umh -subq 8 -me_range 16 -g 250 -keyint_min 25 -sc_threshold 40 -i_qfactor 0.71 -b_strategy 2 -qcomp 0.6 -qmin 10 -qmax 51 -qdiff 4 -bf 4 -refs 4 -directpred 3 -trellis 1 -flags2 +wpred+mixed_refs+dct8x8+fastpskip -acodec libfaac -ac 2 -ar 48000 -ab 96k -metadata title="${FILENAME}" "${VIDEODIR}/${FILENAME}.mp4" >> "/tmp/${FILENAME}.log" 2>&1

# detect crop settings
crop=$(ffmpeg -i "$FILENAME" -t 30 -vf cropdetect -f null - 2>&1 \
    | gawk '/crop/{print $NF}' | tail -1)

if [ -n "$crop" ]; then
    echo "Crop: $crop" >> "$TRANSCODELOG"
    # if long edge is greater than 1000 px, it's HD, scale to 720p
    if [ $(echo $crop | sed -r 's/crop=([0-9]+):.*/\1/') -gt 1000 ]; then
	scale="-s 1280x720"
	#echo "File is HD"
    else
	# kgutwin 2013-08-25  trying to avoid jaggy lines in cartoons (george)
	#scale="-s 853x480"
	#echo "File is SD"
	true
    fi
    if [ $(echo $crop | sed 's/.*://') -gt 20 ]; then
	crop=",$crop"
    else
	crop=""
    fi
    echo "result crop $crop scale $scale" >> "$TRANSCODELOG"
fi

#-coder 1 -flags +loop -cmp chroma \
#    -partitions parti8x8+parti4x4+partp8x8+partb8x8 -me_method umh \
#    -subq 8 -me_range 16 -g 250 -keyint_min 25 -sc_threshold 40 \
#    -i_qfactor 0.71 -b_strategy 2 -qcomp 0.6 -qmin 10 -qmax 51 -qdiff 4 \
#    -bf 4 -refs 4 -trellis 1 \
#    -weightb 1 \
# $crop -vpre roku -profile:v high -level 4.0 \

# yadif=0:-1:1

nice -n 19 ffmpeg -i "$FILENAME" \
    -acodec aac -strict -2 -ab 192k -ac 2 \
    -vcodec libx264 -vf yadif=0:-1:1$crop -vpre roku -profile:v high \
    -r 29.97 -level 4.0 $scale \
    -f mp4 -movflags faststart \
    -metadata title="$BASENAME" \
    "$OUTFILE" \
    >> "$TRANSCODELOG" 2>&1
 
#MP4Box -tmp "${VIDEODIR}" -inter 500 "${VIDEODIR}/${FILENAME}.mp4"
 
# Create Roku BIF thumbnail file
nice -n 19 perl $SCRIPTDIR/bifencode.pl ${VIDEODIR} "${BASENAME}.mp4" \
    >> "$TRANSCODELOG" 2>&1
 
# Update feed
perl $SCRIPTDIR/feed.pl \
    >> "$TRANSCODELOG" 2>&1

echo $(date) complete >> "$TRANSCODELOG"
echo "$OUTFILE"
exit 0
