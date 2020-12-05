load(
  "@lunch//:env.bzl",
  "TARGET_PRODUCT",
  "TARGET_BUILD_VARIANT",
  "COMBINED_NINJA",
  "KATI_NINJA",
  "PACKAGE_NINJA",
  "SOONG_NINJA"
)

ninja_graph(
    name = "combined_graph",
    main = COMBINED_NINJA,
    # This assumes that --skip-make is *not* used, so the Kati and Package files exists.
    ninja_srcs = [
        KATI_NINJA,
        PACKAGE_NINJA,
        SOONG_NINJA,
    ],
    # TODO(b/171012031): Stop hardcoding "out/".
    output_root = "out",
    output_root_inputs = [
	# These files are created externally of the Ninja action graph, for
	# example, when Kati parses the product configuration Make files to
	# create soong/soong.variables.
	#
	# Since these aren't created by actions in the ninja_graph .ninja
	# inputs, Bazel will fail with missing inputs while executing
	# ninja_build. output_root_inputs allowlists these files for Bazel to
	# symlink them into the execution root, treating them as source files
	# in the output directory (toplevel_output_directories).
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
