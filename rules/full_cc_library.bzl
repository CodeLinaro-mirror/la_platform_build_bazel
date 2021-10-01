load(":cc_library_static.bzl", "cc_library_static")
load("@rules_cc//examples:experimental_cc_shared_library.bzl", "CcSharedLibraryInfo", "cc_shared_library")
load(":stripped_shared_library.bzl", "stripped_shared_library")
load(":generate_toc.bzl", "shared_library_toc")

def _add_lists_defaulting_to_none(a, b):
    """Adds two lists a and b, but is well behaved with a `None` default."""
    if a == None:
      return b
    if b == None:
      return a
    return a + b

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
        system_dynamic_deps = None,
        includes = [],
        linkopts = [],
        rtti = False,
        use_libcrt = True,
        user_link_flags = [],
        version_script = None,
        strip = {},
        shared = {}, # attributes for the shared target
        static = {}, # attributes for the static target
        **kwargs):
    static_name = name + "_bp2build_cc_library_static"
    shared_name = name + "_bp2build_cc_library_shared"
    shared_root_name = name + "_bp2build_cc_library_shared_root"

    features = []
    if not use_libcrt:
        features += ["-use_libcrt"]

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
        includes = includes,
        linkopts = linkopts,
        rtti = rtti,
        whole_archive_deps = whole_archive_deps + static.get("whole_archive_deps", []),
        implementation_deps = implementation_deps + static.get("static_deps", []),
        dynamic_deps = dynamic_deps + static.get("dynamic_deps", []),
        system_dynamic_deps = _add_lists_defaulting_to_none(system_dynamic_deps,
                                                            static.get("system_dynamic_deps", None)),
        deps = deps,
        features = features,
    )

    # The static library at the root of the shared library.
    # This may be distinct from the static library if, for example,
    # the static-variant srcs are different than the shared-variant srcs.
    cc_library_static(
        name = shared_root_name,
        hdrs = hdrs,
        srcs = srcs + shared.get("srcs", []),
        srcs_c = srcs_c + shared.get("srcs_c", []),
        srcs_as = srcs_as + shared.get("srcs_as", []),
        copts = copts + shared.get("copts", []),
        cppflags = cppflags,
        conlyflags = conlyflags,
        asflags = asflags,
        includes = includes,
        linkopts = linkopts,
        rtti = rtti,
        whole_archive_deps = whole_archive_deps + shared.get("whole_archive_deps", []),
        implementation_deps = implementation_deps + shared.get("static_deps", []),
        dynamic_deps = dynamic_deps + shared.get("dynamic_deps", []),
        system_dynamic_deps = _add_lists_defaulting_to_none(system_dynamic_deps,
                                                            shared.get("system_dynamic_deps", None)),
        deps = deps,
        features = features,
    )

    cc_shared_library(
        name = shared_name + "_unstripped",
        user_link_flags = user_link_flags,
        # b/184806113: Note this is a pretty a workaround so users don't have to
        # declare all transitive static deps used by this target.  It'd be great
        # if a shared library could declare a transitive exported static dep
        # instead of needing to declare each target transitively.
        static_deps = ["//:__subpackages__"] + [shared_root_name],
        dynamic_deps = dynamic_deps + shared.get("dynamic_deps", []),
        version_script = version_script,
        roots = [shared_root_name],
        features = features,
    )

    stripped_shared_library(
        name = shared_name,
        src = shared_name + "_unstripped",
        **strip,
    )

    shared_library_toc(
        name = shared_name + "_toc",
        src = shared_name,
    )

    _cc_library_proxy(
        name = name,
        static = static_name,
        shared = shared_name,
        table_of_contents = shared_name + "_toc",
    )

# Returns a cloned copy of the given CcInfo object, except that all linker inputs
# with owner `old_owner_label` are recreated and owned by the current target.
#
# This is useful in the "macro with proxy rule" pattern, as some rules upstream
# may expect they are depending directly on a target which generates linker inputs,
# as opposed to a proxy target which is a level of indirection to such a target.
def _claim_ownership(ctx, old_owner_label, ccinfo):
    linker_inputs = []
    # This is not ideal, as it flattens a depset.
    for old_linker_input in ccinfo.linking_context.linker_inputs.to_list():
        if old_linker_input.owner == old_owner_label:
            new_linker_input = cc_common.create_linker_input(
                owner = ctx.label,
                libraries = depset(direct = old_linker_input.libraries))
            linker_inputs.append(new_linker_input)
        else:
            linker_inputs.append(old_linker_input)

    linking_context = cc_common.create_linking_context(linker_inputs = depset(direct = linker_inputs))
    return CcInfo(compilation_context = ccinfo.compilation_context, linking_context = linking_context)

def _cc_library_proxy_impl(ctx):
    static_files = ctx.attr.static[DefaultInfo].files.to_list()
    shared_files = ctx.attr.shared[DefaultInfo].files.to_list()

    table_of_contents = ctx.file.table_of_contents

    files = static_files + shared_files + [table_of_contents]

    return [
        ctx.attr.shared[CcSharedLibraryInfo],
        _claim_ownership(ctx, ctx.attr.static.label, ctx.attr.static[CcInfo]),
        DefaultInfo(
            files = depset(direct = files),
            runfiles = ctx.runfiles(files = files),
        ),
    ]

_cc_library_proxy = rule(
    implementation = _cc_library_proxy_impl,
    attrs = {
        "shared": attr.label(mandatory = True, providers = [CcSharedLibraryInfo]),
        "static": attr.label(mandatory = True, providers = [CcInfo]),
        "table_of_contents": attr.label(mandatory = True, allow_single_file = True),
    },
)
