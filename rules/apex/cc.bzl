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

ApexCcInfo = provider(
    "Info needed to use CC targets in APEXes",
    fields = {
        "transitive_shared_libs": "File references to transitive .so libs produced by the CC targets and should be included in the APEX.",
    },
)

def _apex_cc_aspect_impl(target, ctx):
    shared_object_files = []

    # Transitive deps containing shared libraries to be propagated the apex.
    transitive_deps = []

    # TODO(b/207812332): Filter out the ones with stable APIs

    # Exclude the stripped and unstripped so files
    if ctx.rule.kind == "_cc_library_shared_proxy":
        for output_file in target[DefaultInfo].files.to_list():
            if output_file.extension == "so":
                shared_object_files.append(output_file)
        if hasattr(ctx.rule.attr, "shared"):
            transitive_deps.append(ctx.rule.attr.shared)
    elif ctx.rule.kind == "cc_shared_library" and hasattr(ctx.rule.attr, "dynamic_deps"):
        # Propagate along the dynamic_deps edge
        for dep in ctx.rule.attr.dynamic_deps:
            transitive_deps.append(dep)
    elif ctx.rule.kind == "stripped_shared_library" and hasattr(ctx.rule.attr, "src"):
        # Propagate along the src edge
        transitive_deps.append(ctx.rule.attr.src)

    return [
        ApexCcInfo(
            # TODO: Rely on a split transition across arches to happen earlier
            transitive_shared_libs = depset(
                shared_object_files,
                transitive = [dep[ApexCcInfo].transitive_shared_libs for dep in transitive_deps],
            )
        ),
    ]

# This aspect is intended to be applied on a apex.native_shared_libs attribute
apex_cc_aspect = aspect(
    implementation = _apex_cc_aspect_impl,
    attr_aspects = ["dynamic_deps", "shared", "src"],
    # TODO: Have this aspect also propagate along attributes of native_shared_libs?
)
