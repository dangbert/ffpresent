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
# https://en.wikipedia.org/wiki/List_of_Avid_DNxHD_resolutions
OUT_BITRATE="36M"          # output bitrate (36M, 45M, 75M, 115M, ...) (Mbps)
OUT_SCALE=("1920" "1080")  # output resoulution
OUT_EXT="mov"              # output file extension (don't change this)

SEARCH_TARGET="/run/media/dan/My Passport/MY_MEDIA/video_editing/grandma_engbert/search-target.jpg"

function main() {

    #if [ "$#" -ne 2 ]; then
    #    echo "ERROR expected 2 args, received: $#"
    #    echo "USAGE:"
    #    echo "  ./process_config.sh <config_file> <output_folder>"
    #    echo "  EXAMPLE: ./process_config.sh list-detailed.txt /tmp"
    #    exit 1
    #fi

    if [[ "$#" == "3" && "$1" == "-i" ]]; then
        # prompt user y/n create video off this list or filter it first?

        # global variables needed by process_config
        CONFIG_FILE="$2"
        FOLDER="$3/combined_output"
        OUT_LIST="$(dirname "$FOLDER")/filtered-list.txt"
        FOLDER_INT="$FOLDER/intermediary" # folder to store intermediary files (before the video is created)
        LOG="$(mktemp)"

        if [ -f "$OUT_LIST" ] ; then # OUT_LIST already exists
            echo -e "\nWARNING: file '$OUT_LIST' already exists"
            #echo -e "(it will 

            read -p "Append filtered filenames to existing file? (y/n): " -n 1 -r
            echo ""   # (optional) move to a new line
            if [[ ! $REPLY =~ ^[Yy]$ ]]
            then
                read -p "Delete existing file? (y/n): " -n 1 -r
                echo ""   # (optional) move to a new line
                if [[ ! $REPLY =~ ^[Yy] ]]; then
                    exit 1
                else
                    rm -f "$OUT_LIST"
                fi
            fi
        fi

        # TODO: call with options manually (no $@)
        echo "logging to: $LOG"
        interactive_pics "$@"
    else
        # global variables needed by process_config
        CONFIG_FILE="$1"
        FOLDER="$2/combined_output"
        FOLDER_MOVS="$FOLDER/intermediary" # folder to store converted mov files
        LOG_FILE="$FOLDER/tmp-ffmpeg-log.txt"
        OUT_LIST="$FOLDER/list-combine.txt"

        OUT_COMBINED="$FOLDER/out-combined.mov"

        process_config "$@"
    fi


}

