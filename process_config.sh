#!/bin/sh
# read config file ($1)
# and convert each file one by one to dnxhd
# and rotate files (where rot!=""), adding black padding as needed
# (the point is someone can manually modify the file before running this step)
# mediainfo <video> # (useful command)


# https://en.wikipedia.org/wiki/List_of_Avid_DNxHD_resolutions
OUT_BITRATE="45M"       # output bitrate (36M, 45M, 75M, 115M, ...) (Mbps)
OUT_SCALE="1920:1080"   #"1280:720" #"iw:-1"
OUT_EXT="mov"           # output file extension

# flags for conversion (must store these in an array!)
# https://stackoverflow.com/a/29175560
CONV_FLAGS=(
    -c:v dnxhd
    -vf 'scale='${OUT_SCALE}',fps=30000/1001,format=yuv422p'
    -b:v $OUT_BITRATE
    -c:a pcm_s16le
)
    #-af 'aresample=async=1024'
    # ^i don't think we need the async flag until we start combining videos
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

    # get index of the value string for the -vf flag (in CONV_FLAGS)
    loc=$(get_loc)

    # iterate over lines in $config_file
    while IFS= read -r line
    do
        echo "" && echo "current=>>> $line"
        flags=("${CONV_FLAGS[@]}")              # copy array of flags

        # parse values from line
        IFS=',' read -ra ARR <<< "$line"
        count=$(awk -F"," '{print NF-1}' <<< "${line}")
        if [ "$count" -ne "3" ]; then
            echo "ERROR: found $count occurences of delimter (expected 3)."
            exit 1
        fi
        fname=${ARR[0]}; rot=${ARR[1]}; width=${ARR[2]}; height=${ARR[3]}


        # set flags for rotation (if needed):
        # https://stackoverflow.com/a/9570992
        # TODO: delete this part?
        flags_rot=() # empty array
        str=""
        if [ "$rot" == "90" ]; then
            str="transpose=1"
            flags_rot+=(-vf 'transpose=1')
        elif [ "$rot" == "180" ]; then
            str="transpose=2,transpose=2"
            flags_rot+=(-vf 'transpose=2,transpose=2')
        elif [ "$rot" == "270" ]; then
            str="transpose=2"
            flags_rot+=(-vf 'transpose=2')
        fi

        # rotate and add padding to video if needed (modify -vf filter)
        # TODO: note: also must check if dimensions are 1080x1920 (for iphone)
        if ! [ -z "$rot" ]; then
            # TODO: don't hardcode  width, height?
            flags[$loc]="${flags[$loc]},pad=width=1920:height=1080:x=ih:y=(ow-iw)/2:color=AliceBlue,transpose=1" #,$str
            echo "  modified -vf filter to: \"${flags[$loc]}\""
        fi

        # TODO: TODO: TODO: TODO:
        # TODO: magic line for converting all vertical videos to horizontal with padding:
        # !!!!!!!!
        #ffmpeg -hide_banner -y -i iphone/VER_2.MOV -c:v dnxhd -vf "scale=-1:1080,pad=1920:1080:(ow-iw)/2:color=AliceBlue,fps=30000/1001,format=yuv422p" -b:v 45M -c:a pcm_s16le /tmp/converted_vids/iphone_ver2.mov
        # !!!!!!!!
        # links:
        # filtergraph defined: http://ffmpeg.org/ffmpeg-filters.html#Filtergraph-description
        # read definition/options for each filter to understand
        # https://ffmpeg.org/ffmpeg-filters.html#scale-1
        # https://ffmpeg.org/ffmpeg-filters.html#pad-1
        # TODO: TODO: TODO: TODO:






        # generate filename
        # TODO: maybe use existing path/filename but prepend "CONV--"
        # https://www.cyberciti.biz/faq/bash-get-basename-of-filename-or-directory-name/
        # https://stackoverflow.com/a/14892459
        newfile="$(mktemp -u --tmpdir=/tmp/converted_vids).${OUT_EXT}" && rm -f $newfile

        # print command to log
        echo "">>${LOG_FILE} && echo "ffmpeg -hide_banner -y -i $fname ${flags[@]} ${newfile} < /dev/null >>${LOG_FILE} 2>&1" >>${LOG_FILE}
        # run command
        ffmpeg -hide_banner -y -i $fname ${flags[@]} ${newfile} </dev/null >>${LOG_FILE} 2>&1

        if [ "$?" -ne "0" ]; then
            echo "ERROR: (exit code $?) converting video: $fname"
            echo "  $CMD" && echo "" && exit 1
        fi
        # TODO: use another tool/command to copy the metadata afterwards? (map_metadata?)
        #touch -r "$fname" "$newfile"  # copy original file's metadata

        echo "file $newfile" >> $OUT_LIST
    done < "$CONFIG_FILE"

    echo "" && echo "list to combine outputted to $OUT_LIST"
    echo "combining videos..." && echo ""
    ffmpeg -f concat -y -safe 0 -i $OUT_LIST -c copy $OUT_COMBINED </dev/null >>${LOG_FILE} 2>&1

    if [ "$?" -ne "0" ]; then
        echo "ERROR: (exit code $?) combining videos: $fname"
        exit 1
    fi
    echo "combined video generated: $OUT_COMBINED"
}

# returns the location of the value corresponding to the -vf flag in CONV_FLAGS
# or exits if this value doesn't exist in the array
function get_loc() {
    for loc in "${!CONV_FLAGS[@]}"; do
        #echo "$loc => ${CONV_FLAGS[$loc]}"
        if [ "${CONV_FLAGS[$loc]}" == "-vf" ]; then
            loc=$((loc+1))
            break
        fi
    done
    #echo "loc=$loc (of ${#CONV_FLAGS[@]})"
    if (( "$loc" == "${#CONV_FLAGS[@]}-1" )); then
        echo "ERROR: flag '-vf' not found in array CONV_FLAGS"
        exit 1
    fi
    echo "$loc"
}

process_config "$@"
