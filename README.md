# FFMPEG Tools for Combining a List of Videos Together

### How to combine videos (using the scripts):
1. Create file `list.txt` where each line contains a single filename:
````bash
# generate list.txt:
./generate_config -l "<folder_with_videos>" <ext1> <ext2> <ext3> <...>
# example command:
./generate_config.sh -l "/media/dan/My Passport/CALI/" mov MOV mp4 MP4
````
  * then go through list.txt and delete any lines containing files you don't want combined, and reorder the files as desired.  You can also comment out a line by starting the line with '#'.
  * (videos will be combined later in the order they appear in this file).

2. Generate `list-detailed.txt`:
````bash
./generate_config.sh -g list.txt
````
  * feel free to delete / reorder / comment out lines (with '#') after this step as well.

3. Now combine all the videos:
````bash
# combine videos:
./process_config.sh <config_file> <output_folder>
# example command:
./process_config.sh list-detailed.txt ~/Downloads
````
  * (lines starting with '#' will be ignored)
  * the combined video `out-combined.mov` and the file `list-combine.txt` will be generated.
    * this txt file can be used to regenerate the final video as desired (no comments supported though)

---
### Known limitations:
* file names containing a comma will mess up the scripts.
* I need to thoroughly test this on a diverse set of videos of different formats/resolutions...

---
### Ideas:
* TODO: add ability for config file to be compatible with images later
  * (defaults to showing each image for X seconds, unless specified as an extra option on the line.
* could first combine everything in the directory (all images and videos, etc), and use ffmpeg to overlay a unique ID for each (and their filename), and the current timestamp relative to the start of that file.
  * Then watch that video one time, and edit the file list as you go to comment out the stuff you don't want.
  * Then lastly regenerate the final video using the modified config/list file.
  * Then simpy use another program to underlay music as desired.
  * (with this system you could do some great video editing with any laptop!)
* add option to blend in a list of music files
  * adjust audio to max during for image portions
  * and use an optional flag in the video config file to specify if the audio there is "important" (so it knows to lower the music to say 20% audio there)
    * (and blend the volume changes in audio during transitions)

---
### Useful Commands to know:
* get list of all file extensions inside a folder: [reference](https://stackoverflow.com/a/4998326)
````bash
find . -type f -name '*.*' | sed 's|.*\.||' | sort -u
````

* list all files in order by date:
````bash
find -printf "%TY-%Tm-%Td %TT,%p\n" | sort -n | cut -d',' -f 2
````

* get all files matching a list of extensions: [reference](https://stackoverflow.com/a/2622857)
````bash
find /path/to -type f -regex ".*\.\(jpg\|gif\|png\|jpeg\)"
````
