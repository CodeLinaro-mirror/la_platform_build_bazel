load(":cc_library_common.bzl", "add_lists_defaulting_to_none", "system_dynamic_deps_defaults", "disable_crt_link")
load(":cc_library_static.bzl", "cc_library_static")
load(":stl.bzl", "shared_stl_deps")
load("@rules_cc//examples:experimental_cc_shared_library.bzl", "cc_shared_library", _CcSharedLibraryInfo = "CcSharedLibraryInfo")
load(":stripped_cc_common.bzl", "stripped_shared_library")
load(":generate_toc.bzl", "shared_library_toc", _CcTocInfo = "CcTocInfo")

CcTocInfo = _CcTocInfo
CcSharedLibraryInfo = _CcSharedLibraryInfo

def cc_library_shared(
        name,
        # Common arguments between shared_root and the shared library
        features = [],
        dynamic_deps = [],
        implementation_dynamic_deps = [],
        linkopts = [],

        # Ultimately _static arguments for shared_root production
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
        system_dynamic_deps = None,
        export_includes = [],
        export_system_includes = [],
        local_includes = [],
        absolute_includes = [],
        rtti = False,
        use_libcrt = True,
        stl = "",
        cpp_std = "",
        link_crt = True,

        additional_linker_inputs = None,

        # Purely _shared arguments
        strip = {},
        **kwargs):
    "Bazel macro to correspond with the cc_library_shared Soong module."

    shared_root_name = name + "_root"
    unstripped_name = name + "_unstripped"
    stripped_name = name + "_stripped"
    toc_name = name + "_toc"

    if system_dynamic_deps == None:
        system_dynamic_deps = system_dynamic_deps_defaults

    # Force crtbegin and crtend linking unless explicitly disabled (i.e. bionic
    # libraries do this)
    if link_crt == False:
        features = disable_crt_link(features)

    # The static library at the root of the shared library.
    # This may be distinct from the static version of the library if e.g.
    # the static-variant srcs are different than the shared-variant srcs.
    cc_library_static(
        name = shared_root_name,
        hdrs = hdrs,
        srcs = srcs,
        srcs_c = srcs_c,
        srcs_as = srcs_as,
        copts = copts,
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
        dynamic_deps = dynamic_deps,
        implementation_deps = implementation_deps,
        implementation_dynamic_deps = implementation_dynamic_deps,
        system_dynamic_deps = system_dynamic_deps,
        deps = deps + whole_archive_deps,
        features = features,
    )

    stl_static, stl_shared = shared_stl_deps(stl)

    # implementation_deps and deps are to be linked into the shared library via
    # --no-whole-archive. In order to do so, they need to be dependencies of
    # a "root" of the cc_shared_library, but may not be roots themselves.
    # Below we define stub roots (which themselves have no srcs) in order to facilitate
    # this.
    imp_deps_stub = name + "_implementation_deps"
    deps_stub = name + "_deps"
    native.cc_library(
        name = imp_deps_stub,
        deps = implementation_deps + stl_static,
    )
    native.cc_library(
        name = deps_stub,
        deps = deps,
    )

    shared_dynamic_deps = add_lists_defaulting_to_none(
        dynamic_deps,
        system_dynamic_deps,
        implementation_dynamic_deps,
        stl_shared,
    )

    cc_shared_library(
        name = unstripped_name,
        user_link_flags = linkopts,
        # b/184806113: Note this is  a workaround so users don't have to
        # declare all transitive static deps used by this target.  It'd be great
        # if a shared library could declare a transitive exported static dep
        # instead of needing to declare each target transitively.
        static_deps = ["//:__subpackages__"] + [shared_root_name, imp_deps_stub, deps_stub],
        dynamic_deps = shared_dynamic_deps,
        additional_linker_inputs = additional_linker_inputs,
        roots = [shared_root_name, imp_deps_stub, deps_stub] + whole_archive_deps,
        features = features,
        **kwargs
    )

    stripped_shared_library(
        name = stripped_name,
        src = unstripped_name,
        **strip
    )

    shared_library_toc(
        name = toc_name,
        src = stripped_name,
    )

    _cc_library_shared_proxy(
        name = name,
        shared = stripped_name,
        root = shared_root_name,
        table_of_contents = toc_name,
    )

def _cc_library_shared_proxy_impl(ctx):
    root_files = ctx.attr.root[DefaultInfo].files.to_list()
    shared_files = ctx.attr.shared[DefaultInfo].files.to_list()

    files = root_files + shared_files + [ctx.file.table_of_contents]

    return [
        DefaultInfo(
            files = depset(direct = files),
            runfiles = ctx.runfiles(files = files),
        ),
        ctx.attr.shared[CcSharedLibraryInfo],
        ctx.attr.table_of_contents[CcTocInfo],
        # Propagate only includes from the root. Do not re-propagate linker inputs.
        CcInfo(compilation_context = ctx.attr.root[CcInfo].compilation_context),
    ]

_cc_library_shared_proxy = rule(
    implementation = _cc_library_shared_proxy_impl,
    attrs = {
        "shared": attr.label(mandatory = True, providers = [CcSharedLibraryInfo]),
        "root": attr.label(mandatory = True, providers = [CcInfo]),
        "table_of_contents": attr.label(mandatory = True, allow_single_file = True, providers = [CcTocInfo]),
    },
)
