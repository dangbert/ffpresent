#!/bin/sh
# read config file ($1)
# and convert each file one by one to dnxhd
# and rotate files (where rot!=""), adding black padding as needed
# (the point is someone can manually modify the file before running this step)
# mediainfo <video> # (useful command)


# https://en.wikipedia.org/wiki/List_of_Avid_DNxHD_resolutions
OUT_BITRATE="45M"       # output bitrate (36M, 45M, 75M, 115M, ...) (Mbps)
OUT_SCALE=("1920" "1080")
OUT_EXT="mov"           # output file extension

LOG_FILE="tmp-ffmpeg-log.txt"
OUT_LIST="tmp-combine-list.txt"
OUT_COMBINED="out-combined.mov"

function process_config() {
    CONFIG_FILE="$1"
    rm -rf /tmp/converted_vids && mkdir -p /tmp/converted_vids
    rm -f $LOG_FILE $OUT_LIST $OUT_COMBINED

    if [ "$#" -ne 1 ]; then
        echo "ERROR expected 1 arg, received: $#"
        echo "USAGE:"
        echo "  ./process_config.sh config.txt"
        exit 1
    fi
    echo "ffmpeg progress will be logged to: ${LOG_FILE}" && echo ""

    echo "current line:"
    # iterate over lines in $config_file
    while IFS= read -r line
    do
        echo "  >>> $line"
        # parse values from line:
        IFS=',' read -ra ARR <<< "$line"
        count=$(awk -F"," '{print NF-1}' <<< "${line}")
        if [ "$count" -ne "3" ]; then
            echo "ERROR: found $count occurences of delimter (expected 3)."
            exit 1
        fi
        fname=${ARR[0]}; rot=${ARR[1]}; width=${ARR[2]}; height=${ARR[3]}

        # generate filename:
        # TODO: maybe use existing path/filename but prepend "CONV--"
        # https://www.cyberciti.biz/faq/bash-get-basename-of-filename-or-directory-name/
        # https://stackoverflow.com/a/14892459
        newfile="$(mktemp -u --tmpdir=/tmp/converted_vids).${OUT_EXT}" && rm -f $newfile

        ###
        # flags for conversion (must store these in an array!) https://stackoverflow.com/a/29175560
        CONV_FLAGS=(
            -c:a pcm_s16le
            -af "aresample=async=1024"
            -c:v dnxhd
            -b:v $OUT_BITRATE
            # (last flag must be the value for -vf)
            -vf 'scale='${OUT_SCALE[0]}:${OUT_SCALE[1]}',fps=30000/1001,format=yuv422p'
        )
        flags=("${CONV_FLAGS[@]}")              # copy array of flags
        ###

        # check if video is vertical (set flags to rotate and add black bars during re-encoding):
        if ! [ -z "$rot" ] || [ "$height" -gt "$width" ]; then
            flags[-1]="scale=-1:${OUT_SCALE[1]},pad=${OUT_SCALE[0]}:${OUT_SCALE[1]}:(ow-iw)/2:color=Black,${flags[-1]}"
        fi

        # print command to log and re-encode:
        echo "">>${LOG_FILE} && echo "ffmpeg -hide_banner -y -i $fname ${flags[@]} ${newfile} < /dev/null >>${LOG_FILE} 2>&1" >>${LOG_FILE}
        ffmpeg -hide_banner -y -i $fname ${flags[@]} ${newfile} </dev/null >>${LOG_FILE} 2>&1
        if [ "$?" -ne "0" ]; then
            echo "ERROR: (exit code $?) converting video: \"$fname\" (aborting early)..."
            echo "  $CMD" && echo "" && exit 1
        fi
        echo "file $newfile" >> $OUT_LIST
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

    echo "" && echo "*****************:" && echo "list to combine outputted to: $OUT_LIST"
    echo "  combining videos..." && echo ""
    #ffmpeg -f concat -y -safe 0 -i $OUT_LIST -c copy -af "aresample=async=1024" $OUT_COMBINED </dev/null >>${LOG_FILE} 2>&1
    ffmpeg -f concat -y -safe 0 -i $OUT_LIST -c copy $OUT_COMBINED </dev/null >>${LOG_FILE} 2>&1

    if [ "$?" -ne "0" ]; then
        echo "  ERROR: (exit code $?) combining videos: $fname"
        exit 1
    fi
    echo "  combined video generated: $OUT_COMBINED"
}

process_config "$@"