# this is a tool for sorting files
#
# TODO: move this option to generate_config.sh (where the program will allow you to preview the files (with eog or mpv opened automatically)
#  then you hit <enter> to skip the file (not put it in the list.txt you're generating or <any other key>
function interactive_pics() {
    #if [ "$#" -le 2 ]; then
    #    echo "ERROR expected 2 args, received: $#"
    #    echo "USAGE:"
    #    echo "  ./process_config.sh <config_file> <output_folder>"
    #    echo "  EXAMPLE: ./process_config.sh list-detailed.txt /tmp"
    #    exit 1
    #fi



    # manual (prompted review way):  # not finished yet

    # TODO: later add additional flag and dependency to allow the user to specify a picture of someone's fact to use
    #   to automatically use facial recognition to find every picture file from the list that includes this persons face
    # or just use a program that can display both pictures and videos (idk if eog does)


    #{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{
    #### FOR NOW: we do it the manual way:
    #}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

    mkdir -p "$FOLDER_INT"
    # read file with list of paths to picture files
    skipCount=0
    while IFS= read -r line
    do
        # note: value of current line now stored in "$line"
        line="$line"


        # doesn't hurt but:
        #   TODO: better to just check if current line is a valid file path
        #   (as input validation that also allows comments)
        if [[ "$line" == \#* ]]; then
            skipCount=$((skipCount+1))
            continue
            # parse values from line:
            #IFS=',' read -ra ARR <<< "$line"
        fi

        echo -e "current line: '$line'"

        res="$(preview_file "$line")"
        echo "res='$res'"
        if [ "$res" -ne "1" ]; then
            echo -e "skipping pic"
            # skip this video
            continue

        fi
        echo -e "including pic"

        # now i can first write these names to file filtered-list.txt
        echo "$line" >> "$OUT_LIST"

        # then (here in this script for now OR a function below) 
        #  now create sym links (in FOLDER_INT) to all the pictures in order in the OUT_DIR (of a incrementing number format for ffmpeg to use to read in order and combine into a video)


        continue   ##### manual way #####:
        # now preview file
        #eog "$fname" &  # backgrounds the process
        #prevPid="$!"    # pid of background process

        # provide text prompt to user (preview should still be open)
    done < "$CONFIG_FILE"

    echo -e "\ncreated $OUT_LIST"
    echo -e "\nnow run: process_config.sh again"
    exit

    # TODO: prompt user with command they can use to then create a video from this file
    # and offer to run it for them if they hit y

    #FRAME_DUR="3000" # duration (ms) for each frame to be visible in the video

    # TODO: now use the new filtered list to combine all pics in there in order at desired framerate
    # (just do this with one command (soft link list of files to use that are numbered correctly)


    # ORIGINAL PLAN:
    # iterate over each file (display in eog)
    # then user types <enter> to skip file (don't copy it to the intermediary folder)
    #     or <any other key> to select the file for usage

    # then: we combine the remaining list of files to a single video (here in this function with a simple oneliner or something)
    #      TODO: later we can modify process_config to allow pictures to be interleaved within the video (e.g. convert each pic to a 1 second itermediary video or something (and then just call that function from here at the end now that our list is done

}

# previews a provided file and returns (echoes) true or false
# true = user wants to select this file
# false = user wants to skip this file
function preview_file() {
    local fname="$1"   # path to file of interest
    local prompt="$2"  # question prompt
    local PROG="/home/dan/Downloads/projects/ffmpeg-tools/external/facedetect-master/facedetect"
    local TARGET="/run/media/dan/My Passport/MY_MEDIA/video_editing/grandma_engbert/source_library/uncle_tom/incomplete--Brawley fam/MVIMG_20190706_192823_1.jpg"
    local THRESH="60"

    # TODO: identify whether fname is an image or video file (or invalid)
    #  (using ffmpeg maybe or some program)

    # for now we will assume it's an image file
    #eog "$fname"

    # TODO: TODO: for now I will to use facial recognition to tell if grandma appears in the pictures
    #   (and still return true or false)
    #    TODO: later make facial recognition a param option to this function (to specifiy automatic vs manual review)
    #echo "at $fname"

    #"$SEARCH_TARGET"
    ############ latest method: ##################
    PROG="/home/dan/Downloads/projects/ffmpeg-tools/external/face_recognition/my_searcher.py"
    "$PROG" "$fname" --data-dir "$(dirname "$PROG")" -s "$TARGET" --search-threshold "$THRESH" >> "$LOG"


    ############ method 1: ##################
    #"$PROG" "$fname" "$SEARCH_TARGET"
    #./facedetect  "$fname" --data-dir . -s "" --search-threshold "100"

    echo -e "\nrunning: "$PROG" "$fname" --data-dir "$(dirname "$PROG")" -s "$TARGET" --search-threshold "$THRESH"" >> "$LOG"
    "$PROG" "$fname" --data-dir "$(dirname "$PROG")" -s "$TARGET" --search-threshold "$THRESH" >> "$LOG"

    local res="$?"
    #echo "now res='$res'"
    if [ "$res" == "1" ]; then
        echo -e "ERROR: facedetector returned with error code ($res)"
        echo "0"
        exit
    fi

    if [ "$res" == "0" ]; then
        echo "1"
    else
        echo "0"
    fi

    #./facedetect  "/run/media/dan/My Passport/MY_MEDIA/video_editing/grandma_engbert/source_library/uncle_tom/incomplete--Brawley fam/MVIMG_20190706_192823_1.jpg" --data-dir . -s "/run/media/dan/My Passport/MY_MEDIA/video_editing/grandma_engbert/search-target.jpg" --search-threshold "100"

    #echo "1" # TODO: for now
    exit

    # I need to search by face if im going to do this
    #   because there are 8,558 picture files in "/run/media/dan/My Passport/PHOTOS/FAMILY-PHOTOS"
    #   and if i manually filtered through the files
    #     (using my prompt tool that i started below)
    #   and each pic took 3 seconds to review, it would total to: 7.13 hours to review

}

function process_config_usage() {
    echo "ERROR expected 2 args, received: $#"
    echo "USAGE:"
    echo "  ./process_config.sh <config_file> <output_folder>"
    echo "  EXAMPLE: ./process_config.sh list-detailed.txt /tmp"
    exit 1
}

function process_config() {
    if [ "$#" -ne 2 ]; then
        process_config_usage
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
    while IFS= read -r line
    do
        if [[ "$line" == \#* ]]; then
            skipCount=$((skipCount+1))
            continue
        fi
        # TODO: consider adding something like: "  (line 3 of 201)"
        echo "  >>> $line"
        # parse values from line:
        IFS=',' read -ra ARR <<< "$line"
        count=$(awk -F"," '{print NF-1}' <<< "${line}")
        if [ "$count" -ne "3" ]; then
            echo "ERROR: found $count occurences of delimter (expected 3)."
            exit 1
        fi
        fname="${ARR[0]}"; rot="${ARR[1]}"; width="${ARR[2]}"; height="${ARR[3]}"

        ###
        # generate filename (doesn't create file):
        #   TODO: TODO: TODO: maybe use existing path/filename but prepend "CONV--"
        #   or create a new folder and put all the new files in with the same hierachy as before
        #   https://www.cyberciti.biz/faq/bash-get-basename-of-filename-or-directory-name/
        #   https://stackoverflow.com/a/14892459
        newfile="$(mktemp -u --tmpdir="$FOLDER_MOVS").${OUT_EXT}"
        ###
        # flags for conversion: (must store these in an array!) https://stackoverflow.com/a/29175560

        CONV_FLAGS=(
            -t 5   # for images make them into videos of this number of seconds each
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

        # debug with text overlay:
        #${flags[-1]}="${flags[-1]},\
        #drawtext=\"fontfile=/home/dan/.gimp-2.8/fonts/Dangbert.ttf: \
#text='Stack Overflow': fontcolor=white: fontsize=24: box=1: boxcolor=black: \
#x=(w-text_w)/2:y=h-th\""

        flags=("${CONV_FLAGS[@]}")              # copy array of flags

        # check if video is vertical (set flags to rotate and add black bars during re-encoding):
        if ! [ -z "$rot" ] || [ "$height" -gt "$width" ]; then
            flags[-1]="scale=-1:${OUT_SCALE[1]},pad=${OUT_SCALE[0]}:${OUT_SCALE[1]}:(ow-iw)/2:color=Black,${flags[-1]}"
        fi

        # print command to log and re-encode:
        echo "" >>"${LOG_FILE}" && echo "ffmpeg -hide_banner -loglevel warning -y -i "$fname" ${flags[@]} \"${newfile}\" </dev/null >>\"${LOG_FILE}\" 2>&1" >>"${LOG_FILE}"
        # loop 1 is for images (seems like it has to be one of the first flags...)
        # TODO: get this to work for images and videos interleaved...
        # image to video based on https://stackoverflow.com/a/25895709

        ffmpeg -hide_banner -loglevel warning -y -loop 1 -i "$fname" ${flags[@]} "${newfile}" </dev/null >>"${LOG_FILE}" 2>&1
        if [ "$?" -ne "0" ]; then
            echo "ERROR: (exit code $?) converting video: \"$fname\" (aborting early)..."
            echo "  $CMD" && echo "" && exit 1
        fi
        # store the absolute path to this file in "$OUT_LIST"
        # TODO: the \' is not working (try again with the -e below)
        echo -e "file '`realpath "$newfile"`'" >> "$OUT_LIST"
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
    echo "List of videos used to concatenate outputted to: \"$OUT_LIST\""
    echo "*****************:"

    # concatenate videos into one:
    #  (keep in mind that for this step it is critical that all videos being combined
    #    are the exact same encoding, number of audio streams, etc)
    echo "" && echo "Combining videos... in \"$OUT_LIST\"" && echo ""
    echo "" >>"${LOG_FILE}" && echo "ffmpeg -f concat -y -safe 0 -i \"$OUT_LIST\" -c copy \"$OUT_COMBINED\" </dev/null >>\"${LOG_FILE}\" 2>&1" >>"${LOG_FILE}"
    ffmpeg -f concat -y -safe 0 -i "$OUT_LIST" -c copy "$OUT_COMBINED" </dev/null >>"${LOG_FILE}" 2>&1

    if [ "$?" -ne "0" ]; then
        echo "  ERROR: (exit code $?) combining videos"
        exit 1
    fi
    echo "  combined video generated: \"$OUT_COMBINED\""
}

#process_config "$@"
main "$@"
