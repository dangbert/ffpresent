#!/bin/sh
# script to combine a bunch of videos with the same codec into 1 long video
# (sorts by date created)
# arg $1 is the name of a text file listing video files to combine (delimted by newline)
#   (and in order desired to combine them in)
# TODO: create another simple script to automatically generate that (whitelist of video file types, ordered by time stamp)
# TODO: check this works with spaces in filenames (at some point)

TMP_FILE=tmp-config.txt
#OUT_FILE=output.mp4

# outputs a text file with the metadata about each file to be combined
# input: $1 (name of file listing filenames seperated by newlines)
function generate_config() {
    LIST_FILE="$1"

    rm -f $TMP_FILE
    #if [ -f "$OUT_FILE" ]; then
    #    echo "output file "$OUT_FILE" already exists. Delete and try again."
    #    exit 1
    #fi

    if [ "$#" -ne 1 ]; then
        echo "ERROR expected 1 arg, received: $#"
        echo "USAGE:"
        echo "  ./generate_config.sh list.txt"
        exit 1
    fi

    # iterate over file names in $LIST_FILE
    while IFS= read -r fname
    do
        #echo "fname=$fname"
        rot="$(get_rot $fname)"
        res="$(get_res $fname)"
        width=$(cut -d 'x' -f1 <<< $res)
        height=$(cut -d 'x' -f2 <<< $res)

        # add this to TMP_FILE
        #echo "file $fname" >> $TMP_FILE
        echo "$fname,$rot,$width,$height" >> $TMP_FILE
    done < "$LIST_FILE"

    # combine into one video
    #ffmpeg -f concat -safe 0 -i $TMP_FILE -c copy output.mp4
    echo "created: $TMP_FILE"
}

# returns "" if given video is already horizontal
# else returns the number of degrees the video should be rotated
function get_rot() {
    FNAME="$1" # name of file to check
    # get angle that video needs to be rotated ("" if already horizontal)
    rot=`ffprobe -loglevel error -select_streams v:0 -show_entries stream_tags=rotate -of default=nw=1:nk=1 -i $FNAME`

    echo $rot
}

# returns resolution of video "<width>x<height>" (e.g. "1280x720")
function get_res() {
    FNAME="$1" # name of file to check
    # get angle that video needs to be rotated ("" if already horizontal)
    val=`ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 -i $FNAME`
    echo $val
}

generate_config "$@"
