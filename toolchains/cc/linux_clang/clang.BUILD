load(
    "@//build/bazel/toolchains/cc:actions.bzl",
    "ASSEMBLE_ACTIONS",
    "CPP_COMPILE_ACTIONS",
    "C_COMPILE_ACTIONS",
    "LINK_ACTIONS",
    "LTO_BACKEND_ACTIONS",
    "LTO_INDEX_ACTIONS",
    "OBJC_COMPILE_ACTIONS",
)
load(
    "@//build/bazel/toolchains/cc:rules.bzl",
    "cc_tool",
    "cc_toolchain_import",
)
load("@rules_cc//cc:action_names.bzl", "ACTION_NAMES")

package(default_visibility = ["@//build/bazel/toolchains/cc:__subpackages__"])

filegroup(
    name = "llvm_cov",
    srcs = ["bin/llvm-cov"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "llvm_profdata",
    srcs = ["bin/llvm-profdata"],
    visibility = ["//visibility:public"],
)

cc_tool(
    name = "clang",
    applied_actions = C_COMPILE_ACTIONS + OBJC_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS + ASSEMBLE_ACTIONS + LINK_ACTIONS + LTO_BACKEND_ACTIONS + LTO_INDEX_ACTIONS,
    runfiles = glob(
        [
            "bin/clang*",
            "bin/*lld",
        ],
        exclude = [
            "bin/clang-check",
            "bin/clangd",
            "bin/*clang-format",
            "bin/clang-tidy*",
        ],
    ) + ["bin/lld-link"],
    tool = ":bin/clang",
)

cc_tool(
    name = "archiver",
    applied_actions = [ACTION_NAMES.cpp_link_static_library],
    tool = ":bin/llvm-ar",
)

cc_tool(
    name = "strip",
    applied_actions = [ACTION_NAMES.strip],
    runfiles = [":bin/llvm-objcopy"],
    tool = ":bin/llvm-strip",
)

cc_toolchain_import(
    name = "libcxx",
    dynamic_mode_libs = [
        ":lib/x86_64-unknown-linux-gnu/libc++.so",
        ":lib/x86_64-unknown-linux-gnu/libc++abi.so",
    ],
    include_paths = [
        ":include/c++/v1",
    ],
    static_mode_libs = [
        ":lib/x86_64-unknown-linux-gnu/libc++.a",
        ":lib/x86_64-unknown-linux-gnu/libc++abi.a",
    ],
    support_files = glob(
        [
            "include/c++/v1/**",
        ],
    ),
)

cc_toolchain_import(
    name = "compiler_rt",
    include_paths = glob(
        [
            "lib/clang/*/include",
        ],
        exclude_directories = 0,
    ),
    lib_search_paths = glob(
        [
            "lib/clang/*/lib/x86_64-unknown-linux-gnu",
        ],
        exclude_directories = 0,
    ),
    support_files = glob(
        [
            "lib/clang/*/include/**",
            "lib/clang/*/lib/x86_64-unknown-linux-gnu/*",
        ],
    ),
)

# Clang's builtin headers (stddef.h, arm_neon.h, etc.) without any target-specific
# runtime libraries. Used by cross-compiling toolchains, which get their runtime libs
# from a target sysroot instead.
cc_toolchain_import(
    name = "builtin_headers",
    include_paths = glob(
        [
            "lib/clang/*/include",
        ],
        exclude_directories = 0,
    ),
    support_files = glob(
        [
            "lib/clang/*/include/**",
        ],
    ),
)

cc_toolchain_import(
    name = "libunwind",
    lib_search_paths = [
        ":lib/x86_64-unknown-linux-gnu",
    ],
    support_files = [
        ":lib/x86_64-unknown-linux-gnu/libunwind.a",
        ":lib/x86_64-unknown-linux-gnu/libgcc_s.a",
    ],
)
