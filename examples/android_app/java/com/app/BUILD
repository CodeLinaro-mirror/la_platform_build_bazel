load("@rules_android//rules:rules.bzl", "android_binary", "android_library")

android_binary(
    name = "app",
    manifest = "AndroidManifest.xml",
    deps = [
        ":applib",
    ],
)

android_library(
  name = "applib",
  srcs = [
      "MainActivity.java",
      #"Jni.java", # TODO: integrate JNI
  ],
  resource_files = glob(["res/**"]),
  manifest = "AndroidManifest.xml",
  deps = [
    ":lib",
    #":jni", # TODO: integrate JNI
  ]
)

android_library(
    name = "lib",
    srcs = ["Lib.java"],
)

cc_library(
    name = "jni",
    srcs = ["jni.cc"],
    deps = [":jni_dep"],
    tags = ["manual"], # need to be built in android transition, so exclude from ... and :all target patterns
)

cc_library(
    name = "jni_dep",
    srcs = ["jni_dep.cc"],
    hdrs = ["jni_dep.h"],
    tags = ["manual"], # need to be built in android transition, so exclude from ... and :all target patterns
)
