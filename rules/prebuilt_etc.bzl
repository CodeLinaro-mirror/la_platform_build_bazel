PrebuiltEtcInfo = provider(
    "Info needed for prebuilt_etc modules",
    fields={
        "src": "Source file of this prebuilt",
        "sub_dir": "Optional subdirectory to install into",
        "filename": "Optional name for the installed file",
        "installable": "Whether this is directly installable into one of the partitions",
    })


def _prebuilt_etc_rule_impl(ctx):
    return [
        PrebuiltEtcInfo(
            src = ctx.file.src,
            sub_dir = ctx.attr.sub_dir,
            filename = ctx.attr.filename,
            installable = ctx.attr.installable
        )
    ]

_prebuilt_etc = rule(
    implementation = _prebuilt_etc_rule_impl,
    attrs = {
        "src": attr.label(mandatory = True, allow_single_file = True),
        "sub_dir": attr.string(),
        "filename": attr.string(),
        "installable": attr.bool(default = True),
    },
)

def prebuilt_etc(
    name,
    src,
    sub_dir = None,
    filename = None,
    installable = True,
    **kwargs):
    "Bazel macro to correspond with the prebuilt_etc Soong module."

    _prebuilt_etc(
        name = name,
        src = src,
        sub_dir = sub_dir,
        filename = filename,
        installable = installable,
        **kwargs,
    )
