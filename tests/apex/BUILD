load(":apex_diff_test.bzl", "apex_diff_test")

apex_diff_test(
    name = "com.android.tzdata",
    apex1 = "//system/timezone/apex:com.android.tzdata",
    apex2 = "@make_injection//:target/product/generic/system/apex/com.android.tzdata.apex",
)

apex_diff_test(
    name = "build.bazel.examples.apex.minimal",
    apex1 = "//build/bazel/examples/apex/minimal:build.bazel.examples.apex.minimal",
    apex2 = "@make_injection//:target/product/generic/system/product/apex/build.bazel.examples.apex.minimal.apex",
)

apex_diff_test(
    name = "com.android.adbd",
    apex1 = "//packages/modules/adb/apex:com.android.adbd",
    apex2 = "@make_injection//:target/product/generic/system/apex/com.android.adbd.capex",
)
