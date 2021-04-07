def cc_library_headers(
        name,
        deps = [],
        hdrs = [],
        includes = [],
        native_bridge_supported = False, # TODO: not supported yet.
        **kwargs):
    "Bazel macro to correspond with the cc_library_headers Soong module."

    # Silently drop these attributes for now:
    # - native_bridge_supported
    native.cc_library(
        name = name,
        deps = deps,
        hdrs = hdrs,
        includes = includes,
        **kwargs
    )

