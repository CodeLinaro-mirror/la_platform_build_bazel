load(
    "@goldfish_build//toolchains/cc:rules.bzl",
    "cc_toolchain_config",
    "cc_toolchain_dynamic_runtime",
    "cc_toolchain_static_runtime",
)
load("@goldfish_build//toolchains/cc/linux_clang:features.bzl", "cc_features")
load("@rules_cc//cc:defs.bzl", "cc_toolchain")

package(default_visibility = ["//visibility:public"])

_x64_imports = [
    "@clang_linux_x64//:libcxx",
    "@clang_linux_x64//:compiler_rt",
    "@clang_linux_x64//:libunwind",
    "@gcc_lib//:start_libs",
    "@gcc_lib//:libs",
]

_arm64_imports = [
    "@arm_sysroot//:libstdcxx",
    "@arm_sysroot//:libs",
    "@clang_linux_x64//:compiler_hdrs",
]

_warning_flags = [
    "-Wall",
    "-Wthread-safety",
    "-Wthread-safety-analysis",
    "-Wthread-safety-attributes",
    "-Wthread-safety-beta",
    "-Wthread-safety-negative",
    "-Wno-error=thread-safety-negative",
    "-Wthread-safety-pointer",
    "-Wthread-safety-precise",
    "-Wthread-safety-reference",
    "-Wthread-safety-reference-return",
    "-Wthread-safety-verbose",
    "-Wno-character-conversion",
    "-Wno-deprecated-declarations",
    "-Wno-initializer-overrides",
    "-Wno-unused-const-variable",
    "-Wno-ignored-attributes",
    "-Wno-writable-strings",
    "-Wno-extern-c-compat",
    "-Wno-unused-function",
    "-Wno-unused-variable",
    "-Wno-c99-designator",
    "-Wno-unknown-warning-option",
    "-Wno-gnu-variable-sized-type-not-at-end",
    "-Wno-macro-redefined",
]

cc_features(
    name = "x64_features",
    assembler_flags = [
        "--target=x86_64-unknown-linux-gnu",
    ],
    b_prefix = "@gcc_lib//:lib/gcc/x86_64-linux/4.8.3",
    compile_flags = [
        "--target=x86_64-unknown-linux-gnu",
        "-fstack-protector-strong",
        "-fcolor-diagnostics",
        "-D__STDC_FORMAT_MACROS",
    ],
    cxx_flags = [
        "-std=c++26",
        "-fno-exceptions",
    ],
    link_flags = [
        "--target=x86_64-unknown-linux-gnu",
        "-fuse-ld=lld",
        "-rtlib=compiler-rt",
        "-Wno-unused-command-line-argument",
        "-Wl,--as-needed",
        "-lm",
        "-ldl",
        "-Wl,--no-as-needed",
        "-l:libunwind.a",
    ],
    toolchain_imports = _x64_imports,
    warning_flags = _warning_flags,
)

cc_toolchain_config(
    name = "x64_config",
    cc_features = ":x64_features",
    cc_tools = [
        "@clang_linux_x64//:clang",
        "@clang_linux_x64//:clang-tidy",
        "@clang_linux_x64//:archiver",
        "@clang_linux_x64//:strip",
        "@clang_linux_x64//:llvm-cov",
        "@clang_linux_x64//:llvm-profdata",
    ],
    compiler_name = "clang",
    identifier = "linux_clang_x64",
    sysroot = "@gcc_lib//:sysroot",
    target_cpu = "k8",
    toolchain_imports = _x64_imports,
)

cc_toolchain_dynamic_runtime(
    name = "x64_dynamic_runtime",
    libs = _x64_imports,
)

cc_toolchain_static_runtime(
    name = "x64_static_runtime",
    libs = _x64_imports,
)

