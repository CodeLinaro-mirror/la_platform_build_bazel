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

load("//build/bazel/product_variables:constants.bzl", "constants")

_bionic_targets = ["//bionic/libc", "//bionic/libdl", "//bionic/libm"]
_static_bionic_targets = ["//bionic/libc:libc_bp2build_cc_library_static", "//bionic/libdl:libdl_bp2build_cc_library_static", "//bionic/libm:libm_bp2build_cc_library_static"]

# The default system_dynamic_deps value for cc libraries. This value should be
# used if no value for system_dynamic_deps is specified.
system_dynamic_deps_defaults = select({
    constants.ArchVariantToConstraints["linux_bionic"]: _bionic_targets,
    constants.ArchVariantToConstraints["android"]: _bionic_targets,
    "//conditions:default": [],
})

system_static_deps_defaults = select({
    constants.ArchVariantToConstraints["linux_bionic"]: _static_bionic_targets,
    constants.ArchVariantToConstraints["android"]: _static_bionic_targets,
    "//conditions:default": [],
})

def add_lists_defaulting_to_none(*args):
    """Adds multiple lists, but is well behaved with a `None` default."""
    combined = None
    for arg in args:
        if arg != None:
            if combined == None:
                combined = []
            combined += arg

    return combined

# By default, crtbegin/crtend linking is enabled for shared libraries and cc_binary.
def disable_crt_link(features):
    return features + ["-link_crt"]
