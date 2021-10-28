#!/bin/bash -eux
# Verifies that bp2build-generated BUILD files for bionic (and its dependencies)
# result in successful Bazel builds.
# This verification script is designed to be used for continuous integration
# tests, though may also be used for manual developer verification.

if [[ -z ${DIST_DIR+x} ]]; then
  echo "DIST_DIR not set. Using out/dist. This should only be used for manual developer testing."
  DIST_DIR="out/dist"
fi

# Generate BUILD files into out/soong/bp2build
AOSP_ROOT="$(dirname $0)/../../.."
"${AOSP_ROOT}/build/soong/soong_ui.bash" --make-mode nothing --skip-soong-tests bp2build

# Remove the ninja_build output marker file to communicate to buildbot that this is not a regular Ninja build, and its
# output should not be parsed as such.
rm -f out/ninja_build

# We could create .bazelrc files and use them on buildbots with --bazelrc, but
# it's simpler to use a list for now.
BUILD_FLAGS_LIST=(
  --color=no
  --curses=no
  --show_progress_rate_limit=5
  --config=bp2build
)
BUILD_FLAGS="${BUILD_FLAGS_LIST[@]}"

TEST_FLAGS_LIST=(
  --keep_going
  --test_output=errors
)
TEST_FLAGS="${TEST_FLAGS_LIST[@]}"

# Build targets for various architectures.
BUILD_TARGETS_LIST=(
  //bionic/...
  //build/bazel/...
  //development/sdk/...
  //external/...
  //packages/apps/Music/...
  //packages/apps/QuickSearchBox/...
  //packages/apps/WallpaperPicker/...
  //prebuilts/clang/host/linux-x86:all
  //system/...
)
BUILD_TARGETS="${BUILD_TARGETS_LIST[@]}"
tools/bazel --max_idle_secs=5 build ${BUILD_FLAGS} --platforms //build/bazel/platforms:android_x86 -k ${BUILD_TARGETS}
tools/bazel --max_idle_secs=5 build ${BUILD_FLAGS} --platforms //build/bazel/platforms:android_x86_64 -k ${BUILD_TARGETS}
tools/bazel --max_idle_secs=5 build ${BUILD_FLAGS} --platforms //build/bazel/platforms:android_arm -k ${BUILD_TARGETS}
tools/bazel --max_idle_secs=5 build ${BUILD_FLAGS} --platforms //build/bazel/platforms:android_arm64 -k ${BUILD_TARGETS}

# Run tests.
tools/bazel --max_idle_secs=5 test ${BUILD_FLAGS} ${TEST_FLAGS} //build/bazel/tests/...

# Test copying of some files to $DIST_DIR (set above, or from the CI invocation).
tools/bazel --max_idle_secs=5 run //build/bazel_common_rules/dist:dist_bionic_example --config=bp2build -- --dist_dir="${DIST_DIR}"
if [[ ! -f "${DIST_DIR}/bionic/libc/liblibc_bp2build_cc_library_shared_stripped.so" ]]; then
  >&2 echo "Expected dist dir to exist at ${DIST_DIR} and contain the libc shared library, but the file was not found."
  exit 1
fi
