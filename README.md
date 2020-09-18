# ffpresent
This commandline tool combines videos/images of arbitrary formats/resolutions into a single video.

### How it works:
* Uses ffmpeg to convert all desired images/videos into individual videos of the same format, and then merges everything into a single video (see advanced usage to specify the output format), and adds padding as needed so the final video is 1920x1080 (allowing you to combine videos of different resolutions).
  * (I selected these output codecs because they always works with the Davinci Resolve video editing software).

### How to use:
1. Create the config file `project.ffpres`:
````bash
# run with no arguments, and follow the interactive prompts:
./ffgenerate.sh
````

  * Note that `project.ffpres` defines a list of pictures/video files to be combined in the order they appear in the file (initially ordered by increasing date).
    * After generating this file you can remove files from the list by adding a `#` symbol to the start of a line or by deleting the line entirely.
    * for image files, you can optionally edit the duration field from `NA` to a number like `5` or `1.2` to set the duration the image will be shown for in the outputted video.  If you don't change this value, the default will be used (as defined by `IMG_DUR` at the top of `ffpresent.sh`).

2. Now generate the combined video defined by `project.ffpres`:
````bash
./ffpresent.sh project.ffpres .
# the program expects 2 arguments of the form:
./ffpresent.sh /path/to/project.ffpres /path/to/desired/output/dir
````

* after running, the combined video `out-combined.mp4` will appear in the folder `combined_output/` within the provided `output_dir`
  * you can also view `log-ffmpeg.txt` in the output directory to troubleshoot if anything went wrong.

#### Advanced usage:
* choose your desired output video format: `mp4`, `mov`, `webm` are supported (default is `mp4`)
````bash
# specify the desired output format (mp4, mov, and webm)
./ffpresent.sh project.ffpres . --mp4
./ffpresent.sh project.ffpres . --mov
./ffpresent.sh project.ffpres . --webm
````

  * `mov` (video codec: dnxhd, audio: pcm_s16le) will be higher quality, but the video filesize will be much larger.  (However this format works well with [Davinci Resolve](https://www.blackmagicdesign.com/products/davinciresolve/) for video editing).


* other ways to generate `project.ffpres`:
````bash
# run with arguments instead of interactive mode:
./ffgenerate.sh "<folder_with_videos>" <ext1> <ext2> <ext3> <...>
# for example:
./ffgenerate.sh "/media/dan/My Passport/CALI/" mov MOV mp4 MP4 jpg
#
# or if you have a list of filenames (one per line) you can also generate project.ffpres with:
./ffgenerate.sh -g list.txt
````

---
### Known limitations:
* Note that drives formatted with the FAT32 filesystem dont't support storing mp4 files above 4GB.  This can lead to the error "av_interleaved_write_frame() file too large" [more info](https://stackoverflow.com/q/29179624).
* file names containing a comma will mess up the scripts?
* file names containing an apostrophe will mess up the combination process (I will fix this soon)
* The script is kind of slow (best to leave running overnight when combining many videos).  In the future I will experiment further with parallel processing.

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

* [replacing a video's audio with a provided audio file](https://superuser.com/a/277667 ):
````bash
# (also seemed to drastically lower the file size of my slideshow video without much noticeable quality drop):
fmpeg -i combined_output/out-combined.mov -i ../source_music/combined_music/combined-music.mp3 -map 0:v:0 -map 1:a:0 -shortest  combined_output/v4-with_music.mov
````

* convert mp3 files to wav for Davinci Resolve:
````bash
ls *.mp3 | xargs -L 1 -I@ bash -c "ffmpeg -i \"@\" \"`dirname @`/wav/@.wav\""
````

* listing files:
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
