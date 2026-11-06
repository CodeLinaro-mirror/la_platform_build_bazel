# Copyright 2026 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Starlark macros for exporting symbols from a Windows .def file across Windows, macOS, and Linux."""

load("@rules_cc//cc:cc_binary.bzl", "cc_binary")

def posix_export_files(name, win_def_file, linkshared = False):
    """Generates macOS and Linux linker export files from a Windows .def file.

    Args:
        name: Base name used for the generated export file targets.
        win_def_file: Label of the .def file listing exported symbols.
        linkshared: True when generating exports for a shared library (-shared),
            False when generating exports for an executable.

    Returns:
        A tuple (macos_exp, linux_lds) of generated export file names in the
        caller's package.
    """
    macos_exp = "_" + name + "_macos.exp"
    native.genrule(
        name = "_" + name + "_macos_exports",
        srcs = [win_def_file],
        outs = [macos_exp],
        tools = ["@goldfish_build//rules:gen_linker_exports"],
        cmd = (
            "$(execpath @goldfish_build//rules:gen_linker_exports) --os=macos " +
            "$(execpath " + win_def_file + ") -o \"$@\""
        ),
        target_compatible_with = ["@platforms//os:macos"],
        visibility = ["//visibility:private"],
    )

    linux_lds = "_" + name + "_linux.lds"
    linux_mode_flag = " --linkshared" if linkshared else ""
    native.genrule(
        name = "_" + name + "_linux_exports",
        srcs = [win_def_file],
        outs = [linux_lds],
        tools = ["@goldfish_build//rules:gen_linker_exports"],
        cmd = (
            "$(execpath @goldfish_build//rules:gen_linker_exports) --os=linux" +
            linux_mode_flag + " $(execpath " + win_def_file + ") -o \"$@\""
        ),
        target_compatible_with = ["@platforms//os:linux"],
        visibility = ["//visibility:private"],
    )
    return macos_exp, linux_lds

def cc_exported_shared_library(
        name,
        win_def_file,
        linkopts = None,
        additional_linker_inputs = None,
        visibility = None,
        **kwargs):
    """Creates a shared library exporting only the symbols in win_def_file.

    Uses win_def_file as the single source of truth across Windows (/DEF:),
    macOS (-exported_symbols_list), and Linux (a GNU ld / lld version script
    with EXTERN and 'local: *;').

    Args:
        name: The name of the shared library cc_binary target.
        win_def_file: Label of the .def file listing exported symbols.
        linkopts: Additional linker options for the shared library target.
        additional_linker_inputs: Additional files required at link time.
        visibility: Visibility labels for the shared library target.
        **kwargs: Additional arguments forwarded to cc_binary.
    """
    macos_exp, linux_lds = posix_export_files(
        name,
        win_def_file,
        linkshared = True,
    )
    cc_binary(
        name = name,
        linkshared = True,
        visibility = visibility,
        win_def_file = select({
            "@platforms//os:windows": win_def_file,
            "//conditions:default": None,
        }),
        linkopts = ([] if linkopts == None else linkopts) + select({
            "@platforms//os:macos": [
                "-Wl,-exported_symbols_list,$(execpath :" + macos_exp + ")",
            ],
            "@platforms//os:linux": [
                "-Wl,$(execpath :" + linux_lds + ")",
            ],
            "//conditions:default": [],
        }),
        additional_linker_inputs = (
            [] if additional_linker_inputs == None else additional_linker_inputs
        ) + select({
            "@platforms//os:macos": [":" + macos_exp],
            "@platforms//os:linux": [":" + linux_lds],
            "//conditions:default": [],
        }),
        **kwargs
    )
