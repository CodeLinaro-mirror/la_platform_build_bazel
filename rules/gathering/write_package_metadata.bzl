"""
This file contains the implementation of the write_package_metadata rule.
"""

load(
    "@rules_license//rules_gathering:gather_metadata.bzl",
    "gather_metadata_info",
    "write_metadata_info",
)
load("//rules/gathering:gather_prebuilt_info.bzl", "gather_prebuilt_metadata")
load("//rules/gathering:providers.bzl", "TransitivePrebuiltPackageInfo")

def _write_package_metadata_impl(ctx):
    licenses_file = ctx.actions.declare_file("_%s_licenses_info.json" % ctx.label.name)
    write_metadata_info(ctx, ctx.attr.deps, licenses_file)
    outputs = [licenses_file]

    # TODO: b/337111620 - Merge licenses_file with merged output.
    merged_output = ctx.actions.declare_file(ctx.label.name + ".json")
    spdx_files = set([])
    third_party_library_files = set([])
    for dep in ctx.attr.deps:
        if TransitivePrebuiltPackageInfo in dep:
            package_infos = dep[TransitivePrebuiltPackageInfo].deps.to_list()
            for pkg_info in package_infos:
                if pkg_info.third_party_dependencies:
                    third_party_library_files.add(pkg_info.third_party_dependencies)
                if pkg_info.spdx_json:
                    spdx_files.add(pkg_info.spdx_json)
    args = ctx.actions.args()
    args.add_all("--spdx_json", list(spdx_files))
    args.add_all("--third_party_libraries", list(third_party_library_files))
    args.add("--output", merged_output.path)
    ctx.actions.run(
        outputs = [merged_output],
        inputs = list(spdx_files.union(third_party_library_files)),
        executable = ctx.executable._merge_metadata,
        arguments = [args],
        mnemonic = "MergePkgMetadata",
    )
    outputs.append(merged_output)

    return [
        DefaultInfo(files = depset(outputs)),
        OutputGroupInfo(licenses_file = depset([licenses_file])),
    ]

write_package_metadata = rule(
    implementation = _write_package_metadata_impl,
    doc = """
    A rule that writes package metadata for a prebuilt package.
    """,
    attrs = {
        "deps": attr.label_list(
            aspects = [gather_metadata_info, gather_prebuilt_metadata],
            doc = """
            The dependencies to generate the package metadata from.

            NOTE: Every dep is expected to have package_metadata that includes
            a @rules_license license associated, else this rule will fail.
            """,
        ),
        "_merge_metadata": attr.label(
            default = Label("//rules/gathering:merge_metadata"),
            executable = True,
            cfg = "exec",
        ),
    },
)
