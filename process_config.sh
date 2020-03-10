#!/bin/sh
#################################################
# reads config file ($1)
#   and converts each file one by one to dnxhd according to provided config
#   then combine everythin into a file outputted video in the folder $2
#################################################
# mediainfo <video> # (useful command)
# get help with a filter (e.g. apad):
#  ffmpeg -h filter=apad
#
# TODO: https://ffmpeg.org/ffmpeg-filters.html#concat
#       https://stackoverflow.com/questions/47050033/ffmpeg-join-two-movies-with-different-timebase
#       https://github.com/leandromoreira/ffmpeg-libav-tutorial#learn-ffmpeg-libav-the-hard-way

#
# TODO: store these values somewhere at top of project.ffpres
####################################################################################################
# https://en.wikipedia.org/wiki/List_of_Avid_DNxHD_resolutions
OUT_EXT="mov"              # output file extension (don't change this)
OUT_SCALE=("1920" "1080")  # output resoulution
OUT_BITRATE="36M"          # output bitrate (36M, 45M, 75M, 115M, ...) (Mbps)
FPS="25"                   # frames per second (25, 30000/1001, 50, ...)
AUDIO_FREQ="48000"         # output audio frequency in HZ (number of samples of audio carried per second)
IMG_DUR="4.1"              # default image duration (sec). overwritten by "dur" field in config if a number is provided there
B_COLOR="Black"            # background color for padding videos to fit OUT_SCALE
FFMPEG_THREADS="1"         # number of threads for ffmpeg to use
DEBUG="0"                  # 0 for normal mode, 1 for debug mode (overlaid text details on video)
FONT="/usr/share/fonts/gnu-free/FreeSans.ttf"   # path to font file used for debug text
####################################################################################################

# flags used if media has no audio
#  (fixes issue with final combined video's audio when a video in the middle has no audio)
SILENT_FIX_FLAGS=(
    #   https://superuser.com/a/1096968
    #-f lavfi -i aevalsrc=0 -shortest
    #   https://stackoverflow.com/a/12375018
    -f lavfi -i anullsrc=cl=stereo:r=$AUDIO_FREQ
)

# TODO: try to make mov files smaller? https://superuser.com/questions/525279/reduce-mov-file-size https://ffmpeg.org/ffmpeg-codecs.html
# flags in ffmpeg command for conversion:
#   (best to store these in an array!) https://stackoverflow.com/a/29175560
CONV_FLAGS=(
    -threads "$FFMPEG_THREADS"
    -c:a pcm_s16le
    -af "aresample=async=1024"
    #-async 25
    #-af "apad"
    #-af "asettb=expr=1/48000"
    #-shortest
    #-avoid_negative_ts make_zero
    #-video_track_timescale 600
    -fflags +genpts
    -c:v dnxhd
    -b:v $OUT_BITRATE
    # TODO: crf option isn't working (for lowering file size):
    #-crf 5 # Valid range is 0 (lower quality) to 63 (higher quality). Only used if set; by default only the bitrate target is used.
    -ar $AUDIO_FREQ # set the audio sampling frequency
    # important! videos must either be all stereo or all mono before concat:
    -ac 2 # force all videos to have exactly two audio channels
    -shortest # needed for SILENT_FIX_FLAGS
    # NOTE: last flag must be the value for -vf (because later we will reference [-1] to modify it)
    -vf "settb=expr=1/30000,fps=$FPS,format=yuv422p"
)

