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
# TODO: put the planned rotation in the list-detailed.txt?

OUT_FILE=list-detailed.txt

function menu() {
    while ! [ -d "$FOLDER" ]; do
        read -p "Enter source folder path to find videos> " FOLDER
    done

    echo "List of all extension found in target folder:"
    find "$FOLDER" -type f -name '*.*' | sed 's|.*\.||' | sort -u
    # TODO: https://www.commandlinefu.com/commands/view/12759/join-the-content-of-a-bash-array-with-commas
    echo "****************************************************" && echo ""

    echo -e "\nEnter list of desired extensions separated by commas: (e.g. \"mov,mp4,mts\")"
    read -p "> " EXTENSIONS
    IFS=',' read -ra EXT_LIST <<< "$EXTENSIONS"

    echo -e "\nSearching for files with the following extensions:"
    echo "  ${EXT_LIST[@]}" && echo ""

    create_list "$FOLDER" "${EXT_LIST[@]}"
}

# generate list.txt (with details about each video on each line)
# TODO: use proper flag parsing?
function create_list() {
    OUT_FILE="list.txt"
    if [ -f "$OUT_FILE" ]; then
        OUT_FILE="$(mktemp -u list.XXXX.txt)"
    fi
    echo -e "writing results to: \"$OUT_FILE\""

    # build search_str:
    FOLDER="$1"
    EXT_LIST=("${@:2}") # remove first element (the folder path)
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
    tmp_list="$(mktemp -u --tmpdir=/tmp).txt"
    find "$FOLDER" -type f -regex "${search_str}" -printf "%TY-%Tm-%Td %TT,%p\n" | sort -n  >"$tmp_file"
    cat "$tmp_file" | cut -d',' -f2 > "$tmp_list"
    #echo -e "\ncreated temporary file: \"$tmp_list\""

    # iterate over $tmp_list to create a list with more details
    while IFS= read -r fname
    do
        get_all_file_details "$fname" >> "$OUT_FILE"
    done < "$tmp_list"
    rm -f "$tmp_list"

    echo "done!"
    #echo "copy of list (including dates) outputted to: ${tmp_file}"
}

# takes the filename "$1" and returns a string containing the details:
# "file_name,rotation,duration,width,height"
function get_all_file_details() {
    fname="$1"
    rot="$(get_rot "$fname")"
    res="$(get_res "$fname")"
    duration="$(get_dur "$fname")"
    width=$(cut -d 'x' -f1 <<< $res)
    height=$(cut -d 'x' -f2 <<< $res)

    echo "$fname,$rot,$width,$height,$duration"
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
# prints usage
function usage() {
    echo -e "==========================================================================================================="
    echo -e "Generates a list of files (ordered by date) by searching a provided folder recusively for desired file extensions."
    echo -e "\nUSAGE:"
    echo -e "\tgenerate_config   # when no args are provided you are prompted to type params"
    echo -e "\tgenerate_config \"<folder>\" <ext1> <ext2> <ext3> <...>"
    echo -e "EXAMPLE:"
    echo -e "\tEXAMPLE: generate_config.sh \"~/Downloads/0.Costa_Rica/\" mov MOV mp4"
    echo -e "===========================================================================================================\n"
}

if [ "$#" -eq "0" ]; then
    usage
    menu
elif [ "$#" -gt "1" ]; then
    create_list "$@"
elif [ "$#" == "1" ] && [ -d "$1" ]; then
    usage
    echo -e "\nList of all filetypes in target folder for reference:"
    FOLDER="$1" && find "$FOLDER" -type f -name '*.*' | sed 's|.*\.||' | sort -u
    exit 1
fi
