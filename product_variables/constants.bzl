"""Constants for product variables based on information in variable.go"""

# Stored as a map to provide easy checks for existence
_product_variables = {
    "arc": True,
    "binder32bit": True,
    "debuggable": True,
    "enforce_vintf_manifest": True,
    "eng": True,
    "flatten_apex": True,
    "malloc_not_svelte": True,
    "malloc_pattern_fill_contents": True,
    "malloc_zero_contents": True,
    "native_coverage": True,
    "override_rs_driver": True,
    "pdk": True,
    "platform_sdk_version": True,
    "safestack": True,
    "treble_linker_namespaces": True,
    "uml": True,
    "unbundled_build": True,
}

_arch_variant_product_variables = {
    "arc": True,
    "malloc_not_svelte": True,
    "malloc_pattern_fill_contents": True,
    "malloc_zero_contents": True,
    "native_coverage": True,
    "pdk": True,
    "safestack": True,
    "unbundled_build": True,
}

_arch_variant_to_constraints = {
    "arm": "//build/bazel/platforms/arch:arm",
    "arm64": "//build/bazel/platforms/arch:arm64",
    "x86": "//build/bazel/platforms/arch:x86",
    "x86_64": "//build/bazel/platforms/arch:x86_64",
    "android": "//build/bazel/platforms/os:android",
    "darwin": "//build/bazel/platforms/os:darwin",
    "linux": "//build/bazel/platforms/os:linux",
    "linux_bionic": "//build/bazel/platforms/os:linux_bionic",
    "windows": "//build/bazel/platforms/os:windows",
}

constants = struct(
    ProductVariables = _product_variables,
    ArchVariantProductVariables = _arch_variant_product_variables,
    ArchVariantToConstraints = _arch_variant_to_constraints,
)
