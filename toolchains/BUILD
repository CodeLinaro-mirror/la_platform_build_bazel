load("@rules_nasm//nasm:defs.bzl", "nasm_toolchain")
load("@rules_python//python:defs.bzl", "py_test")

exports_files(
    ["tool_versions.json"],
    visibility = ["//visibility:public"],
)

nasm_toolchain(
    name = "nasm_toolchain_impl",
    nasm = "@nasm//:nasm",
    visibility = ["//visibility:public"],
)

toolchain(
    name = "nasm_toolchain",
    toolchain = ":nasm_toolchain_impl",
    toolchain_type = "@rules_nasm//nasm:toolchain_type",
    visibility = ["//visibility:public"],
)

py_test(
    name = "tool_versions_test",
    srcs = ["tool_versions_test.py"],
    data = [
        ":tool_versions.json",
        "//bzlmod:toolchain.MODULE.bazel",
    ],
    deps = ["@rules_python//python/runfiles"],
)
