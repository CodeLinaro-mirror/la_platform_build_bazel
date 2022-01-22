#!/usr/bin/env python3
#
# Copyright (C) 2021 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Provides useful diff information for build artifacts.

Uses collected build artifacts from two separate build invocations to
compare output artifacts of these builds and/or the commands executed
to generate them.

See the directory-level README for information about full usage, including
the collection step: a preparatory step required before invocation of this
tool.

Use `difftool.py --help` for full usage information of this tool.

Example Usage:
  ./difftool.py [left_dir] [left_output_file] [right_dir] [right_output_file]

Difftool will compare [left_dir]/[left_output_file] and
[right_dir]/[right_output_file] and provide its best insightful analysis on the
differences between these files. The content and depth of this analysis depends
on the types of these files, and also on Difftool"s verbosity mode. Difftool
may also use command data present in the left and right directories as part of
its analysis.
"""

import argparse
import os
import pathlib
import subprocess
import sys


_COLLECTION_INFO_FILENAME = "collection_info"


def collect_commands(ninja_file_path, output_file_path):
  """Returns a list of all command lines required to build the file at given
  output_file_path_string, as described by the ninja file present at
  ninja_file_path_string."""

  ninja_tool_path = pathlib.Path(
      "prebuilts/build-tools/linux-x86/bin/ninja").resolve()
  wd = os.getcwd()
  os.chdir(ninja_file_path.parent.absolute())
  result = subprocess.check_output([str(ninja_tool_path),
                                    "-f", ninja_file_path.name,
                                    "-t", "commands",
                                    str(output_file_path)]).decode("utf-8")
  os.chdir(wd)
  return result


def file_differences(left_path, right_path):
  """Returns a list of strings describing differences between the two given files.
  Returns the empty list if these files are deemed "similar enough"."""

  errors = []
  result = subprocess.run(["diff", str(left_path), str(right_path)],
                          check=False, capture_output=True, encoding="utf-8")
  if result.returncode != 0:
    errors += [result.stdout]
  return errors


def parse_collection_info(info_file_path):
  if not info_file_path.is_file():
    raise Exception("Expected file %s was not found. " +
                    "Did you run collect.py for this " +
                    "directory?" % info_file_path)

  ninja_path = pathlib.Path(info_file_path.read_text())
  return ninja_path


def main():
  parser = argparse.ArgumentParser(description="")
  parser.add_argument("--mode", choices=["verify", "rich"], default="verify",
                      help="The difftool mode. This will control the " +
                      "verbosity and depth of the analysis done.")
  parser.add_argument("left_dir",
                      help="the 'left' directory to compare build outputs " +
                      "from. This must be the target of an invocation of " +
                      "collect.py.")
  parser.add_argument("left_output_file",
                      help="the output file (relative to execution root) for " +
                      "the 'left' build invocation.")
  parser.add_argument("right_dir",
                      help="the 'right' directory to compare build outputs " +
                      "from. This must be the target of an invocation of " +
                      "collect.py.")
  parser.add_argument("right_output_file",
                      help="the output file (relative to execution root) " +
                      "for the 'right' build invocation.")
  args = parser.parse_args()

  mode = args.mode

  left_path = pathlib.Path(args.left_dir).joinpath(args.left_output_file)
  right_path = pathlib.Path(args.right_dir).joinpath(args.right_output_file)
  if not left_path.is_file():
    raise RuntimeError("Expected file %s was not found. " % left_path)
  if not right_path.is_file():
    raise RuntimeError("Expected file %s was not found. " % right_path)

  left_diffinfo = pathlib.Path(args.left_dir).joinpath(
      _COLLECTION_INFO_FILENAME)
  right_diffinfo = pathlib.Path(args.right_dir).joinpath(
      _COLLECTION_INFO_FILENAME)

  left_ninja_path = pathlib.Path(args.left_dir).joinpath(
      parse_collection_info(left_diffinfo))
  right_ninja_path = pathlib.Path(args.right_dir).joinpath(
      parse_collection_info(right_diffinfo))

  file_diff_errors = file_differences(left_path, right_path)

  if file_diff_errors:
    for err in file_diff_errors:
      print(err)
    if mode == "rich":
      print("======== ACTION COMPARISON: ========")
      print("=== LEFT:\n")
      left_command = collect_commands(left_ninja_path, args.left_output_file)
      print(left_command.splitlines()[-1])
      print()
      print("=== RIGHT:\n")
      right_command = collect_commands(right_ninja_path, args.right_output_file)
      print(right_command.splitlines()[-1])
      print()
    sys.exit(1)
  sys.exit(0)


if __name__ == "__main__":
  main()
