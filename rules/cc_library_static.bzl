def cc_library_static(
        name,
        srcs = [],
        hdrs = [],
        deps = [],
        copts = [],
        includes = [],
        native_bridge_supported = False, # TODO: not supported yet.
        **kwargs):
    "Bazel macro to correspond with the cc_library_static Soong module."

    # Silently drop these attributes for now:
    # - native_bridge_supported
    native.cc_library(
        name = name,
        srcs = srcs,
        hdrs = hdrs,
        deps = deps,
        copts = copts,
        includes = includes,
        **kwargs
    )

