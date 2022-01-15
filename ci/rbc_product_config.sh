#!/bin/bash -eu
# This script checks that running a build of "nothing" with and without
# RBC_PRODUCT_CONFIG=1 produces the same ninja files.
# It must be passed a list of products as command line arguments to run
# against. The script will exit upon finding the first failing product,
# unless the -k flag is provided.

function die() {
    echo $@ >&2
    exit 1
}

function usage() {
    echo "Usage: $0 [-p] [-b] [-k] [-q] <product> [products...]" >&2
    echo "  -p: Test RBC product configuration. This is implied if -b is not supplied" >&2
    echo "  -b: Test RBC board configuration" >&2
    echo "  -k: Keep going after finding a failing product" >&2
    echo "  -q: Quiet. Suppress all output other than a failure message" >&2
    exit 1
}

board_config=""
product_config=""
while getopts "kqbp" o; do
    case "${o}" in
        k)
            keep_going=true
            ;;
        q)
            quiet=true
            ;;
        b)
            board_config="RBC_BOARD_CONFIG=1"
            ;;
        p)
            product_config="RBC_PRODUCT_CONFIG=1"
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

[[ $# -gt 0 ]] || usage

[[ -n "$board_config" ]] || product_config="RBC_PRODUCT_CONFIG=1"

for arg in $@; do
    [[ "$arg" =~ ^([a-zA-Z0-9_]+)-([a-zA-Z0-9_]+)$ ]] || \
        die "Invalid product name: $arg. Example: aosp_arm64-userdebug"
done

cd "$(readlink -f "$(dirname "$0")"/../../..)"

# Verify that diff will return nonzero on different files
! diff -q <(echo "foo") <(echo "bar") >/dev/null 2>/dev/null || \
    die "Diff does not return nonzero on different files"

mkdir -p out/rbc_ci

function test_product() {
    local product="$1"
    local variant="$2"
    build/soong/soong_ui.bash --make-mode \
        $product_config \
        $board_config \
        TARGET_PRODUCT=$product \
        TARGET_BUILD_VARIANT=$variant \
        nothing || return 1
    cp out/soong/build.ninja out/rbc_ci/build.ninja.rbc || return 1
    cp out/build-${product}.ninja out/rbc_ci/build-product.ninja.rbc || return 1
    cp out/build-${product}-package.ninja out/rbc_ci/build-product-package.ninja.rbc || return 1
    build/soong/soong_ui.bash --make-mode \
        RBC_NO_PRODUCT_GRAPH=1 \
        DISABLE_ARTIFACT_PATH_REQUIREMENTS=t \
        TARGET_PRODUCT=$product \
        TARGET_BUILD_VARIANT=$variant \
        nothing || return 1
    diff -q out/soong/build.ninja out/rbc_ci/build.ninja.rbc || return 1
    diff -q out/build-${product}.ninja out/rbc_ci/build-product.ninja.rbc || return 1
    diff -q out/build-${product}-package.ninja out/rbc_ci/build-product-package.ninja.rbc || return 1
}

declare -A failed_products

for arg in $@; do
    [[ "$arg" =~ ^([a-zA-Z0-9_]+)-([a-zA-Z0-9_]+)$ ]]
    product="${BASH_REMATCH[1]}"
    variant="${BASH_REMATCH[2]}"
    if [[ -n ${quiet+unset} ]]; then
        test_product ${product} ${variant} >&/dev/null || \
            failed_products[${product}-${variant}]=true
    else
        test_product ${product} ${variant} || \
            failed_products[${product}-${variant}]=true
    fi
    [[ -z "${!failed_products[@]}" ]] || [[ -n ${keep_going+unset} ]] || break
done

if [[ -n "${!failed_products[@]}" ]]; then
    echo "Some products produced different ninja files with/without RBC product configuration. Reproduce with:" >&2
    die "build/bazel/ci/rbc_product_config.sh ${!failed_products[@]}"
elif [[ -z ${quiet+unset} ]]; then
    echo "Success!"
fi
