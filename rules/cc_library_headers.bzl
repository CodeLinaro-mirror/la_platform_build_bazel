load("//build/bazel/rules:cc_library_static.bzl", "cc_library_static")

def cc_library_headers(
        name,
        implementation_deps = [],
        deps = [],
        hdrs = [],
        includes = [],
        native_bridge_supported = False, # TODO: not supported yet.
        **kwargs):
    "Bazel macro to correspond with the cc_library_headers Soong module."

    cc_library_static(
        name = name,
        implementation_deps = implementation_deps,
        deps = deps,
        hdrs = hdrs,
        includes = includes,
        native_bridge_supported = native_bridge_supported,
        # do not automatically add libcrt dependency to header libraries
        use_libcrt = False,
        **kwargs
    )

