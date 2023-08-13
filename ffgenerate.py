#!/usr/bin/env python3
import os
import sys
from ffpresent import run_cmd

# Define the run_cmd() function here
# Make sure it's implemented and imported correctly


def get_rot(fname):
    rot = run_cmd(
        f'ffprobe -loglevel error -select_streams v:0 -show_entries stream_tags=rotate -of default=nw=1:nk=1 -i "{fname}" 2>/dev/null | head -n 1',
        exit_on_fail=False,
        print_on_fail=False,
    )
    return rot.stdout.strip()


def get_res(fname):
    val = run_cmd(
        f'ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 -i "{fname}" 2>/dev/null | head -n 1',
        exit_on_fail=False,
        print_on_fail=False,
    )
    return val.stdout.strip()


def get_dur(fname):
    val = run_cmd(
        f'ffprobe -v error -select_streams v:0 -show_entries stream=duration -of csv=s=x:p=0 -i "{fname}" 2>/dev/null | head -n 1',
        exit_on_fail=False,
        print_on_fail=False,
    )
    if val.stdout.strip() == "N/A":
        return "NA"
    else:
        return run_cmd(
            f'date -d "@{val.stdout.strip()}" -u +%H:%M:%S',
            exit_on_fail=False,
            print_on_fail=False,
        ).stdout.strip()


def get_type(fname):
    out = run_cmd(
        f'ffprobe -v error -select_streams v -show_entries format=format_name -of default=nokey=1:noprint_wrappers=1 "{fname}" 2>/dev/null',
        exit_on_fail=False,
        print_on_fail=False,
    )
    if out.stdout.strip() == "image2" or out.stdout.strip() == "png_pipe":
        return "image"
    else:
        return "video"


def create_config(in_list, out_config):
    with open(in_list, "r") as file:
        lines = file.readlines()

    with open(out_config, "w") as file:
        file.write("#fileType,width,height,rot,dur,fname\n")
        for line in lines:
            line = line.strip()
            if line.startswith("#") or not os.path.isfile(line):
                continue
            file_type = get_type(line)
            rotation = get_rot(line)
            resolution = get_res(line)
            duration = "NA" if file_type == "image" else get_dur(line)
            width, height = resolution.split("x")
            file.write(f"{file_type},{width},{height},{rotation},{duration},{line}\n")


def main():
    out_list = "list.txt"
    out_config = "project.ffpres"

    if len(sys.argv) == 3 and sys.argv[1] == "-g" and os.path.isfile(sys.argv[2]):
        if os.path.isfile(out_config):
            response = input(f"Overwrite existing file '{out_config}'? (y/n): ")
            if response.lower() != "y":
                sys.exit(1)
            else:
                os.remove(out_config)
        print(f"\ncreating config: '{out_config}'...")
        create_config(sys.argv[2], out_config)
        print("done!")
    elif len(sys.argv) > 1:
        create_list(sys.argv)
    elif len(sys.argv) == 2 and os.path.isdir(sys.argv[1]):
        print("usage information here")
        print("\nList of all filetypes in target folder for reference:")
        folder = sys.argv[1]
        extensions = run_cmd(
            f'find "{folder}" -type f -name "*.*" | sed "s|.*\.||" | sort -u | tr "\r\n" " "',
            exit_on_fail=False,
            print_on_fail=False,
        ).stdout.strip()
        print(extensions)
        print("\n")
        sys.exit(1)
    else:
        print("interactive mode here")


if __name__ == "__main__":
    main()
