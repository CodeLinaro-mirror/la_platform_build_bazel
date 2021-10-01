# Rule to support Bazel in copying its output files to the dist dir outside of
# the standard Bazel output user root.

def _copy_to_dist_dir_implementation(ctx):
    # Copy the Python dist tool as binary targets (like this one) cannot use an
    # executable created by another (py_binary) target.
    dist_tool = ctx.actions.declare_file("dist_tool")
    arguments = ["cp", ctx.executable._dist_executable.path, dist_tool.path]
    ctx.actions.run_shell(
        inputs = [ctx.executable._dist_executable],
        outputs = [dist_tool],
        command = " ".join(arguments),
    )

    # Create a manifest of dist files to differentiate them from other runfiles.
    dist_manifest = ctx.actions.declare_file("dist_manifest.txt", sibling = dist_tool)
    dist_manifest_content = ""
    all_dist_files = []
    for f in ctx.attr.data:
        dist_files = f[DefaultInfo].files.to_list()
        all_dist_files += dist_files
        dist_manifest_content += "\n".join([dist_file.short_path for dist_file in dist_files])
    ctx.actions.write(
        output = dist_manifest,
        content = dist_manifest_content,
    )

    # Create the runfiles object.
    runfiles = ctx.runfiles(files = [dist_tool, dist_manifest] + all_dist_files)
    # Needed by the py_binary dist tool.
    runfiles = runfiles.merge(ctx.attr._dist_executable[DefaultInfo].default_runfiles)

    return [DefaultInfo(executable = dist_tool, runfiles = runfiles)]


copy_to_dist_dir = rule(
    implementation = _copy_to_dist_dir_implementation,
    doc = "A simple dist rule to copy files out of Bazel's output directory into a custom location.",
    executable = True,
    attrs = {
        "_dist_executable": attr.label(default = ":dist", executable = True, cfg = "host"),
        "data": attr.label_list(mandatory = True, allow_files = True),
    },
)
