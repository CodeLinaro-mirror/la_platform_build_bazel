load("//build/bazel/rules:cc_library_headers.bzl", "cc_library_headers")

# "cc_object" module copts, taken from build/soong/cc/object.go
_CC_OBJECT_COPTS = ["-fno-addrsig"]

def cc_object(
        name,
        copts = [],
        local_include_dirs = [],
        srcs = [],
        deps = [],
        native_bridge_supported = False, # TODO: not supported yet.
        **kwargs):
    "Build macro to correspond with the cc_object Soong module."

    # convert local_include_dirs to cc_library_headers deps
    include_deps = []
    for dir in local_include_dirs:
        dep_name = "generated__" + dir + "_includes" # may contain slashes, but valid label anyway.
        include_deps += [dep_name]

        # Since multiple cc_objects can refer to the same cc_library_headers dep, avoid
        # generating duplicate deps by using native.existing_rule.
        if native.existing_rule(dep_name) == None:
            cc_library_headers(
                name = dep_name,
                includes = [dir],
                strip_include_prefix = dir,
                include_prefix = dir,
                hdrs = native.glob([dir + "/**/*.h"]),
            )

    # combine deps and include deps
    all_deps = deps + include_deps

    # Simulate hdrs_check = 'loose' by allowing src files to reference headers
    # directly in the directories they are in.
    globs = {}
    for src in srcs:
        dir_name = src.split("/")[:-1]
        dir_name += ["*.h"]
        dir_glob = "/".join(dir_name)
        globs[dir_glob] = True
    hdrs = native.glob(globs.keys())

    native.cc_library(
        name = name,
        hdrs = hdrs,
        copts = _CC_OBJECT_COPTS + copts,
        srcs = srcs,
        deps = all_deps,
        **kwargs
    )
