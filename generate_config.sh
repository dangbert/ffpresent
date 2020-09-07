#!/bin/sh
# script to create the config file to provide as input to process_config.sh
# (to combine many videos/pictures into one)
# TODO: consider putting the date in list.txt as a comment at the end of the line
#       (also would have to make the comment feature smarter)
#       (just take the substring of the line up to the comment if it exsits)
#       (and maybe also remove whitespace, skip line if the substring is empty, etc)
#

# global constants
OUT_LIST="list.txt"
OUT_CONFIG="project.ffpres"

# interactive mode (user is prompted to type their parameters)
function menu() {
    echo "Running in interactive mode:"
    while ! [ -d "$FOLDER" ]; do
        read -p "Enter source folder path to find media> " FOLDER
    done

    echo -e "\nList of all filetypes in target folder for reference:"
    find "$FOLDER" -type f -name '*.*' | sed 's|.*\.||' | sort -u | tr '\r\n' ' ' && echo ""
    echo -e "****************************************************"

    # TODO: https://www.commandlinefu.com/commands/view/12759/join-the-content-of-a-bash-array-with-commas
    echo -e "\nEnter list of desired extensions separated by spaces: (e.g. \"mov mp4 mts\")"
    read -p "> " EXTENSIONS
    IFS=' ' read -ra EXT_LIST <<< "$EXTENSIONS"

    echo -e "\nSearching for files with the following extensions: ${EXT_LIST[@]}"

    create_list "$FOLDER" "${EXT_LIST[@]}"
}

# generates list.txt (list of filenames matching provided search)
# then generates project.ffpres
# usage:
#   create_list <search_folder> <ext1> <ext2> <ext3> ...
#   create_list "./trip" jpg JPG jpeg mp4 mov
function create_list() {
    if [ -f "$OUT_LIST" ]; then
        #OUT_LIST="$(mktemp -u "list.XXXX.txt")"
        read -p "Overwrite existing file '$OUT_LIST'? (y/n): " -n 1 -r && echo ""
        if [[ ! $REPLY =~ ^[Yy] ]]; then exit 1; else rm -f "$OUT_LIST"; fi
    fi
    if [ -f "$OUT_CONFIG" ]; then
        read -p "Overwrite existing file '$OUT_CONFIG'? (y/n): " -n 1 -r && echo ""
        if [[ ! $REPLY =~ ^[Yy] ]]; then exit 1; else rm -f "$OUT_CONFIG"; fi
    fi

    # build search_str:
    FOLDER="$1"
    EXT_LIST=("${@:2}") # remove first element (the folder path)
    search_str=""       # e.g. ".*\.\(mov\|MOV\|mp4\|MP4\)"
    for i in "${!EXT_LIST[@]}"; do
        ext="${EXT_LIST[$i]}"
        if (( i == 0 )); then
            search_str=".*\.\(${ext}"
        else
            search_str="${search_str}\|${ext}"
        fi
    done
    search_str="${search_str}\)"
    #echo -e "search_str: '$search_str'\n"

    # do the search, and order results by date:
    # TODO: consider putting "# date generated: ..." at the top of the outputted files, etc
    echo -e "\ncreating list: '$OUT_LIST'"...
    # escaping with a \t instead of a comma allows filenames containing a comma
    find "$FOLDER" -type f -regex "${search_str}" -printf "%TY-%Tm-%Td %TT\t%p\0" | sort -z | while read -d $'\0' line
    do
        #local dateStr="$(echo "$line" | cut -d'\t' -f1 | cut -d'.' -f1)" # e.g. '2020-02-27 13:30:04'
        local path="$(echo "$line" | cut -d$'\t' -f2)"    # e.g. './02-oldish/IMG_2635.jpg'
        echo "$(realpath "$path")" >> "$OUT_LIST"
    done
    echo "done!"

    # generate config file as well:
    echo -e "\ncreating config: '$OUT_CONFIG'..."
    echo -e "\tto generate again later run: generate_config.sh -g '$OUT_LIST'"
    create_config "$OUT_LIST" "$OUT_CONFIG"
    echo "done!"
}

