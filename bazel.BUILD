# TODO(b/160567682): Check-in the lunch repository rule to stop hardcoding these.
TARGET_PRODUCT = "aosp_flame"
TARGET_BUILD_VARIANT = "eng"

ninja_graph(
    name = "combined_graph",
    # TODO: Stop hardcoding "out/".
    # TODO: the actual suffix comes from getKatiSuffix, which may not necessarily
    #       just be TARGET_PRODUCT.
    #       https://cs.android.com/android/platform/superproject/+/master:build/soong/ui/build/kati.go;drc=9f43597ff7349c4facd9e338e5b4b277e625e518;l=36
    main = "out/combined-%s.ninja" % TARGET_PRODUCT,
    ninja_srcs = [
        "out/build-%s.ninja" % TARGET_PRODUCT,
        "out/build-%s-package.ninja" % TARGET_PRODUCT,
        "out/soong/build.ninja",
    ],
    output_root = "out",
    output_root_inputs = [
        "soong/.bootstrap/bin/soong_build",
        "soong/.bootstrap/bin/soong_env",
        "soong/.bootstrap/bin/loadplugins",
        "soong/build_number.txt",
        "soong/soong.variables",
        "soong/dexpreopt.config",
        "build_date.txt",
        ".module_paths/Android.mk.list",
        ".module_paths/Android.bp.list",
        ".module_paths/AndroidProducts.mk.list",
        ".module_paths/CleanSpec.mk.list",
        ".module_paths/files.db",
        ".module_paths/OWNERS.list",
        ".module_paths/TEST_MAPPING.list",
        "soong/.bootstrap/bin/gotestmain",
        "soong/.bootstrap/bin/gotestrunner",
        "empty",
    ],
)

ninja_build(
    name = "%s-%s" % (TARGET_PRODUCT, TARGET_BUILD_VARIANT),
    ninja_graph = ":combined_graph",
    output_groups = {
        "droid": ["droid"],
    },
)
