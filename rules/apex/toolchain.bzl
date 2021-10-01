ApexToolchainInfo = provider(
    doc = "APEX toolchain",
    fields = [
        "aapt2",
        "avbtool",
        "apexer",
        "mke2fs",
        "resize2fs",
        "e2fsdroid",
        "sefcontext_compile",
        "conv_apex_manifest",
        "android_jar",
    ],
)

def _apex_toolchain_impl(ctx):
    toolchain_info = platform_common.ToolchainInfo(
        toolchain_info = ApexToolchainInfo(
            aapt2 = ctx.file.aapt2,
            avbtool = ctx.file.avbtool,
            apexer = ctx.file.apexer,
            mke2fs = ctx.file.mke2fs,
            resize2fs = ctx.file.resize2fs,
            e2fsdroid = ctx.file.e2fsdroid,
            sefcontext_compile = ctx.file.sefcontext_compile,
            conv_apex_manifest = ctx.file.conv_apex_manifest,
            android_jar = ctx.file.android_jar,
        ),
    )
    return [toolchain_info]

apex_toolchain = rule(
    implementation = _apex_toolchain_impl,
    attrs = {
        "aapt2": attr.label(allow_single_file = True, cfg = "host", executable = True),
        "avbtool": attr.label(allow_single_file = True, cfg = "host", executable = True),
        "apexer": attr.label(allow_single_file = True, cfg = "host", executable = True),
        "mke2fs": attr.label(allow_single_file = True, cfg = "host", executable = True),
        "resize2fs": attr.label(allow_single_file = True, cfg = "host", executable = True),
        "e2fsdroid": attr.label(allow_single_file = True, cfg = "host", executable = True),
        "sefcontext_compile": attr.label(allow_single_file = True, cfg = "host", executable = True),
        "conv_apex_manifest": attr.label(allow_single_file = True, cfg = "host", executable = True),
        "android_jar": attr.label(allow_single_file = True, cfg = "host"),
    },
)
