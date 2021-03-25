toplevel_output_directories(paths = ["out"])

load("//build/bazel/rules:lunch.bzl", "lunch")

lunch()

register_toolchains(
    "//prebuilts/clang/host/linux-x86:all"
)

local_repository(
    name = "rules_cc",
    path = "build/bazel/rules_cc",
)

local_repository(
    name = "bazel_skylib",
    path = "build/bazel/bazel_skylib",
)

