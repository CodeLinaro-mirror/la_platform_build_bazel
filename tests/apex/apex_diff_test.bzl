load("@bazel_skylib//rules:diff_test.bzl", "diff_test")

def apex_diff_test(name, apex1, apex2, **kwargs):
    """A test that compares the content list of two APEXes, determined by `deapexer`."""

    native.alias(
        name = "deapexer",
        actual = "@make_injection//:host/linux-x86/bin/deapexer",
    )

    native.alias(
        name = "debugfs",
        actual = "@make_injection//:host/linux-x86/bin/debugfs",
    )

    native.genrule(
        name = name + "_apex1_deapex",
        tools = [
            ":deapexer",
            ":debugfs",
        ],
        srcs = [apex1],
        outs = [name + ".apex1.txt"],
        cmd = "$(location :deapexer) --debugfs_path=$(location :debugfs) list $< > $@",
    )

    native.genrule(
        name = name + "_apex2_deapex",
        tools = [
            ":deapexer",
            ":debugfs",
        ],
        srcs = [apex2],
        outs = [name + ".apex2.txt"],
        cmd = "$(location :deapexer) --debugfs_path=$(location :debugfs) list $< > $@",
    )

    diff_test(
        name = "tzdata_content_diff_test",
        file1 = name + ".apex1.txt",
        file2 = name + ".apex2.txt",
    )
