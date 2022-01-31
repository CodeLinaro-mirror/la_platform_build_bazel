toplevel_output_directories(paths = ["out"])

load("//build/bazel/rules:lunch.bzl", "lunch")
load("//build/bazel/rules:soong_injection.bzl", "soong_injection_repository")
load("//build/bazel/rules:make_injection.bzl", "make_injection_repository")

lunch()

register_toolchains(
    "//prebuilts/clang/host/linux-x86:all"
)

soong_injection_repository(name="soong_injection")

# This is a repository rule to allow Bazel builds to depend on Soong-built
# prebuilts for migration purposes.
make_injection_repository(
    name = "make_injection",
    binaries = [
        # APEX tools
        "aapt2",
        "apexer",
        "avbtool",
        "conv_apex_manifest",
        "deapexer",
        "debugfs",
        "e2fsdroid",
        "mke2fs",
        "resize2fs",
        "sefcontext_compile",
        "signapk",
    ],
    target_module_files = {
        # For APEX comparisons
        "com.android.tzdata": ["system/apex/com.android.tzdata.apex"],
        "com.android.runtime": ["system/apex/com.android.runtime.apex"],
        "com.android.adbd": ["system/apex/com.android.adbd.capex"],
        "build.bazel.examples.apex.minimal": ["system/product/apex/build.bazel.examples.apex.minimal.apex"],
    },
    watch_android_bp_files = [
        "//:build/bazel/examples/apex/minimal/Android.bp", # for build.bazel.examples.apex.minimal
        "//:packages/modules/adbd/apex/Android.bp", # for com.android.adbd
        # TODO(b/210399979) - add the other .bp files to watch for the other modules built in these rule
    ],
)

local_repository(
    name = "rules_cc",
    path = "build/bazel/rules_cc",
)

local_repository(
    name = "bazel_skylib",
    path = "external/bazel-skylib",
)

local_repository(
    name = "rules_android",
    path = "external/bazelbuild-rules_android",
)

register_toolchains(
  # For Starlark Android rules
  "//prebuilts/sdk:android_default_toolchain",
  "//prebuilts/sdk:android_sdk_tools",

  # For native android_binary
  "//prebuilts/sdk:android_sdk_tools_for_native_android_binary",

  # For APEX rules
  "//build/bazel/rules/apex:all"
)

bind(
  name = "databinding_annotation_processor",
  actual = "//prebuilts/sdk:compiler_annotation_processor",
)

bind(
  name = "android/dx_jar_import",
  actual = "//prebuilts/sdk:dx_jar_import",
)

# The r8.jar in prebuilts/r8 happens to have the d8 classes needed
# for Android app building, whereas the d8.jar in prebuilts/sdk/tools doesn't.
bind(
  name = "android/d8_jar_import",
  actual = "//prebuilts/r8:r8_jar_import",
)

# TODO(b/201242197): Avoid downloading remote_coverage_tools (on CI) by creating
# a stub workspace. Test rules (e.g. sh_test) depend on this external dep, but
# we don't support coverage yet. Either vendor the external dep into AOSP, or
# cut the dependency from test rules to the external repo.
local_repository(
    name = "remote_coverage_tools",
    path = "build/bazel/rules/coverage/remote_coverage_tools",
)
