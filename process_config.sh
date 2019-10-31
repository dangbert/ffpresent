#!/bin/sh
# read config file ($1)
# and convert each file one by one to dnxhd
# and rotate files (where rot!=""), adding black padding as needed
# (the point is someone can manually modify the file before running this step)
# mediainfo <video> # (useful command)
# get help with a filter (e.g. apad):
#  ffmpeg -h filter=apad
#
# useful filters to consider in future:
#   (https://ffmpeg.org/ffmpeg-filters.html)
#   afade (apply fad-in/out effect to input audio)
#   apad (pad the end of an audio stream with silence)
#   aresample (stretch/squeeze the audio data to make it match the timestamps or to inject silence / cut out audio to make it match the timestamps)
#
# note: sample rate is the number of samples of audio carried per second (measured in HZ)
#  you can see this when you do `ffmpeg -i <video_file>`

# view the time_base of files: (this is important):
#  https://video.stackexchange.com/a/19238
#   ls *.mov | xargs -L 1 ffprobe -select_streams a -show_entries stream=time_base -of compact=p=0 2>/dev/null| grep -i "time_base"
# 
# what is a timebase? https://stackoverflow.com/a/43337235
#   (a defined unit of time to serve as a unit representing one tick of a clock)
#   PTS (Presentation Time Stamps) are denominated in terms of this timebase.
#   "tbn" (in ffmpeg readout) = Timescale = 1 / timebase
#
# TODO: https://ffmpeg.org/ffmpeg-filters.html#concat
#       https://stackoverflow.com/questions/47050033/ffmpeg-join-two-movies-with-different-timebase
#       https://github.com/leandromoreira/ffmpeg-libav-tutorial#learn-ffmpeg-libav-the-hard-way

# https://en.wikipedia.org/wiki/List_of_Avid_DNxHD_resolutions
OUT_BITRATE="45M"       # output bitrate (36M, 45M, 75M, 115M, ...) (Mbps)
OUT_SCALE=("1920" "1080")
OUT_EXT="mov"           # output file extension

FOLDER=/tmp/converted_vids  # folder for storing intermediary .mov outputs
FOLDER_MKV=/tmp/mkv  # folder for storing intermediary .mkv outputs
LOG_FILE="$FOLDER/tmp-ffmpeg-log.txt"
OUT_LIST="$FOLDER/tmp-combine-list.txt"
OUT_COMBINED="$FOLDER/out-combined.mov"