cc_toolchain(
    name = "x64",
    all_files = ":x64_config",
    ar_files = "@clang_linux_x64//:archiver",
    as_files = "@clang_linux_x64//:clang",
    compiler_files = ":x64_config",
    dwp_files = "@goldfish_build//toolchains/cc:empty",
    dynamic_runtime_lib = ":x64_dynamic_runtime",
    linker_files = ":x64_config",
    objcopy_files = "@goldfish_build//toolchains/cc:empty",
    static_runtime_lib = ":x64_static_runtime",
    strip_files = "@clang_linux_x64//:strip",
    supports_param_files = True,
    toolchain_config = ":x64_config",
)

toolchain(
    name = "x64_toolchain",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:linux",
        "@bazel_tools//tools/cpp:clang",
    ],
    target_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:linux",
    ],
    toolchain = ":x64",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

cc_features(
    name = "arm64_features",
    assembler_flags = [
        "--target=aarch64-none-linux-gnu",
    ],
    cc_only_link_flags = ["-lstdc++"],
    compile_flags = [
        "--target=aarch64-none-linux-gnu",
        "--gcc-toolchain=external/goldfish_build++http_archive+arm_sysroot",
        "-fstack-protector-strong",
        "-fcolor-diagnostics",
        "-D__STDC_FORMAT_MACROS",
    ],
    cxx_flags = [
        "-std=c++26",
    ],
    link_flags = [
        "--target=aarch64-none-linux-gnu",
        "--gcc-toolchain=external/goldfish_build++http_archive+arm_sysroot",
        "-fuse-ld=lld",
        "-Wno-unused-command-line-argument",
        # In-process ThinLTO on rust_shared_library lowers AArch64 outline
        # atomics (__aarch64_*) after archive scanning, resolving against
        # Rust's libcompiler_builtins.a.
        "-Wl,--warn-backrefs-exclude=*libcompiler_builtins*",
        "-Wl,--as-needed",
        "-lm",
        "-ldl",
        "-Wl,--no-as-needed",
    ],
    toolchain_imports = _arm64_imports,
    warning_flags = _warning_flags,
)

cc_toolchain_config(
    name = "arm64_config",
    cc_features = ":arm64_features",
    cc_tools = [
        "@clang_linux_x64//:clang",
        "@clang_linux_x64//:clang-tidy",
        "@clang_linux_x64//:archiver",
        "@clang_linux_x64//:strip",
        "@clang_linux_x64//:llvm-cov",
        "@clang_linux_x64//:llvm-profdata",
    ],
    compiler_name = "clang",
    identifier = "linux_clang_arm64",
    sysroot = "@arm_sysroot//:arm_sysroot",
    target_cpu = "aarch64",
    toolchain_imports = _arm64_imports,
)

cc_toolchain_dynamic_runtime(
    name = "arm64_dynamic_runtime",
    libs = _arm64_imports,
)

cc_toolchain(
    name = "arm64",
    all_files = ":arm64_config",
    ar_files = "@clang_linux_x64//:archiver",
    as_files = "@clang_linux_x64//:clang",
    compiler_files = ":arm64_config",
    dwp_files = "@goldfish_build//toolchains/cc:empty",
    dynamic_runtime_lib = ":arm64_dynamic_runtime",
    linker_files = ":arm64_config",
    objcopy_files = "@goldfish_build//toolchains/cc:empty",
    static_runtime_lib = "@goldfish_build//toolchains/cc:empty",
    strip_files = "@clang_linux_x64//:strip",
    supports_param_files = True,
    toolchain_config = ":arm64_config",
)

toolchain(
    name = "arm64_toolchain",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:linux",
        "@bazel_tools//tools/cpp:clang",
    ],
    target_compatible_with = [
        "@platforms//cpu:arm64",
        "@platforms//os:linux",
    ],
    toolchain = ":arm64",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

toolchain(
    name = "x64_objcopy_toolchain",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:linux",
    ],
    toolchain = "@clang_linux_x64//:objcopy",
    toolchain_type = "@goldfish_build//toolchains/cc:objcopy_toolchain_type",
)
