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

load(":cc_library_common.bzl", "add_lists_defaulting_to_none", "disable_crt_link")
load(":cc_library_shared.bzl", "CcSharedLibraryInfo", "CcTocInfo", "cc_library_shared")
load(":cc_library_static.bzl", "CcStaticLibraryInfo", "cc_library_static")

def cc_library(
        name,
        # attributes for both targets
        srcs = [],
        srcs_c = [],
        srcs_as = [],
        copts = [],
        cppflags = [],
        conlyflags = [],
        asflags = [],
        hdrs = [],
        implementation_deps = [],
        deps = [],
        whole_archive_deps = [],
        dynamic_deps = [],
        implementation_dynamic_deps = [],
        system_dynamic_deps = None,
        export_includes = [],
        export_system_includes = [],
        local_includes = [],
        absolute_includes = [],
        linkopts = [],
        rtti = False,
        link_crt = True,
        use_libcrt = True,
        stl = "",
        cpp_std = "",
        c_std = "",
        strip = {},
        shared = {},  # attributes for the shared target
        static = {},  # attributes for the static target
        additional_linker_inputs = None,
        **kwargs):
    static_name = name + "_bp2build_cc_library_static"
    shared_name = name + "_bp2build_cc_library_shared"

    features = []
    if "features" in kwargs:
        features += kwargs["features"]
    if not use_libcrt:
        features += ["-use_libcrt"]

    # Force crtbegin and crtend linking unless explicitly disabled (i.e. bionic
    # libraries do this)
    if link_crt == False:
        features = disable_crt_link(features)

    # The static version of the library.
    cc_library_static(
        name = static_name,
        hdrs = hdrs,
        srcs = srcs + static.get("srcs", []),
        srcs_c = srcs_c + static.get("srcs_c", []),
        srcs_as = srcs_as + static.get("srcs_as", []),
        copts = copts + static.get("copts", []),
        cppflags = cppflags,
        conlyflags = conlyflags,
        asflags = asflags,
        export_includes = export_includes,
        export_system_includes = export_system_includes,
        local_includes = local_includes,
        absolute_includes = absolute_includes,
        rtti = rtti,
        stl = stl,
        cpp_std = cpp_std,
        c_std = c_std,
        whole_archive_deps = whole_archive_deps + static.get("whole_archive_deps", []),
        implementation_deps = implementation_deps + static.get("implementation_deps", []),
        dynamic_deps = dynamic_deps + static.get("dynamic_deps", []),
        implementation_dynamic_deps = implementation_dynamic_deps + static.get("implementation_dynamic_deps", []),
        system_dynamic_deps = add_lists_defaulting_to_none(
            system_dynamic_deps,
            static.get("system_dynamic_deps", None),
        ),
        deps = deps + static.get("deps", []),
        features = features,
    )

    cc_library_shared(
        name = shared_name,

        # Common arguments
        features = features,
        dynamic_deps = dynamic_deps + shared.get("dynamic_deps", []),
        implementation_dynamic_deps = implementation_dynamic_deps + shared.get("implementation_dynamic_deps", []),

        # shared_root static arguments
        hdrs = hdrs,
        srcs = srcs + shared.get("srcs", []),
        srcs_c = srcs_c + shared.get("srcs_c", []),
        srcs_as = srcs_as + shared.get("srcs_as", []),
        copts = copts + shared.get("copts", []),
        cppflags = cppflags,
        conlyflags = conlyflags,
        asflags = asflags,
        export_includes = export_includes,
        export_system_includes = export_system_includes,
        local_includes = local_includes,
        absolute_includes = absolute_includes,
        linkopts = linkopts,
        additional_linker_inputs = additional_linker_inputs,
        rtti = rtti,
        stl = stl,
        cpp_std = cpp_std,
        c_std = c_std,
        whole_archive_deps = whole_archive_deps + shared.get("whole_archive_deps", []),
        deps = deps + shared.get("deps", []),
        implementation_deps = implementation_deps + shared.get("implementation_deps", []),
        system_dynamic_deps = add_lists_defaulting_to_none(
            system_dynamic_deps,
            shared.get("system_dynamic_deps", None),
        ),

        # Shared library arguments
        strip = strip,
        link_crt = link_crt,
        soname = name + ".so",
    )

    _cc_library_proxy(
        name = name,
        static = static_name,
        shared = shared_name,
    )

def _cc_library_proxy_impl(ctx):
    static_files = ctx.attr.static[DefaultInfo].files.to_list()
    shared_files = ctx.attr.shared[DefaultInfo].files.to_list()
    files = static_files + shared_files

    return [
        ctx.attr.shared[CcSharedLibraryInfo],
        ctx.attr.shared[CcTocInfo],
        # Propagate includes from the static variant.
        CcInfo(compilation_context = ctx.attr.static[CcInfo].compilation_context),
        DefaultInfo(
            files = depset(direct = files),
            # Runfiles to be added if this is referenced via the "data" attribute, generally
            # for tests.
            data_runfiles = ctx.runfiles(files = files),
            # Shared library runfiles -- to indicate that only the shared library output needs to be
            # present at runtime (as a dynamic dependency).
            default_runfiles = ctx.runfiles(files = ctx.attr.shared[DefaultInfo].default_runfiles.files.to_list()),
        ),
        ctx.attr.static[CcStaticLibraryInfo],
    ]

_cc_library_proxy = rule(
    implementation = _cc_library_proxy_impl,
    attrs = {
        "shared": attr.label(mandatory = True, providers = [CcSharedLibraryInfo, CcTocInfo]),
        "static": attr.label(mandatory = True, providers = [CcInfo]),
    },
)
