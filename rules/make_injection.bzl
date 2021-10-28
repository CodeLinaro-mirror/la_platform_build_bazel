# A repository rule to run soong_ui --make-mode to provide the Bazel standalone
# build with prebuilts from Make/Soong that Bazel can't build yet.
def _impl(rctx):
    binaries = rctx.attr.binaries
    target_modules = rctx.attr.target_module_files

    build_dir = rctx.path(Label("//:WORKSPACE")).dirname
    soong_ui_bash = str(build_dir) + "/build/soong/soong_ui.bash"
    args = [
        soong_ui_bash,
        "--make-mode",
        "--skip-soong-tests",
    ]
    all_modules = target_modules.keys() + binaries
    args += all_modules

    rctx.report_progress("Building modules with Soong: %s" % str(all_modules))
    out_dir = str(build_dir.dirname) + "/make_injection"
    exec_result = rctx.execute(
        args,
        environment = {
            "OUT_DIR": out_dir,
            # TODO(b/196224107): Make these customizable based on product config inputs.
            "TARGET_PRODUCT": "aosp_arm",
            "TARGET_BUILD_VARIANT": "userdebug",
        },
        quiet = False,  # stream stdout so it shows progress
    )
    if exec_result.return_code != 0:
        fail(exec_result.stderr)

    # Get the explicit list of host binary paths to be exported
    rctx.symlink(out_dir + "/host/linux-x86", "host/linux-x86")
    binary_path_prefix = "host/linux-x86/bin"
    binary_paths = ['"%s/%s"' % (binary_path_prefix, binary) for binary in binaries]

    # Get the explicit list of target installed files to be exported
    rctx.symlink(out_dir + "/target", "target")
    target_path_prefix = "target/product/generic"
    target_paths = []
    for paths in target_modules.values():
        target_paths.extend(['"%s/%s"' % (target_path_prefix, path) for path in paths])

    exports_files = """exports_files([
    %s
])
""" % ",\n    ".join(binary_paths + target_paths)
    rctx.file("BUILD", exports_files)

make_injection_repository = repository_rule(
    implementation = _impl,
    doc = """This rule exposes Soong prebuilts for migrating the build to Bazel.

This rule allows the Bazel build (i.e. b build //bionic/...) to depend on prebuilts from
Soong. A use case is to allow the Bazel build to use prebuilt host tools in the
Bazel rules toolchains without first converting them to Bazel.""",
    attrs = {
        "binaries": attr.string_list(default = [], doc = "A list of host binary modules built for linux-x86."),
        "target_module_files": attr.string_list_dict(default = {}, doc = "A dict of modules to the target files that should be exported."),
    },
)