function process_config() {
    CONFIG_FILE="$1"
    rm -rf $FOLDER && mkdir -p $FOLDER
    rm -rf $FOLDER_MKV && mkdir -p $FOLDER_MKV
    rm -f $LOG_FILE $OUT_LIST $OUT_COMBINED

    if [ "$#" -ne 1 ]; then
        echo "ERROR expected 1 arg, received: $#"
        echo "USAGE:"
        echo "  ./process_config.sh config.txt"
        exit 1
    fi
    echo "ffmpeg progress will be logged to: ${LOG_FILE}" && echo ""

    echo "current line:"
    skipCount=0
    # iterate over lines in $config_file
    while IFS= read -r line
    do
        if [[ "$line" == \#* ]]; then
            skipCount=$((skipCount+1))
            continue
        fi
        echo "  >>> $line"
        # parse values from line:
        IFS=',' read -ra ARR <<< "$line"
        count=$(awk -F"," '{print NF-1}' <<< "${line}")
        if [ "$count" -ne "3" ]; then
            echo "ERROR: found $count occurences of delimter (expected 3)."
            exit 1
        fi
        fname=${ARR[0]}; rot=${ARR[1]}; width=${ARR[2]}; height=${ARR[3]}

        ###
        # generate filename:
        # TODO: maybe use existing path/filename but prepend "CONV--"
        # https://www.cyberciti.biz/faq/bash-get-basename-of-filename-or-directory-name/
        # https://stackoverflow.com/a/14892459
        newfile="$(mktemp -u --tmpdir=$FOLDER).${OUT_EXT}" && rm -f $newfile
        ###
        # flags for conversion (must store these in an array!) https://stackoverflow.com/a/29175560
        # TODO: ensure both audio channels are preserved (Left/right) (remember the issue from last time)
        CONV_FLAGS=(
            -c:a pcm_s16le
            #-async 25
            #-af "aresample=async"
            #-af "apad"
            #-af "asettb=expr=1/48000"
            #-shortest
            #-avoid_negative_ts make_zero
            #-video_track_timescale 600
            -fflags +genpts
            -c:v dnxhd
            -b:v $OUT_BITRATE
            -ar 48000 # set the audio sampling frequency
            # important! videos must either be all stereo or all mono before concat:
            -ac 2 # force all videos to have ecactly two audio channels
            # (last flag must be the value for -vf):
            -vf 'settb=expr=1/30000,scale='${OUT_SCALE[0]}:${OUT_SCALE[1]}',fps=30000/1001,format=yuv422p'
        )
        flags=("${CONV_FLAGS[@]}")              # copy array of flags

        # check if video is vertical (set flags to rotate and add black bars during re-encoding):
        if ! [ -z "$rot" ] || [ "$height" -gt "$width" ]; then
            flags[-1]="scale=-1:${OUT_SCALE[1]},pad=${OUT_SCALE[0]}:${OUT_SCALE[1]}:(ow-iw)/2:color=Black,${flags[-1]}"
        fi

        # print command to log and re-encode:
        echo "">>${LOG_FILE} && echo "ffmpeg -hide_banner -loglevel warning -y -i $fname ${flags[@]} ${newfile} </dev/null >>${LOG_FILE} 2>&1" >>${LOG_FILE}
        ffmpeg -hide_banner -loglevel warning -y -i $fname ${flags[@]} ${newfile} </dev/null >>${LOG_FILE} 2>&1
        if [ "$?" -ne "0" ]; then
            echo "ERROR: (exit code $?) converting video: \"$fname\" (aborting early)..."
            echo "  $CMD" && echo "" && exit 1
        fi
        # store the absolute path to this file in $OUT_LIST
        echo "file `realpath $newfile`" >> $OUT_LIST
        # TODO: also preserve metadata from original file (date created, etc)?

        ##########
        # working example for converting all vertical videos to horizontal with padding:
        #   ffmpeg -hide_banner -y -i iphone/VER_2.MOV -c:v dnxhd -vf "scale=-1:1080,pad=1920:1080:(ow-iw)/2:color=AliceBlue,fps=30000/1001,format=yuv422p" -b:v 45M -c:a pcm_s16le /tmp/converted_vids/iphone_ver2.mov
        # links:
        #   filtergraph defined: http://ffmpeg.org/ffmpeg-filters.html#Filtergraph-description
        #   (read definition/options for each filter to understand)
        #   https://ffmpeg.org/ffmpeg-filters.html#scale-1
        #   https://ffmpeg.org/ffmpeg-filters.html#pad-1
        ##########
    done < "$CONFIG_FILE"

    echo "" && echo "*****************:" && echo "Finished re-encoding videos!"
    if [ "$skipCount" -gt "0" ]; then
        echo "Note: skipped $skipCount commented lines in \"$CONFIG_FILE\""
    fi
    echo "List of videos to concatenate outputted to: $OUT_LIST"
    echo "*****************:"

    echo "" && echo "Combining videos... in $OUT_LIST" && echo ""
    echo "">>${LOG_FILE} && echo "ffmpeg -f concat -y -safe 0 -i $OUT_LIST -c copy $OUT_COMBINED </dev/null >>${LOG_FILE} 2>&1" >>${LOG_FILE}
    ffmpeg -f concat -y -safe 0 -i $OUT_LIST -c copy $OUT_COMBINED </dev/null >>${LOG_FILE} 2>&1

    if [ "$?" -ne "0" ]; then
        echo "  ERROR: (exit code $?) combining videos"
        exit 1
    fi
    echo "  combined video generated: $OUT_COMBINED"
}

process_config "$@"
