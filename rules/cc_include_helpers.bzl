load("//build/bazel/rules:cc_library_headers.bzl", "cc_library_headers")

# Helpers for managing helpers and includes for cc rules.

def cc_library_header_suite(local_include_dirs):
    """Create cc_library_headers targets for given local_include_dirs.

    The created cc_library_headers targets depend on the given local_include_dirs
    and are unique to targets in the current directory. Thus, an invocation of this
    method may not necessarily create new targets, if these targets were already
    created in a previous invocation of this function.

    Returns: A string list of the labels corresponding to the header libraries."""

    include_deps = []
    for dir in local_include_dirs:
        dep_name = "generated__" + dir + "_includes" # may contain slashes, but valid label anyway.
        include_deps += [dep_name]

        # Avoid generating duplicate deps by using native.existing_rule.
        if native.existing_rule(dep_name) == None:
            dep_hdrs = None
            # The local build package may be included as "."
            if dir == ".":
                dep_hdrs = native.glob(["*.h"])
            else:
                dep_hdrs = native.glob([dir + "/**/*.h"])
            cc_library_headers(
                name = dep_name,
                includes = [dir],
                hdrs = dep_hdrs,
            )

    return include_deps

def hdr_globs_for_srcs(srcs):
    """Return globs for headers in the directories matching the given srcs.

    This simulates hdrs_check = 'loose' by allowing src files to reference headers
    directly in the directories they are in."""
    globs = {}
    for src in srcs:
        dir_name = src.split("/")[:-1]
        dir_name += ["*.h"]
        dir_glob = "/".join(dir_name)
        globs[dir_glob] = True
    return native.glob(globs.keys())
