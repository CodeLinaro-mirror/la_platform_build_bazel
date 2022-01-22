"""
Copyright (C) 2021 The Android Open Source Project

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""

load(":apex_key.bzl", "ApexKeyInfo")
load(":prebuilt_etc.bzl", "PrebuiltEtcInfo")
load(":sh_binary.bzl", "ShBinaryInfo")
load(":android_app_certificate.bzl", "AndroidAppCertificateInfo")
load("//build/bazel/rules/apex:transition.bzl", "apex_transition")
load("//build/bazel/rules/apex:cc.bzl", "ApexCcInfo", "apex_cc_aspect")

# Prepare the input files info for bazel_apexer_wrapper to generate APEX filesystem image.
def _prepare_apexer_wrapper_inputs(ctx):
    # apex_manifest[(image_file_dirname, image_file_basename)] = bazel_output_file
    apex_manifest = {}

    # Handle native_shared_libs
    for dep in ctx.attr.native_shared_libs:
        apex_cc_info = dep[ApexCcInfo]

        # TODO: Update apex_transition to split (1:4) the deps, one for each target platform
        # Then ApexCcInfo would only return a single lib_files field

        for lib_file in apex_cc_info.lib_files:
            apex_manifest[("lib", lib_file.basename)] = lib_file

        for lib64_file in apex_cc_info.lib64_files:
            apex_manifest[("lib64", lib64_file.basename)] = lib64_file

        for lib_arm_file in apex_cc_info.lib_arm_files:
            apex_manifest[("lib/arm", lib_arm_file.basename)] = lib_arm_file

    # Handle prebuilts
    for dep in ctx.attr.prebuilts:
        # TODO: Support more prebuilts than just PrebuiltEtc
        prebuilt_etc_info = dep[PrebuiltEtcInfo]

        directory = "etc"
        if prebuilt_etc_info.sub_dir != None and prebuilt_etc_info.sub_dir != "":
            directory = "/".join([directory, prebuilt_etc_info.sub_dir])

        if prebuilt_etc_info.filename != None and prebuilt_etc_info.filename != "":
            filename = prebuilt_etc_info.filename
        else:
            filename = dep.label.name

        apex_manifest[(directory, filename)] = prebuilt_etc_info.src

    # Handle binaries
    for dep in ctx.attr.binaries:
        # TODO: Support more binaries than just sh_binary
        sh_binary_info = dep[ShBinaryInfo]
        default_info = dep[DefaultInfo]
        if sh_binary_info != None:
            directory = "bin"
            if sh_binary_info.sub_dir != None and sh_binary_info.sub_dir != "":
                directory = "/".join([directory, sh_binary_info.sub_dir])

            if sh_binary_info.filename != None and sh_binary_info.filename != "":
                filename = sh_binary_info.filename
            else:
                filename = dep.label.name

            apex_manifest[(directory, filename)] = default_info.files_to_run.executable

    apex_content_inputs = []

    bazel_apexer_wrapper_manifest = ctx.actions.declare_file("bazel_apexer_wrapper_manifest")
    file_lines = []

    # Store the apex file target directory, file name and the path in the source tree in a file.
    # This file will be read by the bazel_apexer_wrapper to create the apex input directory.
    # Here is an example:
    # {etc/tz,tz_version,system/timezone/output_data/version/tz_version}
    for (apex_dirname, apex_basename), bazel_input_file in apex_manifest.items():
        apex_content_inputs.append(bazel_input_file)
        file_lines += [",".join([apex_dirname, apex_basename, bazel_input_file.path])]

    ctx.actions.write(bazel_apexer_wrapper_manifest, "\n".join(file_lines))

    return apex_content_inputs, bazel_apexer_wrapper_manifest

# conv_apex_manifest - Convert the JSON APEX manifest to protobuf, which is needed by apexer.
def _convert_apex_manifest_json_to_pb(ctx, apex_toolchain):
    apex_manifest_json = ctx.file.manifest
    apex_manifest_pb = ctx.actions.declare_file("apex_manifest.pb")

    ctx.actions.run(
        outputs = [apex_manifest_pb],
        inputs = [ctx.file.manifest],
        executable = apex_toolchain.conv_apex_manifest,
        arguments = [
            "proto",
            apex_manifest_json.path,
            "-o",
            apex_manifest_pb.path,
        ],
        mnemonic = "ConvApexManifest",
    )

    return apex_manifest_pb

# apexer - generate the APEX file.
def _run_apexer(ctx, apex_toolchain, apex_content_inputs, bazel_apexer_wrapper_manifest, apex_manifest_pb):
    # Inputs
    file_contexts = ctx.file.file_contexts
    apex_key_info = ctx.attr.key[ApexKeyInfo]
    privkey = apex_key_info.private_key
    pubkey = apex_key_info.public_key
    android_jar = apex_toolchain.android_jar
    android_manifest = ctx.file.android_manifest

    # Outputs
    apex_output_file = ctx.actions.declare_file(ctx.attr.name + ".apex")

    # Arguments
    args = ctx.actions.args()
    args.add_all(["--manifest", apex_manifest_pb.path])
    args.add_all(["--file_contexts", file_contexts.path])
    args.add_all(["--key", privkey.path])
    args.add_all(["--pubkey", pubkey.path])
    args.add_all(["--min_sdk_version", ctx.attr.min_sdk_version])
    args.add_all(["--bazel_apexer_wrapper_manifest", bazel_apexer_wrapper_manifest])
    args.add_all(["--apexer_tool_path", apex_toolchain.apexer.dirname])
    args.add_all(["--apex_output_file", apex_output_file])

    if android_manifest != None:
        args.add_all(["--android_manifest", android_manifest.path])

    inputs = apex_content_inputs + [
        bazel_apexer_wrapper_manifest,
        apex_manifest_pb,
        file_contexts,
        privkey,
        pubkey,
        android_jar,
        apex_toolchain.apexer,
        apex_toolchain.mke2fs,
        apex_toolchain.e2fsdroid,
        apex_toolchain.sefcontext_compile,
        apex_toolchain.resize2fs,
        apex_toolchain.avbtool,
        apex_toolchain.aapt2,
    ]

    if android_manifest != None:
        inputs.append(android_manifest)

    ctx.actions.run(
        inputs = inputs,
        outputs = [apex_output_file],
        executable = ctx.executable._bazel_apexer_wrapper,
        arguments = [args],
        mnemonic = "BazelApexerWrapper",
    )

    return apex_output_file

# See the APEX section in the README on how to use this rule.
def _apex_rule_impl(ctx):
    apex_toolchain = ctx.toolchains["//build/bazel/rules/apex:apex_toolchain_type"].toolchain_info

    apex_content_inputs, bazel_apexer_wrapper_manifest = _prepare_apexer_wrapper_inputs(ctx)
    apex_manifest_pb = _convert_apex_manifest_json_to_pb(ctx, apex_toolchain)

    apex_output_file = _run_apexer(ctx, apex_toolchain, apex_content_inputs, bazel_apexer_wrapper_manifest, apex_manifest_pb)

    files_to_build = depset([apex_output_file])
    return [DefaultInfo(files = files_to_build)]

_apex = rule(
    implementation = _apex_rule_impl,
    attrs = {
        "manifest": attr.label(allow_single_file = [".json"]),
        "android_manifest": attr.label(allow_single_file = [".xml"]),
        "file_contexts": attr.label(allow_single_file = True, mandatory = True),
        "key": attr.label(providers = [ApexKeyInfo]),
        "certificate": attr.label(providers = [AndroidAppCertificateInfo]),
        "min_sdk_version": attr.string(),
        "updatable": attr.bool(default = True),
        "installable": attr.bool(default = True),
        "native_shared_libs": attr.label_list(providers = [ApexCcInfo], aspects = [apex_cc_aspect], cfg = apex_transition),
        "binaries": attr.label_list(providers = [ShBinaryInfo], cfg = apex_transition),
        "prebuilts": attr.label_list(providers = [PrebuiltEtcInfo], cfg = apex_transition),
        # Required to use apex_transition. This is an acknowledgement to the risks of memory bloat when using transitions.
        "_allowlist_function_transition": attr.label(default = "@bazel_tools//tools/allowlists/function_transition_allowlist"),
        "_bazel_apexer_wrapper": attr.label(
            cfg = "host",
            doc = "The apexer wrapper to avoid the problem where symlinks are created inside apex image.",
            executable = True,
            default = "//build/bazel/rules/apex:bazel_apexer_wrapper",
        ),
    },
    toolchains = ["//build/bazel/rules/apex:apex_toolchain_type"],
)

def apex(
        name,
        manifest = "apex_manifest.json",
        android_manifest = None,
        file_contexts = None,
        key = None,
        certificate = None,
        min_sdk_version = None,
        updatable = True,
        installable = True,
        native_shared_libs = [],
        binaries = [],
        prebuilts = [],
        **kwargs):
    "Bazel macro to correspond with the APEX bundle Soong module."

    # If file_contexts is not specified, then use the default from //system/sepolicy/apex.
    # https://cs.android.com/android/platform/superproject/+/master:build/soong/apex/builder.go;l=259-263;drc=b02043b84d86fe1007afef1ff012a2155172215c
    if file_contexts == None:
        file_contexts = "//system/sepolicy/apex:" + name + "-file_contexts"

    _apex(
        name = name,
        manifest = manifest,
        android_manifest = android_manifest,
        file_contexts = file_contexts,
        key = key,
        certificate = certificate,
        min_sdk_version = min_sdk_version,
        updatable = updatable,
        installable = installable,
        native_shared_libs = native_shared_libs,
        binaries = binaries,
        prebuilts = prebuilts,
        **kwargs
    )
