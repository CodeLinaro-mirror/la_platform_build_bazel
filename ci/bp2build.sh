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
build/bazel/scripts/milestone-2/demo.sh generate

# Remove the ninja_build output marker file to communicate to buildbot that this is not a regular Ninja build, and its
# output should not be parsed as such.
rm -f out/ninja_build

# Build targets under bionic/ for various architectures
tools/bazel --max_idle_secs=5 build --config=bp2build --color=no --curses=no --show_progress_rate_limit=5 --platforms //build/bazel/platforms:android_x86 -k //bionic/...
tools/bazel --max_idle_secs=5 build --config=bp2build --color=no --curses=no --show_progress_rate_limit=5 --platforms //build/bazel/platforms:android_x86_64 -k //bionic/...
tools/bazel --max_idle_secs=5 build --config=bp2build --color=no --curses=no --show_progress_rate_limit=5 --platforms //build/bazel/platforms:android_arm -k //bionic/...
tools/bazel --max_idle_secs=5 build --config=bp2build --color=no --curses=no --show_progress_rate_limit=5 --platforms //build/bazel/platforms:android_arm64 -k //bionic/...

# Run tests.
tools/bazel --max_idle_secs=5 test --config=bp2build --color=no --curses=no --show_progress_rate_limit=5 --test_output=errors -k //build/bazel/tests/...
