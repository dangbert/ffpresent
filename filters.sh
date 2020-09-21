#!/bin/bash
# contains functions for further filtering/sorting a list of files (list.txt)

# this is a tool for sorting files
#
# TODO: move this option to generate_config.sh (where the program will allow you to preview the files (with eog or mpv opened automatically)
#  then you hit <enter> to skip the file (not put it in the list.txt you're generating or <any other key>
# TODO: this is not finished
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
# TODO: this is not finished
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
