ApexCcInfo = provider(
    "Info needed to use CC targets in APEXes",
    fields={
        "lib_files": "File references to lib .so files produced by the CC target",
        "lib64_files": "File references to lib64 .so files produced by the CC target",
        "lib_arm_files": "File references to lib/arm .so files produced by the CC target",
    })

def _apex_cc_aspect_impl(target, ctx):
    shared_object_files = []
    for output_file in target[DefaultInfo].files.to_list():
        if output_file.extension == "so":
            shared_object_files.append(output_file)

    return [
        ApexCcInfo(
            # TODO: Just return lib_files and rely on a split transition across arches to happen earlier
            lib_files=shared_object_files,
            lib64_files=shared_object_files,
            lib_arm_files=shared_object_files,
        )
    ]

# This aspect is intended to be applied on a apex.native_shared_libs attribute
apex_cc_aspect = aspect(
    implementation = _apex_cc_aspect_impl,
    # TODO: Have this aspect also propagate along attributes of native_shared_libs?
)
