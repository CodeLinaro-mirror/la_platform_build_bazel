load(":apex_key.bzl", "ApexKeyInfo")
load(":prebuilt_etc.bzl", "PrebuiltEtcInfo")
load(":android_app_certificate.bzl", "AndroidAppCertificateInfo")
load("//build/bazel/rules/apex:transition.bzl", "apex_transition")
load("//build/bazel/rules/apex:cc.bzl", "apex_cc_aspect", "ApexCcInfo")

# Create input dir for the APEX filesystem image (as a tree artifact).
def _prepare_input_dir(ctx):
    image_apex_dir = "image.apex"
    input_dir = ctx.actions.declare_directory(image_apex_dir)

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

        apex_manifest[(directory,filename)] = prebuilt_etc_info.src

    bazel_inputs = []

    # Used for creating canned_fs_config, since every file and dir in the APEX are represented
    # by an entry in the fs_config.
    apex_subdirs = []

    apex_filepaths = []
    shell_commands = []
    for (apex_dirname, apex_basename), bazel_out_file in apex_manifest.items():
      bazel_inputs.append(bazel_out_file)
      apex_filepath = "/".join([apex_dirname, apex_basename])
      apex_filepaths.append(apex_filepath)
      apex_subdirs.append(apex_dirname)

      # Add a shell command to make the APEX image subdirectory
      full_apex_dirname = "/".join([input_dir.path, apex_dirname])
      shell_commands.append("mkdir -p %s" % (full_apex_dirname))

      # Add a shell command to copy the Bazel built lib into the APEX image subdirectory
      full_apex_filepath = "/".join([input_dir.path, apex_filepath])
      shell_commands.append("cp -f %s %s" % (bazel_out_file.path, full_apex_filepath))

    shell_command_string = " && ".join(shell_commands)

    ctx.actions.run_shell(
        inputs = bazel_inputs,
        outputs = [input_dir],
        mnemonic = "PrepareApexInputDir",
        command = shell_command_string,
    )

    # Make sure subdirs are unique (Starlark doesn't support sets, so use a map hack)
    apex_subdirs_set = {}
    for d in apex_subdirs:
      apex_subdirs_set[d] = True

      # Make sure all the parent dirs of the current subdir are in the set, too
      dirs = d.split("/")
      for i in range(0, len(dirs)):
        apex_subdirs_set["/".join(dirs[:i])] = True

    return input_dir, apex_subdirs_set.keys(), apex_filepaths

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
            "-o", apex_manifest_pb.path
        ],
        mnemonic = "ConvApexManifest"
    )

    return apex_manifest_pb


# Generate filesystem config. This encodes the filemode, uid, and gid of each
# file in the APEX, including apex_manifest.json and apex_manifest.pb.
#
# NOTE: every file must have an entry.
def _generate_canned_fs_config(ctx, dirs, filepaths):
    canned_fs_config = ctx.actions.declare_file("canned_fs_config")
    config_lines = []
    config_lines += ["/ 1000 1000 0755"]
    config_lines += ["/apex_manifest.json 1000 1000 0644"]
    config_lines += ["/apex_manifest.pb 1000 1000 0644"]
    config_lines += ["/" + filepath + " 1000 1000 0644" for filepath in filepaths]
    config_lines += ["/" + d + " 0 2000 0755" for d in dirs]
    ctx.actions.write(canned_fs_config, "\n".join(config_lines))
    return canned_fs_config

# apexer - generate the APEX file.
def _run_apexer(ctx, apex_toolchain, input_dir, apex_manifest_pb, canned_fs_config):
    # Inputs
    file_contexts = ctx.file.file_contexts
    apex_key_info = ctx.attr.key[ApexKeyInfo]
    privkey = apex_key_info.private_key
    pubkey = apex_key_info.public_key
    android_jar = apex_toolchain.android_jar
    android_manifest = ctx.file.android_manifest

    # Outputs
    apex_output = ctx.actions.declare_file(ctx.attr.name + ".apex")

    # Arguments
    args = ctx.actions.args()
    args.add("--verbose")
    args.add("--force")
    args.add("--include_build_info")
    args.add_all(["--manifest", apex_manifest_pb.path])
    args.add_all(["--file_contexts", file_contexts.path])
    args.add_all(["--canned_fs_config", canned_fs_config.path])
    args.add_all(["--key", privkey.path])
    args.add_all(["--pubkey", pubkey.path])
    args.add_all(["--payload_type", "image"])
    args.add_all(["--target_sdk_version", "10000"])
    args.add_all(["--min_sdk_version", ctx.attr.min_sdk_version])
    args.add_all(["--payload_fs_type", "ext4"])

    if android_manifest != None:
        args.add_all(["--android_manifest", android_manifest.path])

    # Input dir
    args.add(input_dir.path)
    # Output APEX
    args.add(apex_output.path)

    inputs = [
            input_dir,
            apex_manifest_pb,
            file_contexts,
            canned_fs_config,
            privkey,
            pubkey,
            android_jar,
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
        outputs = [apex_output],
        executable = apex_toolchain.apexer,
        arguments = [args],
        mnemonic = "Apexer",
        env = {
            "APEXER_TOOL_PATH": apex_toolchain.apexer.dirname,
        },
    )

    return apex_output


# See the APEX section in the README on how to use this rule.
def _apex_rule_impl(ctx):
    apex_toolchain = ctx.toolchains["//build/bazel/rules/apex:apex_toolchain_type"].toolchain_info

    input_dir, apex_subdirs, apex_filepaths = _prepare_input_dir(ctx)
    apex_manifest_pb = _convert_apex_manifest_json_to_pb(ctx, apex_toolchain)
    canned_fs_config = _generate_canned_fs_config(ctx, apex_subdirs, apex_filepaths)

    apex_output = _run_apexer(ctx, apex_toolchain, input_dir, apex_manifest_pb, canned_fs_config)

    files_to_build = depset([apex_output])
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
        "binaries": attr.label_list(cfg = apex_transition),
        "prebuilts": attr.label_list(providers = [PrebuiltEtcInfo], cfg = apex_transition),
        # Required to use apex_transition. This is an acknowledgement to the risks of memory bloat when using transitions.
        "_allowlist_function_transition": attr.label(default = "@bazel_tools//tools/allowlists/function_transition_allowlist"),
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
        **kwargs,
    )
