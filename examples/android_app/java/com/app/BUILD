load("//build/bazel/rules/android:android_binary.bzl", "android_binary")
load("@rules_android//rules:rules.bzl", "android_library")

android_binary(
    name = "app",
    manifest = "AndroidManifest.xml",
    deps = [
        ":applib",
    ],
)

android_binary(
    name = "app-cert-string",
    certificate_name = "platform",
    manifest = "AndroidManifest.xml",
    deps = [
        ":applib",
    ],
)

android_binary(
    name = "app-cert-module",
    certificate = "//build/make/target/product/security:aosp-testkey",
    manifest = "AndroidManifest.xml",
    deps = [
        ":applib",
    ],
)

android_library(
    name = "applib",
    srcs = [
        "MainActivity.java",
        #"Jni.java", # TODO(b/220366404): integrate JNI
    ],
    manifest = "AndroidManifest.xml",
    resource_files = glob(["res/**"]),
    deps = [
        ":lib",
        #":jni", # TODO(b/220366404): integrate JNI
    ],
)

android_library(
    name = "lib",
    srcs = ["Lib.java"],
)

cc_library(
    name = "jni",
    srcs = ["jni.cc"],
    tags = ["manual"],  # need to be built in android transition, so exclude from ... and :all target patterns
    deps = [":jni_dep"],
)

cc_library(
    name = "jni_dep",
    srcs = ["jni_dep.cc"],
    hdrs = ["jni_dep.h"],
    tags = ["manual"],  # need to be built in android transition, so exclude from ... and :all target patterns
)
