load("//build/bazel/rules/apex:toolchain.bzl", "apex_toolchain")
load("@bazel_skylib//rules:common_settings.bzl", "string_setting")

string_setting(name = "apex_name", build_setting_default = "")
string_setting(name = "min_sdk_version", build_setting_default = "")

toolchain_type(name = "apex_toolchain_type")

apex_toolchain(
    name = "prebuilt_apex_toolchain",
    aapt2 = "@make_injection//:host/linux-x86/bin/aapt2",
    avbtool = "@make_injection//:host/linux-x86/bin/avbtool",
    apexer = "@make_injection//:host/linux-x86/bin/apexer",
    mke2fs = "@make_injection//:host/linux-x86/bin/mke2fs",
    resize2fs = "@make_injection//:host/linux-x86/bin/resize2fs",
    e2fsdroid = "@make_injection//:host/linux-x86/bin/e2fsdroid",
    sefcontext_compile = "@make_injection//:host/linux-x86/bin/sefcontext_compile",
    conv_apex_manifest = "@make_injection//:host/linux-x86/bin/conv_apex_manifest",
    android_jar = "//prebuilts/sdk/current:public/android.jar",
)

toolchain(
    name = "prebuilt_apex_toolchain_def",
    exec_compatible_with = [
        "//build/bazel/platforms/arch:x86_64",
        "//build/bazel/platforms/os:linux",
    ],
    target_compatible_with = [
        "//build/bazel/platforms/os:android",
    ],
    toolchain = ":prebuilt_apex_toolchain",
    toolchain_type = "//build/bazel/rules/apex:apex_toolchain_type",
)

py_binary(
    name = "bazel_apexer_wrapper",
    srcs = ["bazel_apexer_wrapper.py"],
    visibility = ["//visibility:public"],
)

sh_test(
    name = "bazel_apexer_wrapper_test",
    srcs = ["bazel_apexer_wrapper_test.sh"],
    deps = ["@bazel_tools//tools/bash/runfiles"],
    data = [
        ":bazel_apexer_wrapper",
        "test.pem",
        "@make_injection//:host/linux-x86/bin/aapt2",
        "@make_injection//:host/linux-x86/bin/avbtool",
        "@make_injection//:host/linux-x86/bin/apexer",
        "@make_injection//:host/linux-x86/bin/conv_apex_manifest",
        "@make_injection//:host/linux-x86/bin/deapexer",
        "@make_injection//:host/linux-x86/bin/debugfs",
        "@make_injection//:host/linux-x86/bin/e2fsdroid",
        "@make_injection//:host/linux-x86/bin/mke2fs",
        "@make_injection//:host/linux-x86/bin/resize2fs",
        "@make_injection//:host/linux-x86/bin/sefcontext_compile",
        "//prebuilts/sdk/current:public/android.jar",
    ]
)
