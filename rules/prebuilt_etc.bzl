"""
Copyright (C) 2021 The Android Open Source Project

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""

PrebuiltEtcInfo = provider(
    "Info needed for prebuilt_etc modules",
    fields = {
        "src": "Source file of this prebuilt",
        "sub_dir": "Optional subdirectory to install into",
        "filename": "Optional name for the installed file",
        "installable": "Whether this is directly installable into one of the partitions",
    },
)

def _prebuilt_etc_rule_impl(ctx):
    return [
        PrebuiltEtcInfo(
            src = ctx.file.src,
            sub_dir = ctx.attr.sub_dir,
            filename = ctx.attr.filename,
            installable = ctx.attr.installable,
        ),
    ]

_prebuilt_etc = rule(
    implementation = _prebuilt_etc_rule_impl,
    attrs = {
        "src": attr.label(mandatory = True, allow_single_file = True),
        "sub_dir": attr.string(),
        "filename": attr.string(),
        "installable": attr.bool(default = True),
    },
)

def prebuilt_etc(
        name,
        src,
        sub_dir = None,
        filename = None,
        installable = True,
        **kwargs):
    "Bazel macro to correspond with the prebuilt_etc Soong module."

    _prebuilt_etc(
        name = name,
        src = src,
        sub_dir = sub_dir,
        filename = filename,
        installable = installable,
        **kwargs
    )
