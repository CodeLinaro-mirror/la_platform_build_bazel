toplevel_output_directories(paths = ["out"])

load("//build/bazel/rules:lunch.bzl", "lunch")
load("//build/bazel/rules:soong_injection.bzl", "soong_injection_repository")
load("//build/bazel/rules:make_injection.bzl", "make_injection_repository")

lunch()

register_toolchains(
    "//prebuilts/clang/host/linux-x86:all"
)

soong_injection_repository(name="soong_injection")
make_injection_repository(
    name = "make_injection",
    modules = [
        # APEX tools
        "aapt2",
        "apexer",
        "avbtool",
        "conv_apex_manifest",
        "e2fsdroid",
        "mke2fs",
        "resize2fs",
        "sefcontext_compile",
        "signapk",

        "deapexer",
        "debugfs",

        # APEX comparisons
        "com.android.tzdata",
        "com.android.runtime",
        "com.android.adbd",
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

  # Local AOSP JDK
  "//prebuilts/jdk/jdk11/linux-x86:jdk11_toolchain",

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
