#!/usr/bin/env python3

"""A Python script to copy files from Bazel's dist rule to a user specified dist directory.

READ ME FIRST.

This script is only meant to be executed with `bazel run`. `bazel build <this
script>` doesn't actually copy the files, you'd have to `bazel run` a
copy_to_dist_dir target.

This script copies files from Bazel's output tree into a directory specified by
the user.  It does not check if the dist dir already contains the file, and will
simply overwrite it.

One approach is to wipe the dist dir every time this script runs, but that may
be overly destructive and best left to an explicit rm -rf call outside of this
script.

Another approach is to error out if the file being copied already exist in the dist dir,
or perform some kind of content hash checking.
"""


import sys
import argparse
import os
import glob
from posix import mkdir
import shutil

def files_to_dist():
    # Assume that dist.bzl is in the same package as dist.py
    dist_manifest = os.path.join(os.path.dirname(__file__), "dist_manifest.txt")
    files_to_dist = []
    with open(dist_manifest, "r") as f:
        files_to_dist = [line.strip() for line in f.readlines()]
    return files_to_dist

def copy_files_to_dist_dir(files, dist_dir):
    for src in files:
        if not os.path.isfile(src):
            continue

        src_relpath = src
        src_abspath = os.path.abspath(src)

        dst = os.path.join(dist_dir, src_relpath)
        dst_dirname = os.path.dirname(dst)
        print("[dist] Disting file: " + dst)
        if not os.path.exists(dst_dirname):
            os.makedirs(dst_dirname)

        shutil.copyfile(src_abspath, dst, follow_symlinks=True)

def main():
    parser = argparse.ArgumentParser(description="Dist Bazel output files into a custom directory.")
    parser.add_argument("--dist_dir", required = True, help = "absolute path to the dist dir")
    args = parser.parse_args()
    dist_dir = args.dist_dir

    if not os.path.isabs(dist_dir):
        # BUILD_WORKSPACE_DIRECTORY is the root of the Bazel workspace containing this binary target.
        # https://docs.bazel.build/versions/main/user-manual.html#run
        dist_dir = os.path.join(os.environ.get("BUILD_WORKSPACE_DIRECTORY"), dist_dir)
    print("[dist] selected dist dir: " + dist_dir)

    copy_files_to_dist_dir(files_to_dist(), dist_dir)
    print("[dist] Done.")

if __name__ == "__main__":
    main()
