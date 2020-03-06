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

#
# TODO: store these values somewhere at top of project.ffpres
# https://en.wikipedia.org/wiki/List_of_Avid_DNxHD_resolutions
OUT_BITRATE="36M"          # output bitrate (36M, 45M, 75M, 115M, ...) (Mbps)
AUDIO_FREQ="48000"
OUT_SCALE=("1920" "1080")  # output resoulution
OUT_EXT="mov"              # output file extension (don't change this)
FFMPEG_THREADS="1"
IMG_DUR="3" # (sec) TODO: consider using the dur field in images ('d' for default)

# flags used if media has no audio
#  (fixes issue with final combined video's audio when a video in the middle has no audio)
SILENT_FIX_FLAGS=(
    #   https://superuser.com/a/1096968
    #-f lavfi -i aevalsrc=0 -shortest
    #   https://stackoverflow.com/a/12375018
    -f lavfi -i anullsrc=cl=stereo:r=$AUDIO_FREQ
)

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
    -ar $AUDIO_FREQ # set the audio sampling frequency
    # important! videos must either be all stereo or all mono before concat:
    -ac 2 # force all videos to have exactly two audio channels
    -shortest # needed for SILENT_FIX_FLAGS
    # NOTE: last flag must be the value for -vf (because later we will reference [-1] to modify it)
    -vf 'settb=expr=1/30000,scale='${OUT_SCALE[0]}:${OUT_SCALE[1]}',fps=30000/1001,format=yuv422p'
)