# reads a list of paths from file "$1" and outputs a ffpresent config file to path "$2"
# TODO: later do something here with requesting (from user) and storing project settings in file as well
#   (output resolution, video type, duration of each image)
#   (also with a headless way to define these)
#   actually for now just dump good defaults to the file and tell the user they can modify them...
function create_config() {
    local inList="$1"    # input filename
    local outConfig="$2" # filename of detailed output config file
    if [ -f "$outConfig" ]; then
        echo "ERROR: file '$outConfig' already exists"
        exit 1
    fi

    echo "#fileType,width,height,rot,dur,fname" >> "$outConfig"
    while IFS= read -r fname
    do
        # support commented lines here
        # TODO: get it working with leading spaces
        if [[ "$(echo $(echo "$line"))" == \#* ]]; then
            continue
        elif ! [ -f "$fname" ]; then
            echo "ERROR: file '$name' doesn't exist (skipping for now)"
            continue
        fi
        get_all_file_details "$fname" >> "$outConfig"
    done < "$inList"
}

# takes the filename "$1" and returns a string containing the details:
# "file_name,rotation,duration,width,height"
function get_all_file_details() {
    fname="$1"
    rot="$(get_rot "$fname")"
    res="$(get_res "$fname")"
    fileType="$(get_type "$fname")"

    dur="NA" # "00:00:00"
    if [[ "$fileType" != "image" ]]; then
        dur="$(get_dur "$fname")"
    fi
    width=$(cut -d 'x' -f1 <<< $res)
    height=$(cut -d 'x' -f2 <<< $res)

    # TODO: consider putting date modified or created here as well
    #  we put fname last in case it contains a comma
    echo "$fileType,$width,$height,$rot,$dur,$fname"
}

# returns "" if given video is already horizontal
# else returns the number of degrees the video should be rotated
function get_rot() {
    FNAME="$1" # name of file to check
    # get angle that video needs to be rotated ("" if already horizontal)
    rot=`ffprobe -loglevel error -select_streams v:0 -show_entries stream_tags=rotate -of default=nw=1:nk=1 -i "$FNAME" 2>/dev/null | head -n 1`
    echo "$rot"
}

# returns resolution of video "<width>x<height>" (e.g. "1280x720")
# some videos (like "./3---Grand Canyon/entering_park.MTS")
# strangely return 2 lines with the result so we pipe to head
function get_res() {
    FNAME="$1" # name of file to check
    # get angle that video needs to be rotated ("" if already horizontal)
    val=`ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 -i "$FNAME" 2>/dev/null | head -n 1`
    echo "$val"
}

# returns duration of video in string format "HH:MM:SS"
function get_dur() {

    FNAME="$1" # name of file to check
    val=`ffprobe -v error -select_streams v:0 -show_entries stream=duration -of csv=s=x:p=0 -i "$FNAME" 2>/dev/null | head -n 1`
    if [[ "$val" == "N/A" ]]; then
        echo "NA"
    else
        echo "$(date -d @"$val" -u +%H:%M:%S)"
    fi
}

# returns "image" for images, "video" otherwise
# https://superuser.com/a/1338791
# TODO: for now assume anything else is a video (later support audio perhaps)
function get_type() {
    local out="$(ffprobe -v error -select_streams v -show_entries format=format_name -of default=nokey=1:noprint_wrappers=1 "$1" 2>/dev/null)"
    if [[ "$out" == "image2" ]] || [[ "$out" == "png_pipe" ]] ; then
        echo "image"
    else
        echo "video"
    fi
}

# prints usage
function usage() {
    echo -e "==========================================================================================================="
    echo -e "Generates a list of files (ordered by date) by searching a provided folder recusively for desired file extensions."
    echo -e "\nUSAGE:"
    echo -e "\tgenerate_config           # interactive mode (when no args are provided you are prompted to type params)"
    echo -e "\tgenerate_config -g list.txt  # generates '$OUT_CONFIG' based on a provided list of media files"
    echo -e "\tgenerate_config \"<folder>\" <ext1> <ext2> <ext3> <...>"
    echo -e "EXAMPLE:"
    echo -e "\tgenerate_config.sh \"~/Downloads/0.Costa_Rica/\" mov MOV mp4 jpg png"
    echo -e "===========================================================================================================\n"
}

# TODO: use proper flag parsing?
if [ -z `which ffmpeg` ] || [ -z `which ffprobe` ]; then
    echo "ERROR: ffmpeg not installed?" >&2
    exit 1
fi
if [ "$#" == "2" ] && [ "$1" == "-g" ] && [ -f "$2" ]; then
    # adds support for: generate_config.sh -g list.txt
    if [ -f "$OUT_CONFIG" ]; then
        read -p "Overwrite existing file '$OUT_CONFIG'? (y/n): " -n 1 -r && echo ""
        if [[ ! $REPLY =~ ^[Yy] ]]; then exit 1; else rm -f "$OUT_CONFIG"; fi
    fi
    echo -e "\ncreating config: '$OUT_CONFIG'..."
    create_config "$2" "$OUT_CONFIG"
    echo "done!"
elif [ "$#" -gt "1" ]; then
    create_list "$@"
elif [ "$#" == "1" ] && [ -d "$1" ]; then
    usage
    echo -e "List of all filetypes in target folder for reference:"
    FOLDER="$1" && find "$FOLDER" -type f -name '*.*' | sed 's|.*\.||' | sort -u | tr '\r\n' ' '
    echo -e "\n"
    exit 1
else
    # run in interactive mode
    usage
    menu
fi
