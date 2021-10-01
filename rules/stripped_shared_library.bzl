"""A macro to handle shared library stripping."""
load("@rules_cc//examples:experimental_cc_shared_library.bzl", "CcSharedLibraryInfo", "cc_shared_library")
load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cpp_toolchain")

# Keep this consistent with soong/cc/strip.go#NeedsStrip.
def needs_strip(attrs):
    force_disable = attrs.none
    force_enable = attrs.all or attrs.keep_symbols or attrs.keep_symbols_and_debug_frame
    return force_enable and not force_disable

# Keep this consistent with soong/cc/strip.go#strip and soong/cc/builder.go#transformStrip.
def get_strip_args(attrs):
    strip_args = []
    keep_symbols_list = attrs.keep_symbols_list
    keep_mini_debug_info = False
    if attrs.keep_symbols:
        strip_args += ["--keep-symbols"]
    elif attrs.keep_symbols_and_debug_frame:
        strip_args += ["--keep-symbols-and-debug-frame"]
    elif len(keep_symbols_list) > 0:
        strip_args += ["-k"+",".join(keep_symbols_list)]
    elif not attrs.all:
        strip_args += ["--keep-mini-debug-info"]
        keep_mini_debug_info = True

    if not keep_mini_debug_info:
        strip_args += ["--add-gnu-debuglink"]

    return strip_args


# https://cs.android.com/android/platform/superproject/+/master:build/soong/cc/builder.go;l=131-146;drc=master
def _stripped_shared_library_impl(ctx):
    # If this library doesn't need to be stripped, return the DefaultInfo
    # and CcSharedLibraryInfo as-is.
    if not needs_strip(ctx.attr):
        return [
            DefaultInfo(files = ctx.attr.src[DefaultInfo].files),
            ctx.attr.src[CcSharedLibraryInfo]
        ]

    cc_toolchain = find_cpp_toolchain(ctx)
    d_file = ctx.actions.declare_file(ctx.attr.name + ".d")
    out_file = ctx.actions.declare_file("lib" + ctx.attr.name + ".so")
    ctx.actions.run(
        env = {
            "CREATE_MINIDEBUGINFO": ctx.executable._create_minidebuginfo.path,
            "XZ": ctx.executable._xz.path,
            "CLANG_BIN": ctx.executable._ar.dirname,
        },
        inputs = ctx.files.src,
        tools = [
            ctx.executable._ar,
            ctx.executable._create_minidebuginfo,
            ctx.executable._objcopy,
            ctx.executable._readelf,
            ctx.executable._strip,
            ctx.executable._strip_script,
            ctx.executable._xz,
        ],
        outputs = [out_file, d_file],
        executable = ctx.executable._strip_script,
        arguments = get_strip_args(ctx.attr) + [
            "-i",
            ctx.files.src[0].path,
            "-o",
            out_file.path,
            "-d",
            d_file.path,
        ],
    )

    return [
        DefaultInfo(files = depset([out_file])),
        ctx.attr.src[CcSharedLibraryInfo]
    ]


stripped_shared_library = rule(
    implementation = _stripped_shared_library_impl,
    attrs = {
        "src": attr.label(mandatory = True, providers = [CcSharedLibraryInfo]),
        "keep_symbols": attr.bool(default = False),
        "keep_symbols_and_debug_frame": attr.bool(default = False),
        "all": attr.bool(default = False),
        "none": attr.bool(default = False),
        "keep_symbols_list": attr.string_list(default = []),
        "_xz": attr.label(
            cfg = "host",
            executable = True,
            allow_single_file = True,
            default = "//prebuilts/build-tools:linux-x86/bin/xz",
        ),
        "_create_minidebuginfo": attr.label(
            cfg = "host",
            executable = True,
            allow_single_file = True,
            default = "//prebuilts/build-tools:linux-x86/bin/create_minidebuginfo",
        ),
        "_strip_script": attr.label(
            cfg = "host",
            executable = True,
            allow_single_file = True,
            default = "//build/soong/scripts:strip.sh",
        ),
        "_ar": attr.label(
            cfg = "host",
            executable = True,
            allow_single_file = True,
            default = "//prebuilts/clang/host/linux-x86:llvm-ar",
        ),
        "_strip": attr.label(
            cfg = "host",
            executable = True,
            allow_single_file = True,
            default = "//prebuilts/clang/host/linux-x86:llvm-strip",
        ),
        "_readelf": attr.label(
            cfg = "host",
            executable = True,
            allow_single_file = True,
            default = "//prebuilts/clang/host/linux-x86:llvm-readelf",
        ),
        "_objcopy": attr.label(
            cfg = "host",
            executable = True,
            allow_single_file = True,
            default = "//prebuilts/clang/host/linux-x86:llvm-objcopy",
        ),
        "_cc_toolchain": attr.label(
            default = Label("@local_config_cc//:toolchain"),
            providers = [cc_common.CcToolchainInfo],
        ),
    },
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
)
