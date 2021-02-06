#!/bin/bash
#
# This script rsyncs generated bp2build BUILD files from out/soong/bp2build to
# the top level AOSP source tree.
#
# Write BUILD files in declared packages:  ./build/bazel/scripts/bp2build-sync.sh write
# Remove BUILD files in declared packages: ./build/bazel/scripts/bp2build-sync.sh remove

set -euo pipefail

# Declare packages to be synced here.
#
# TODO: Should be parameterized, but let's hardcode the prioritized packages for
# now.
declare -a packages=(
  "bionic"
)

# We're in <root>/build/bazel/scripts
AOSP_ROOT="$(dirname $0)/../../.."

function write_build_files() {
  for package in ${packages[@]}; do
    echo "Syncing $(dirname $package)"
    rsync -av \
      --include="*/" \
      --include="BUILD.bazel" \
      --exclude="*" \
      "$AOSP_ROOT/out/soong/bp2build/$package" \
      "$AOSP_ROOT/$(dirname $package)"
  done
}

function remove_build_files() {
  pushd $AOSP_ROOT > /dev/null
  echo "Removing BUILD files.."
  for package in ${packages[@]}; do
    find "$package" -type f -name "BUILD.bazel" -exec rm -vf {} \; \
      || echo "No BUILD files found under $package."
  done
  popd > /dev/null
}

function help() {
  cat <<EOF
bp2build-sync.sh: synchronize and delete generated BUILD files.
Usage:
  ./bp2build-sync.sh write -- copies generated BUILD files from out/soong/bp2build
                              to the source tree, for declared packages.
  ./bp2build-sync.sh remove -- remove BUILD files for declared packages and all subpackages.
EOF
}

function run() {
  action=$1; shift

  case $action in
    "write")
      write_build_files
      ;;
    "remove")
      remove_build_files
      ;;
    "help")
      help
      ;;
    *)
      echo "Unknown bp2build-sync action: $action"
      help
      exit 1
  esac

  echo "Done."
}

run $@
