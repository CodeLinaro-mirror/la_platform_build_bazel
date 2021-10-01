# A repository rule to run soong_ui --make-mode to provide the Bazel standalone
# build with prebuilts from Make/Soong that Bazel can't build yet.
def _impl(rctx):
    modules = rctx.attr.modules

    build_dir = rctx.path(Label("//:WORKSPACE")).dirname
    soong_ui_bash = str(build_dir) + "/build/soong/soong_ui.bash"
    args = [
        soong_ui_bash,
        "--make-mode",
        "--skip-soong-tests",
    ]
    args += modules

    rctx.report_progress("Building modules with Soong: %s" % str(modules))
    out_dir = str(build_dir.dirname) + "/make_injection"
    exec_result = rctx.execute(args, environment = {
        "OUT_DIR": out_dir,
        # TODO(b/196224107): Make these customizable based on product config inputs.
        "TARGET_PRODUCT": "aosp_arm",
        "TARGET_BUILD_VARIANT": "userdebug",
    })
    if exec_result.return_code != 0:
        fail(exec_result.stdout)
        fail(exec_result.stderr)

    rctx.symlink(out_dir + "/host/linux-x86", "host/linux-x86")
    rctx.symlink(out_dir + "/target", "target")
    rctx.file("BUILD", """exports_files(glob(["host/linux-x86/**/*", "target/**/*"]))""")

make_injection_repository = repository_rule(
    implementation = _impl,
    attrs = {
        "modules": attr.string_list(mandatory = True, default = []),
    },
)
