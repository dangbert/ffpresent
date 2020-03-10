# FFMPEG Tools for Combining a List of Videos Together

This tools works on almost any images/videos regardless of their codecs.
* It converts everything to the same codec (video: dnxhd, audio: pcm_s16le) before combining into the final video.
  * (I selected these output codecs because they always works with the Davinci Resolve video editing software).

### How to combine videos (using the scripts):
1. Create config file `project.ffpres`
  * (defines which pictures/videos appear in the combined video and in what order)

````bash
# generate list.txt and project.ffpres:
./generate_config.sh  # run with no args and follow the prompts
# or run with args:
#./generate_config "<folder_with_videos>" <ext1> <ext2> <ext3> <...>
./generate_config.sh "/media/dan/My Passport/CALI/" mov MOV mp4 MP4 jpg
#
# if you have a list of filenames you can also generate project.ffpres with:
./generate_config.sh -g list.txt
````
  * then go through `project.ffpres` and delete any lines containing files you don't want combined, and reorder the files as desired.  You can also comment out a line by starting the line with '#'.
  * (videos will be combined later in the order they appear in this file).

2. Generate the combined video from the project config:
````bash
./process_config.sh project.ffpres <output_dir>
./process_config.sh project.ffpres .
````
* the combined video `out-combined.mov` and the file `combine-list.txt` will be generated in the folder `combined_output/` within the provided `output_dir`

---
### Known limitations:
* file names containing a comma will mess up the scripts?
* file names containing an apostrophe will mess up the combination process (I will fix this soon)

---
### Future Ideas:
* add option to blend in a list of music files
  * adjust audio to max during for image portions
  * and use an optional flag in the video config file to specify if the audio there is "important" (so it knows to lower the music to say 20% audio there)
    * (and blend the volume changes in audio during transitions)

---
### ffmpeg notes:
* [filtergraph defined](http://ffmpeg.org/ffmpeg-filters.html#Filtergraph-description) (read definition/options for each filter to understand):
  * [scale filter](https://ffmpeg.org/ffmpeg-filters.html#scale-1)
  * [pad filter](https://ffmpeg.org/ffmpeg-filters.html#pad-1)

* [useful filters to consider in future](https://ffmpeg.org/ffmpeg-filters.html):
  * [afade](https://ffmpeg.org/ffmpeg-filters.html#afade-1): apply fad-in/out effect to input audio
  * [apad](https://ffmpeg.org/ffmpeg-filters.html#apad): pad the end of an audio stream with silence
  * [aresample](https://ffmpeg.org/ffmpeg-filters.html#aresample-1): stretch/squeeze the audio data to make it match the timestamps or to inject silence / cut out audio to make it match the timestamps

* [view the time_base of files](https://video.stackexchange.com/a/19238) (this is important):
  * `ls *.mov | xargs -L 1 ffprobe -select_streams a -show_entries stream=time_base -of compact=p=0 2>/dev/null| grep -i "time_base"`
  * [what is a timebase?](https://stackoverflow.com/a/43337235)
    - (a defined unit of time to serve as a unit representing one tick of a clock)
    -  PTS (Presentation Time Stamps) are denominated in terms of this timebase.
    - "tbn" (in ffmpeg readout) = Timescale = 1 / timebase

* working example for converting all vertical videos to horizontal with padding:
````bash
ffmpeg -hide_banner -y -i iphone/VER_2.MOV -c:v dnxhd -vf "scale=-1:1080,pad=1920:1080:(ow-iw)/2:color=AliceBlue,fps=30000/1001,format=yuv422p" -b:v 45M -c:a pcm_s16le /tmp/converted_vids/iphone_ver2.mov
````

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