function process_config() {
    if [ "$#" -ne 2 ]; then
        echo "ERROR expected 2 args, received: $#"
        echo "USAGE:"
        echo "  ./process_config.sh <config_file> <output_folder>"
        echo "  EXAMPLE: ./process_config.sh list-detailed.txt /tmp"
        exit 1
    fi

    CONFIG_FILE="$1"
    FOLDER="$2/combined_output"
    FOLDER_MOVS="$FOLDER/intermediary" # folder to store converted mov files
    LOG_FILE="$FOLDER/ffmpeg-log.txt"
    OUT_LIST="$FOLDER/combine-list.txt"
    OUT_COMBINED="$FOLDER/out-combined.mov"

    if [ -d "$FOLDER" ]; then
        echo "output folder \"$FOLDER\" already exists. Delete and try again."
        exit 1
    fi
    echo "All outputs will be saved in: \"${FOLDER}\"..."
    mkdir -p "$FOLDER" && mkdir -p "$FOLDER_MOVS"
    echo "ffmpeg progress will be logged to: \"${LOG_FILE}\"..."

    echo -e "\ncurrent line (note lines starting with '#' are skipped):"
    local skipCount="0"
    local curLine="0"
    local totalLines="$(wc -l "$CONFIG_FILE")"
    local errCount="0"
    # iterate over lines in $config_file
    # TODO: convert videos in the list in parallel
    #   https://stackoverflow.com/a/43308733
    while IFS= read -r line
    do
        curLine="$((curLine+1))"
        # support commented lines here
        # TODO: get it working with leading spaces
        #if [[ "$(echo $("$line" | xargs echo -n ))" == \#* ]]; then
        if [[ "$(echo $(echo "$line"))" == \#* ]]; then
            skipCount="$((skipCount+1))"
            continue
        fi
        echo -e "(line $curLine/$totalLines) >>> $line"
        echo -e "\n(line $curLine/$totalLines) >>> $line" >> "${LOG_FILE}"
        # parse values from line:
        IFS=',' read -ra ARR <<< "$line"
        local count=$(awk -F"," '{print NF-1}' <<< "${line}")
        if [ "$count" -lt "5" ]; then # may be more than 5 if fname contains a comma
            echo "ERROR: found $count occurences of delimter (expected 5)."
            exit 1
        elif [ "$count" -gt "5" ]; then
            echo "WARNING: found $count occurences of delimter (expected 5)."
            echo "  line> $line"
            continue # TODO: for now
            # TODO: if count > 5 we should combine the last elements of the array (to handle filenames with a comma
        fi
        local fType="${ARR[0]}"; local width="${ARR[1]}"; local height="${ARR[2]}";
        local rot="${ARR[3]}";   local dur="${ARR[4]}";   local fname="${ARR[5]}"

        if ! [ -f "$fname" ]; then
            echo -e "\tERROR: file not found (skipping for now): '$fname'"
            errCount="$((errCount+1))"
            continue
        fi
        ###
        # generate filename (doesn't create file):
        #   TODO: create a new folder and put all the new files in with the same hierachy as before???
        #   https://www.cyberciti.biz/faq/bash-get-basename-of-filename-or-directory-name/
        #   https://stackoverflow.com/a/14892459
        #newfile="$(mktemp -u "$FOLDER_MOVS/`basename "$fname"`.XXXXX".${OUT_EXT})" # handles duplicates
        local newfile="$FOLDER_MOVS/`basename "$fname"`.${OUT_EXT}" # TODO: this doesn't handle duplicates
        if [ -f "$newFile" ]; then
            echo -e "\tWARNING: overwriting existing file '$newFile'"
        fi
        ###

        # TODO: have way a debug mode where the line number in the file is overlaid on each clip

        local conv_flags=("${CONV_FLAGS[@]}")         # copy array of flags
        local pre_flags=()                            # flags coming in command before "-i $fname"
        ########
        # flags to force videos with no audio stream to have a silent audio stream:
        # (needed for video concat to have the audios line up)
        if [[ -z "$(ffprobe -i "$fname" -show_streams -select_streams a -loglevel error)" ]]; then
            pre_flags=("${SILENT_FIX_FLAGS[@]}")
        fi
        ########
        if [ "$fType" == "image" ]; then
            local imgDur="$IMG_DUR"
            if [[ "$dur" =~ ^[0-9]+([.][0-9]+)?$ ]]; then # check if $dur is a number (int or float)
                imgDur="$dur"
            fi
            # adjust flags as needed to convert this image to a video:
            pre_flags+=("-loop" "1" "-f" "image2")
            conv_flags=("-t" "$imgDur" "${conv_flags[@]}")
            #echo "image's encoding is: $(exiftool "$fname" | grep -i "encoding")"
            # TODO: for images set a timeout timer for ffmpeg conversion
            #   because for example 20180625_162004.jpg never times out do to some issue with that image...

            # TODO: add ability to slowly zoom in or zoom out on images
            #   https://superuser.com/a/1127759
            #   https://ffmpeg.org/ffmpeg-filters.html#zoompan
        fi

        # compare current to desired aspect ratio to desired to determine how to scale (before padding)
        #   https://ffmpeg.org/ffmpeg-filters.html#pad-1
        if [ "$(awk -v a="$width" -v b="$height" -v c="${OUT_SCALE[0]}" -v d="${OUT_SCALE[1]}" "BEGIN{print( a/b <= c/d )}")" -eq "1" ]; then
            # and example of this case would be a vertical video (where we'd want to add black bars on either side)
            # prepend to vf filters:
            conv_flags[-1]="scale=-1:${OUT_SCALE[1]},pad=${OUT_SCALE[0]}:${OUT_SCALE[1]}:x=(ow-iw)/2:color=${B_COLOR},${conv_flags[-1]}"
        else
            # and example of this case would be a very wide panorama image
            conv_flags[-1]="scale=${OUT_SCALE[0]}:-1,pad=${OUT_SCALE[0]}:${OUT_SCALE[1]}:y=(oh-ih)/2:color=${B_COLOR},${conv_flags[-1]}"
        fi

        # debug mode (ovelay text details on videos):
        if [ "$DEBUG" -eq "1" ]; then
            local debugText="line #${curLine}, \"$(basename "$fname")\""
            # using printf to escape symbols like spaces, etc https://stackoverflow.com/a/12811033
            conv_flags[-1]="${conv_flags[-1]},drawtext=fontfile=${FONT}:text='$(printf %q "$debugText")':fontcolor=white:fontsize=24:box=1:boxcolor=black:x=(w-text_w)/2:y=h-th"
        fi
        # allows us to put extra quotes around vf_args in the command below (needed when doing text overlay e.g. if there's a space in the text)
        local vf_args="${conv_flags[-1]}"
        conv_flags[-1]=""

        # print command to log then re-encode:
        echo -e "\nffmpeg -hide_banner -loglevel warning -y ${pre_flags[@]} -i \"$fname\" ${conv_flags[@]} \"$vf_args\" \"${newfile}\""  >>"${LOG_FILE}"
        ffmpeg -hide_banner -loglevel warning -y ${pre_flags[@]} -i "$fname" ${conv_flags[@]} "$vf_args" "${newfile}"  </dev/null >>"${LOG_FILE}" 2>&1
        if [ "$?" -ne "0" ]; then
            echo "ERROR: (exit code $?) converting video: \"$fname\" (skipping for now)...\n"
            errCount="$((errCount+1))"
            continue
        fi
        # TODO: also preserve metadata from original file (date created, etc)?
        # TODO: replace occurences of ' in $newfile with '\'' https://superuser.com/a/787651 (in case image has ' in its filename)
        printf "file \'`realpath "$newfile"`\'\n" >> "$OUT_LIST" # store the absolute path to this file in "$OUT_LIST"
    done < "$CONFIG_FILE"

    echo -e "\n*****************:\nFinished re-encoding videos!"
    if [ "$skipCount" -gt "0" ]; then
        echo "Note: skipped $skipCount commented lines in \"$CONFIG_FILE\""
    fi
    if [ "$errCount" -gt "0" ]; then
        echo "WARNING: $errCount errors processing \"$CONFIG_FILE\""
    fi
    echo "List of videos used to concatenate outputted to: \"$OUT_LIST\""
    echo "*****************:"

    # concatenate videos into one:
    #  (keep in mind that for this step it is critical that all videos being combined
    #    are the exact same encoding, number of audio streams, SAR/DAR, etc)
    echo -e "\nCombining videos... in \"$OUT_LIST\"\n"
    echo -e "\n===================\nCommand for combining videos:" >>"${LOG_FILE}"
    echo -e "ffmpeg -hide_banner -loglevel warning -f concat -y -safe 0 -i \"$OUT_LIST\" -c copy -threads \"$FFMPEG_THREADS\" \"$OUT_COMBINED\""  >>"${LOG_FILE}"
    # TODO: consider putting this output to the terminal as well (it seems to exit with code 0 even if it can't open one image)
    ffmpeg -hide_banner -loglevel warning -f concat -y -safe 0 -i "$OUT_LIST" -c copy -threads "$FFMPEG_THREADS" "$OUT_COMBINED"  </dev/null >>"${LOG_FILE}" 2>&1

    if [ "$?" -ne "0" ]; then
        echo "  ERROR: (exit code $?) combining videos"
        exit 1
    fi
    echo "  combined video generated: \"$OUT_COMBINED\""
}

process_config "$@"
