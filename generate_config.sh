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

# TODO: give the user the list of extensions while its running so they can choose from them while it's running (if they don't provide any)...
# TODO: I should be able to run just one command and get an outputted video

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
        # TODO: also put the video duration as a field for reference...
        #echo "fname=$fname"
        rot="$(get_rot "$fname")"
        res="$(get_res "$fname")"
        width=$(cut -d 'x' -f1 <<< $res)
        height=$(cut -d 'x' -f2 <<< $res)

        # add this to OUT_FILE
        echo "$fname,$rot,$width,$height" >> $OUT_FILE
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
    rot=`ffprobe -loglevel error -select_streams v:0 -show_entries stream_tags=rotate -of default=nw=1:nk=1 -i "$FNAME"`

    echo $rot
}

# returns resolution of video "<width>x<height>" (e.g. "1280x720")
function get_res() {
    FNAME="$1" # name of file to check
    # get angle that video needs to be rotated ("" if already horizontal)
    val=`ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 -i "$FNAME"`
    echo $val
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
    # TODO: allow EXT_LIST to be empty (then just print the folders extensions)
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

    # TODO: also automatically create list-detailed.txt at this point...
}

#echo "num args = $#"
# check if $1 == "-l" and call create_list:
if [ "$1" == "-l" ] && [ "$#" -gt "2" ]; then
    #^^ # TODO: test minimum $# required
    create_list "$@"
# otherwise call generate_config():
elif [ "$1" == "-g" ] && [ "$#" == "2" ]; then
    generate_config "$@"
else
    # example filenames (which are the correct ones)
    res="`find . -type f -name '*.*' | sed 's|.*\.||' | sort -u | tr '\n' ' '`"
    #if [ "$res" -z ]; then
    #    res="mov MOV mp4"
    #    #$2="./" # TODO prevent './~/.dan'
    #fi

    echo "USAGE:"
    echo "  1. generate a list of files (ordered by date) by searching a provided folder recusively for desired file extensions"
    echo "      ./generate_config -l \"<folder>\" <ext1> <ext2> <ext3> <...>"
    echo "      EXAMPLE: ./generate_config.sh -l '$2' $res"
    #echo "      EXAMPLE: ./generate_config.sh -l '$2' $(if [ "$res" -z $res) $res"
    #echo "      EXAMPLE: ./generate_config.sh -l \"/run/media/dan/My Passport/PHOTOS/0.TRIPS/COSTA_CALI-2019/0.Costa_Rica/\" mov MOV mp4"
    echo ""

    echo "  2. process a list of files (one per line) to create the config file \"${OUT_FILE}\" for use with ./process_config.sh"
    echo "      ./generate_config -g <list_file>"
    echo "      EXAMPLE: ./generate_config -g list.txt"
    exit 1
fi