function process_config() {
    # TODO: create a "debug" mode where extra info is added to each video as overlaid text
    # (e.g. filename, location in config file, etc)
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
    LOG_FILE="$FOLDER/tmp-ffmpeg-log.txt"
    OUT_LIST="$FOLDER/list-combine.txt"
    OUT_COMBINED="$FOLDER/out-combined.mov"

    if [ -d "$FOLDER" ]; then
        echo "output folder \"$FOLDER\" already exists. Delete and try again."
        exit 1
    fi
    echo "All outputs will be saved in: \"${FOLDER}\"..."
    mkdir -p "$FOLDER" && mkdir -p "$FOLDER_MOVS"
    echo "ffmpeg progress will be logged to: \"${LOG_FILE}\"..." && echo ""

    echo "current line:"
    skipCount=0
    # iterate over lines in $config_file
    # TODO: convert videos in the list in parallel
    #   https://stackoverflow.com/a/43308733
    while IFS= read -r line
    do
        # support commented lines here
        # TODO: get it working with leading spaces
        #if [[ "$(echo $("$line" | xargs echo -n ))" == \#* ]]; then
        if [[ "$(echo $(echo "$line"))" == \#* ]]; then
            skipCount=$((skipCount+1))
            continue
        fi
        # TODO: consider adding something like: "  (line 3 of 201)"
        echo "  >>> $line"
        # parse values from line:
        IFS=',' read -ra ARR <<< "$line"
        count=$(awk -F"," '{print NF-1}' <<< "${line}")
        if [ "$count" -lt "5" ]; then # may be more than 5 if fname contains a comma
            echo "ERROR: found $count occurences of delimter (expected 5)."
            exit 1
        elif [ "$count" -gt "5" ]; then
            echo "WARNING: found $count occurences of delimter (expected 5)."
            echo "  line> $line"
            continue # TODO: for now
            # TODO: if count > 5 we should combine the last elements of the array (to handle filenames with a comma
        fi
        fType="${ARR[0]}"; width="${ARR[1]}"; height="${ARR[2]}"; rot="${ARR[3]}"; dur="${ARR[4]}"; fname="${ARR[5]}"

        ###
        # generate filename (doesn't create file):
        #   TODO: create a new folder and put all the new files in with the same hierachy as before???
        #   https://www.cyberciti.biz/faq/bash-get-basename-of-filename-or-directory-name/
        #   https://stackoverflow.com/a/14892459
        #newfile="$(mktemp -u --tmpdir="$FOLDER_MOVS").${OUT_EXT}"
        newfile="$(mktemp -u "$FOLDER_MOVS/`basename "$fname"`.XXXXX".${OUT_EXT})"
        ###

        conv_flags=("${CONV_FLAGS[@]}")         # copy array of flags
        pre_flags=()                            # flags coming in command before "-i $fname"
        ########
        # flags to force videos with no audio stream to have a silent audio stream:
        # (needed for video concat to have the audios line up)
        if [[ -z "$(ffprobe -i "$fname" -show_streams -select_streams a -loglevel error)" ]]; then
            # TODO: verify this works for images as well...
            pre_flags=("${SILENT_FIX_FLAGS[@]}")
        fi
        ########
        if [ "$fType" == "image" ]; then
            echo "image's encoding is: $(exiftool "$fname" | grep -i "encoding")"
            # adjust flags as needed to convert this image to a video
            pre_flags+=("-loop" "1" "-f" "image2")
            conv_flags=("-t" "$IMG_DUR" "${conv_flags[@]}")
        fi

        # check if video is vertical (set flags to rotate and add black bars during re-encoding):
        if ! [ -z "$rot" ] || [ "$height" -gt "$width" ]; then
            # tweak flags for -vf
            conv_flags[-1]="scale=-1:${OUT_SCALE[1]},pad=${OUT_SCALE[0]}:${OUT_SCALE[1]}:(ow-iw)/2:color=Black,${conv_flags[-1]}"
        fi

        # print command to log then re-encode:
        echo -e "\nffmpeg -hide_banner -loglevel warning -y ${pre_flags[@]} -i \"$fname\" ${conv_flags[@]} \"${newfile}\" </dev/null >>\"${LOG_FILE}\" 2>&1"  >>"${LOG_FILE}"
        ffmpeg -hide_banner -loglevel warning -y ${pre_flags[@]} -i "$fname" ${conv_flags[@]} "${newfile}"  </dev/null >>"${LOG_FILE}" 2>&1
        if [ "$?" -ne "0" ]; then
            echo "ERROR: (exit code $?) converting video: \"$fname\" (aborting early)..."
            echo "  $CMD" && echo "" && exit 1
        fi
        # TODO: also preserve metadata from original file (date created, etc)?
        # store the absolute path to this file in "$OUT_LIST"
        printf "file \'`realpath "$newfile"`\'\n" >> "$OUT_LIST"
    done < "$CONFIG_FILE"

    echo -e "\n*****************:\nFinished re-encoding videos!"
    if [ "$skipCount" -gt "0" ]; then
        echo "Note: skipped $skipCount commented lines in \"$CONFIG_FILE\""
    fi
    echo "List of videos used to concatenate outputted to: \"$OUT_LIST\""
    echo "*****************:"

    # concatenate videos into one:
    #  (keep in mind that for this step it is critical that all videos being combined
    #    are the exact same encoding, number of audio streams, etc)
    echo -e "\nCombining videos... in \"$OUT_LIST\"\n"
    echo -e "\n===================\nCommand for combining videos:" >>"${LOG_FILE}"
    echo -e "ffmpeg -f concat -y -safe 0 -i \"$OUT_LIST\" -c copy \"$OUT_COMBINED\" -threads "$FFMPEG_THREADS" </dev/null >>\"${LOG_FILE}\" 2>&1\n" >>"${LOG_FILE}"
    ffmpeg -f concat -y -safe 0 -i "$OUT_LIST" -c copy "$OUT_COMBINED" -threads "$FFMPEG_THREADS" </dev/null >>"${LOG_FILE}" 2>&1

    if [ "$?" -ne "0" ]; then
        echo "  ERROR: (exit code $?) combining videos"
        exit 1
    fi
    echo "  combined video generated: \"$OUT_COMBINED\""
}

process_config "$@"
