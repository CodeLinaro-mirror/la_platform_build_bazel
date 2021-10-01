load(":cc_constants.bzl", "constants")

def extension(f):
    return f.split(".")[-1]

def group_files_by_ext(files):
    cpp = []
    c = []
    asm = []
    # This for-loop iterator works because filegroups in Android don't use
    # configurable selects.
    for f in files:
        if extension(f) in constants.c_src_exts:
            c += [f]
        elif extension(f) in constants.cpp_src_exts:
            cpp += [f]
        elif extension(f) in constants.as_src_exts:
            asm += [f]
        else:
            # not C based
            continue
    return cpp, c, asm

# Filegroup is a macro because it needs to expand to language specific source
# files for cc_library's srcs_as, srcs_c and srcs attributes.
def filegroup(name, srcs = [], **kwargs):
    native.filegroup(
        name = name,
        srcs = srcs,
        **kwargs,
    )

    # These genrule prevent empty filegroups being used as deps to cc libraries,
    # avoiding the error:
    #
    # in srcs attribute of cc_library rule //foo/bar:baz:
    # '//foo/bar/some_other:baz2' does not produce any cc_library srcs files.
    native.genrule(
        name = name + "_null_cc",
        outs = [name + "_null.cc"],
        cmd = "touch $@",
    )
    native.genrule(
        name = name + "_null_c",
        outs = [name + "_null.c"],
        cmd = "touch $@",
    )
    native.genrule(
        name = name + "_null_s",
        outs = [name + "_null.s"],
        cmd = "touch $@",
    )

    cpp_srcs, c_srcs, as_srcs = group_files_by_ext(srcs)
    native.filegroup(
        name = name + "_cpp_srcs",
        srcs = [name + "_null.cc"] + cpp_srcs,
    )
    native.filegroup(
        name = name + "_c_srcs",
        srcs = [name + "_null.c"] + c_srcs,
    )
    native.filegroup(
        name = name + "_as_srcs",
        srcs = [name + "_null.s"] + as_srcs,
    )
