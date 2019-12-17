#!/bin/sh
# script to create the config file to provide as input to process_config.sh
# (to combine many videos into one)
# TODO: write files to the specified folder...
# TODO: consider putting the date in list.txt as a comment at the end of the line
#       (also would have to make the comment feature smarter)
#       (just take the substring of the line up to the comment if it exsits)
#       (and maybe also remove whitespace, skip line if the substring is empty, etc)
# TODO: consider putting "# date generated: ..." at the top of the outputted files, etc
#       (and perhaps list the command that was used to create it)
#
#
# TODO: consider just outputting the detailed list and skipping the list.txt step...
# TODO: put the planned rotation int the list-detailed.txt?

OUT_FILE=list-detailed.txt
# outputs a text file with the metadata about each file to be combined
# input: $1 (name of file listing filenames seperated by newlines)
function generate_config() {
    LIST_FILE="$2"

    if [ -f "$OUT_FILE" ]; then
        echo "output file \"$OUT_FILE\" already exists. Delete and try again."
        exit 1
    fi

    skipCount=0
    # iterate over file names in $LIST_FILE
    echo "Creating: \"$OUT_FILE\"..."
    while IFS= read -r fname
    do
        if [[ "$fname" == \#* ]]; then
            skipCount=$((skipCount+1))
            continue
        fi
        #echo "fname=$fname"
        rot="$(get_rot "$fname")"
        res="$(get_res "$fname")"
        duration="$(get_dur "$fname")"
        width=$(cut -d 'x' -f1 <<< $res)
        height=$(cut -d 'x' -f2 <<< $res)

        # add this to OUT_FILE
        echo "$fname,$rot,$width,$height,$duration" >> $OUT_FILE
    done < "$LIST_FILE"

    if [ "$skipCount" -gt "0" ]; then
        echo "Note: skipped $skipCount commented line(s) in \"$LIST_FILE\""
    fi

    echo "" && echo "Created: \"$OUT_FILE\""
}

# returns "" if given video is already horizontal
# else returns the number of degrees the video should be rotated
function get_rot() {
    FNAME="$1" # name of file to check
    # get angle that video needs to be rotated ("" if already horizontal)
    rot=`ffprobe -loglevel error -select_streams v:0 -show_entries stream_tags=rotate -of default=nw=1:nk=1 -i "$FNAME" | head -n 1`
    echo "$rot"
}

# returns resolution of video "<width>x<height>" (e.g. "1280x720")
# some videos (like "./3---Grand Canyon/entering_park.MTS")
# strangely return 2 lines with the result so we pipe to head
function get_res() {
    FNAME="$1" # name of file to check
    # get angle that video needs to be rotated ("" if already horizontal)
    val=`ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 -i "$FNAME" | head -n 1`
    echo "$val"
}

# returns duration of video in string format "HH:MM:SS"
function get_dur() {
    FNAME="$1" # name of file to check
    val=`ffprobe -v error -select_streams v:0 -show_entries stream=duration -of csv=s=x:p=0 -i "$FNAME" | head -n 1`
    echo "$(date -d @"$val" -u +%H:%M:%S)"
}

# generate list.txt
# TODO: use proper flag parsing?
# TODO: have this program have text menus with options and prompt you to type the options...
# but keep the main menu program as a separate file from the rest
#  (but have a good API for the core funcitonality scripts)
# also have it use your provided folder to give you a list of filenames within to choose from
# usage:
# ./generate_config -l <folder> <ext1> <ext2> <ext3>
# ./generate_config.sh -l "/run/media/dan/My Passport/PHOTOS/0.TRIPS/COSTA_CALI-2019/0.Costa_Rica/" mov MOV mp4
function create_list() {
    OUT_FILE="list.txt"
    IGNORE_CASE=1 # set to 1 to ignore case when searching file extensions

    #ARGS=( "$@" )
    FOLDER=$2
    echo "FOLDER=$FOLDER"
    EXT_LIST=("${@:3}") # remove first two elements ($1 is "-l")

    if [ -f "$OUT_FILE" ]; then
        echo "output file \"$OUT_FILE\" already exists. Delete and try again."
        exit 1
    fi

    echo "List of all filetypes in target folder for reference:"
    find "$FOLDER" -type f -name '*.*' | sed 's|.*\.||' | sort -u
    echo "****************************************************" && echo ""
    echo "Searching for files with the following extensions:"
    echo "  ${EXT_LIST[@]}" && echo ""

    #find /path/to/folder -type f -regex ".*\.\(mov\|MOV\|mp4\|MP4\)")
    search_str="" # ".*\.\(mov\|MOV\|mp4\|MP4\)"
    for i in "${!EXT_LIST[@]}"; do
        ext="${EXT_LIST[$i]}"
        if (( i == 0 )); then
            search_str=".*\.\(${ext}"
        else
            search_str="${search_str}\|${ext}"
        fi
    done
    search_str="${search_str}\)"
    #echo "search_str: $search_str" && echo ""

    # do the search, and order results by date
    tmp_file="$(mktemp -u --tmpdir=/tmp).txt"
    find "$FOLDER" -type f -regex "${search_str}" -printf "%TY-%Tm-%Td %TT,%p\n" | sort -n  >$tmp_file
    cat "$tmp_file" | cut -d',' -f2 > $OUT_FILE
    echo "list of matching files outputted to: \"${OUT_FILE}\""
    echo "copy of list (including dates) outputted to: ${tmp_file}"
}

# prints usage
function usage() {
    echo -e "\nUSAGE:"
    echo "  1. generate a list of files (ordered by date) by searching a provided folder recusively for desired file extensions)"
    echo "      generate_config -l \"<folder>\" <ext1> <ext2> <ext3> <...>"
    echo "      EXAMPLE: generate_config.sh -l \"/run/media/dan/My Passport/PHOTOS/0.TRIPS/COSTA_CALI-2019/0.Costa_Rica/\" mov MOV mp4"
    echo ""

    echo "  2. process a list of files (one per line) to create the config file \"${OUT_FILE}\" for use with ./process_config.sh"
    echo "      generate_config -g <list_file>"
    echo "      EXAMPLE: generate_config -g list.txt"
    #if [ "$#" -eq "1" ] && [ "$1" -eq "1"]; then
    #    exit 1
    #fi
}

#echo "num args = $#"
# check if $1 == "-l" and call create_list:
if [ "$1" == "-l" ]; then
    if [ "$#" -eq "2" ]; then
        usage
        echo -e "\nList of all filetypes in target folder for reference:"
        FOLDER="$2" && find "$FOLDER" -type f -name '*.*' | sed 's|.*\.||' | sort -u
        exit 1
    elif [ "$#" -gt "2" ]; then
        # TODO: test minimum $# required
        create_list "$@"
    fi
# otherwise call generate_config():
elif [ "$1" == "-g" ] && [ "$#" == "2" ]; then
    generate_config "$@"
    exit 0
else
    usage
    exit 1
fi
