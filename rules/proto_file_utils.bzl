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

load("@bazel_skylib//lib:paths.bzl", "paths")

def _generate_and_declare_output_files(
        ctx,
        file_names,
        type_dictionary):
    ret = {}
    for typ in type_dictionary:
        ret[typ] = []

    for name in file_names:
        short_path = name.short_path
        for typ, ext in type_dictionary.items():
            out_name = paths.replace_extension(short_path, ext)
            declared = ctx.actions.declare_file(out_name)
            ret[typ].append(declared)

    return ret

def _generate_proto_action(
        proto_info,
        protoc,
        ctx,
        type_dictionary,
        out_flags,
        plugin_executable = None,
        out_arg = None,
        mnemonic = "ProtoGen"):
    """ Utility function for creating proto_compiler action.

    Args:
      proto_info: ProtoInfo
      protoc: proto compiler executable.
      ctx: context, used for declaring new files only.
      type_dictionary: a dictionary of types to output extensions
      out_flags: protoc output flags
      plugin_executable: plugin executable file
      out_arg: as appropriate, if plugin_executable and out_arg are both supplied, plugin_executable is preferred
      mnemonic: (optional) a string to describe the proto compilation action

    Returns:
      Dictionary with declared files grouped by type from the type_dictionary.
    """
    proto_srcs = proto_info.direct_sources

    outs = _generate_and_declare_output_files(
        ctx,
        proto_srcs,
        type_dictionary,
    )

    transitive_proto_srcs = proto_info.transitive_imports

    tools = []
    dir_out = ctx.bin_dir.path + "/" + ctx.label.package
    args = ctx.actions.args()
    if plugin_executable:
        tools.add(plugin_executable)
        args.add_all(["--plugin=protoc-gen-PLUGIN=" , plugin_executable])
        args.add("--PLUGIN_out=" + ",".join(out_flags) + ":" + dir_out)
    else:
        args.add("{}={}:{}".format(out_arg, ",".join(out_flags), dir_out))

    args.add_all(["-I", proto_info.proto_source_root])
    args.add_all(["-I{0}={1}".format(f.short_path, f.path) for f in transitive_proto_srcs.to_list()])
    args.add_all([f.short_path for f in proto_srcs])

    inputs = depset(
        direct = proto_srcs,
        transitive = [transitive_proto_srcs],
    )

    outputs = []
    for out_files in outs.values():
        outputs.extend(out_files)

    ctx.actions.run(
        inputs = inputs,
        executable = protoc,
        tools = tools,
        outputs = outputs,
        arguments = [args],
        mnemonic = mnemonic,
    )
    return outs

proto_file_utils = struct(
    generate_proto_action = _generate_proto_action,
)
