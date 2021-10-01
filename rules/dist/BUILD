load(":dist.bzl", "copy_to_dist_dir")

py_binary(
    name = "dist",
    srcs = ["dist.py"],
    python_version = "PY3",
)

# bazel run --package_path=out/soong/workspace //build/bazel/rules/dist:dist_bionic_example -- --dist_dir=/tmp/dist
copy_to_dist_dir(
    name = "dist_bionic_example",
    data = [
        "//bionic/libc:libc",
        "//bionic/libdl:libdl",
    ],
)
