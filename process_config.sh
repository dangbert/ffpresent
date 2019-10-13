#!/bin/sh
# read config file ($1)
# and convert each file one by one to dnxhd
# and rotate files (where rot!=""), adding black padding as needed
# (the point is someone can manually modify the file before running this step)


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

function process_config() {
    CONFIG_FILE="$1"
    rm -rf /tmp/converted_vids && mkdir -p /tmp/converted_vids
    rm -f $LOG_FILE

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
        if [ "$rot" == "90" ]; then
            flags_rot+=(-vf 'transpose=1')
        elif [ "$rot" == "180" ]; then
            flags_rot+=(-vf 'transpose=2,transpose=2')
        elif [ "$rot" == "270" ]; then
            flags_rot+=(-vf 'transpose=2')
        fi

        # rotate and add padding to video if needed (modify -vf filter)
        if ! [ -z "$rot" ]; then
            flags[$loc]="${flags[$loc]},pad=1920:1080:ih:(ow-iw)/2:color=AliceBlue"
            echo "  modified -vf filter to: \"${flags[$loc]}\""
        fi

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

        ## rotate video if needed
        #if ! [ -z "$flags_rot" ]; then
        #    # TODO: now do rotation
        #    #   https://video.stackexchange.com/a/17699
        #    #   see my MTS conversion script too
        #fi

    done < "$CONFIG_FILE"
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
