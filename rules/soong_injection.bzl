def _impl(rctx):
    rctx.file("WORKSPACE", "")
    build_dir = str(rctx.path(Label("//:BUILD")).dirname.dirname)
    soong_injection_dir = build_dir + "/soong_injection"
    rctx.symlink(soong_injection_dir + "/mixed_builds", "mixed_builds")
    rctx.symlink(soong_injection_dir + "/cc_toolchain", "cc_toolchain")
    rctx.symlink(soong_injection_dir + "/product_config", "product_config")
    rctx.symlink(soong_injection_dir + "/module_name_to_label", "module_name_to_label")

soong_injection_repository = repository_rule(
    implementation = _impl,
)
