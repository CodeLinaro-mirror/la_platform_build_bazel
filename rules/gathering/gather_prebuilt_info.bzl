"""Aspect for gathering PrebuiltPackageInfo providers."""

load("@rules_license//rules:licenses_core.bzl", "should_traverse")
load("//rules/gathering:providers.bzl", "PrebuiltPackageInfo", "TransitivePrebuiltPackageInfo")

def _collect_transitive_package_info(ctx):
    """Collects all transitive PrebuiltPackageInfo providers.

    This uses the should_traverse function from @rules_license to determine
    which attributes to traverse. This is useful because it will exclude
    attributes that are not intended to be package dependencies.

    Returns:
      A list of depsets of PrebuiltPackageInfo providers.
    """
    transitive_pkg_info = []
    attrs = [a for a in dir(ctx.rule.attr)]
    for name in attrs:
        if not should_traverse(ctx, name):
            continue
        a = getattr(ctx.rule.attr, name)

        # If the attribute is a single target, convert to a list for convenience.
        if type(a) != type([]):
            a = [a]
        for dep in a:
            if type(dep) != "Target":
                continue
            if TransitivePrebuiltPackageInfo in dep:
                transitive_pkg_info.append(dep[TransitivePrebuiltPackageInfo].deps)
    return transitive_pkg_info

def _gather_prebuilt_metadata(_, ctx):
    prebuilt_infos = []

    if hasattr(ctx.rule.attr, "package_metadata"):
        package_metadata = ctx.rule.attr.package_metadata
        for dep in package_metadata:
            if PrebuiltPackageInfo in dep:
                prebuilt_infos.append(dep[PrebuiltPackageInfo])

    transitive_pkg_info = _collect_transitive_package_info(ctx)

    return [
        TransitivePrebuiltPackageInfo(
            deps = depset(prebuilt_infos, transitive = transitive_pkg_info),
        ),
    ]

gather_prebuilt_metadata = aspect(
    doc = """Collect all targets that have PrebuiltPackageInfo providers.""",
    implementation = _gather_prebuilt_metadata,
    attr_aspects = ["*"],
    provides = [TransitivePrebuiltPackageInfo],
    apply_to_generating_rules = True,
)
