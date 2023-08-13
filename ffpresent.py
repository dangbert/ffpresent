#!/usr/bin/env python3
import os
import argparse


def main():
    parser = argparse.ArgumentParser(
        description="Convert and combine videos using ffmpeg."
    )
    parser.add_argument("config_file", help="Path to the config file.")
    parser.add_argument("output_folder", help="Path to the output folder.")
    parser.add_argument("--mov", action="store_true", help="Convert to .mov format.")
    parser.add_argument("--mp4", action="store_true", help="Convert to .mp4 format.")
    parser.add_argument("--webm", action="store_true", help="Convert to .webm format.")
    args = parser.parse_args()

    if not any([args.mov, args.mp4, args.webm]):
        args.mp4 = True  # Default to .mp4 format

    config_file = args.config_file
    output_folder = args.output_folder

    if not os.path.isfile(config_file):
        print("ERROR: Config file not found.")
        return

    try:
        os.makedirs(output_folder, exist_ok=True)
        folder_inter = os.path.join(output_folder, "intermediary")
        os.makedirs(folder_inter, exist_ok=True)
    except Exception as e:
        print(f"ERROR creating folders: {e}")
        return

    specific_flags = mp4_flags  # Assume mp4 format as default
    if args.mov:
        specific_flags = mov_flags
    elif args.webm:
        specific_flags = webm_flags

    # Rest of your script logic here
    # Process the config file line by line, converting videos/images as needed
    # Combine videos using ffmpeg as specified in your script
    # Handle errors and print appropriate messages


def run_cmd(
    cmd: str,
    exit_on_fail: bool = True,
    print_on_fail: bool = True,
    verbose: bool = False,
    dry_run: bool = False,
    custom_error_msg: Optional[str] = None,
) -> Tuple[int, str]:
    """Run a shell command, returning the exitcode."""
    if verbose or dry_run:
        print(f"\n{'running' if not dry_run else 'would run'} command:")
        print(cmd)
    if dry_run:
        return 0, "(dry run, command not ran)"

    # res = subprocess.run(cmd, stdout=subprocess.PIPE, cwd=cwd)
    exit_code, output = subprocess.getstatusoutput(cmd)

    # exitCode = os.system(cmd)
    if exit_code != 0:
        if print_on_fail:
            print_cmd_error(exit_code, output, cmd=cmd)
        if custom_error_msg is not None:
            print("\n", custom_error_msg)
        if exit_on_fail:
            exit(exit_code)
    return exit_code, output


def run_cmd_with_stream(
    cmd: List[str],
    exit_on_fail: bool = True,
    print_on_fail: bool = True,
    verbose: bool = False,
    dry_run: bool = False,
    custom_error_msg: Optional[str] = None,
    stream: bool = True,
) -> Tuple[int, str]:
    """Run a shell command, streaming the output as it happens, returning the exitcode."""
    if verbose or dry_run:
        print(f"\n{'running' if not dry_run else 'would run'} command:")
        print(cmd)
    if dry_run:
        return

    # doesn't appear to actually stream:
    # res = subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)
    # exit_code = res.returncode
    # output = res.stdout
    output = ""
    process = subprocess.Popen(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True
    )
    # for c in iter(lambda: process.stdout.read(1), b""):
    #    sys.stdout.buffer.write(c)
    #    output += c
    output = ""
    while True:
        line = process.stdout.readline()
        if line == "":
            break
        output += line
        if stream:
            sys.stdout.write(line)
    sys.stdout.flush()

    exit_code = process.wait()
    if exit_code != 0:
        if print_on_fail:
            print_cmd_error(exit_code, output, cmd=" ".join(cmd))
        if custom_error_msg is not None:
            print("\n", custom_error_msg)
        if exit_on_fail:
            exit(exit_code)
    return exit_code, output


if __name__ == "__main__":
    main()
