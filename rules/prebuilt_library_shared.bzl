def prebuilt_library_shared(
        name,
        shared_library,
        alwayslink = None,
        **kwargs):
    "Bazel macro to correspond with the *_prebuilt_library_shared Soong module types"

    native.cc_import(
        name = name,
        shared_library = shared_library,
        alwayslink = alwayslink,
        **kwargs
    )

    native.cc_import(
        name = name + "_alwayslink",
        shared_library = shared_library,
        alwayslink = True,
        **kwargs
    )
