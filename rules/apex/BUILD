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
