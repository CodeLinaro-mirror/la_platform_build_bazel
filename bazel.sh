#!/bin/bash

# TODO: Refactor build/make/envsetup.sh to make gettop() available elsewhere
function gettop
{
    local TOPFILE=build/make/core/envsetup.mk
    if [ -n "$TOP" -a -f "$TOP/$TOPFILE" ] ; then
        # The following circumlocution ensures we remove symlinks from TOP.
        (cd "$TOP"; PWD= /bin/pwd)
    else
        if [ -f $TOPFILE ] ; then
            # The following circumlocution (repeated below as well) ensures
            # that we record the true directory name and not one that is
            # faked up with symlink names.
            PWD= /bin/pwd
        else
            local HERE=$PWD
            local T=
            while [ \( ! \( -f $TOPFILE \) \) -a \( "$PWD" != "/" \) ]; do
                \cd ..
                T=`PWD= /bin/pwd -P`
            done
            \cd "$HERE"
            if [ -f "$T/$TOPFILE" ]; then
                echo "$T"
            fi
        fi
    fi
}

# TODO: Refactor build/soong/scripts/microfactory.bash to make getoutdir() available elsewhere
function getoutdir
{
    local out_dir="${OUT_DIR-}"
    if [ -z "${out_dir}" ]; then
        if [ "${OUT_DIR_COMMON_BASE-}" ]; then
            out_dir="${OUT_DIR_COMMON_BASE}/$(basename ${TOP})"
        else
            out_dir="out"
        fi
    fi
    if [[ "${out_dir}" != /* ]]; then
        out_dir="${TOP}/${out_dir}"
    fi
    echo "${out_dir}"
}

TOP="$(gettop)"
if [ ! "$TOP" ]; then
    echo "Couldn't locate the top of the tree.  Try setting TOP."
    return
fi

case $(uname -s) in
    Darwin)
        ANDROID_BAZEL_PATH="${TOP}/prebuilts/bazel/darwin-x86_64/bazel"
        ANDROID_BAZELRC_PATH="${TOP}/build/bazel/darwin.bazelrc"
        ANDROID_BAZEL_JDK_PATH="${TOP}/prebuilts/jdk/jdk11/darwin-x86"
        ;;
    Linux)
        ANDROID_BAZEL_PATH="${TOP}/prebuilts/bazel/linux-x86_64/bazel"
        ANDROID_BAZELRC_PATH="${TOP}/build/bazel/linux.bazelrc"
        ANDROID_BAZEL_JDK_PATH="${TOP}/prebuilts/jdk/jdk11/linux-x86"
        ;;
    *)
        ANDROID_BAZEL_PATH=
        ANDROID_BAZELRC_PATH=
        ANDROID_BAZEL_JDK_PATH=
        ;;
esac

if [ -n "$ANDROID_BAZEL_PATH" -a -f "$ANDROID_BAZEL_PATH" ]; then
    export ANDROID_BAZEL_PATH
else
    echo "Couldn't locate Bazel binary"
    return
fi

if [ -n "$ANDROID_BAZELRC_PATH" -a -f "$ANDROID_BAZELRC_PATH" ]; then
    export ANDROID_BAZELRC_PATH
else
    echo "Couldn't locate bazelrc file for Bazel"
    return
fi

if [ -n "$ANDROID_BAZEL_JDK_PATH" -a -d "$ANDROID_BAZEL_JDK_PATH" ]; then
    export ANDROID_BAZEL_JDK_PATH
else
    echo "Couldn't locate JDK to use for Bazel"
    return
fi

echo "WARNING: Bazel support for the Android Platform is experimental and is undergoing development."
echo "WARNING: Currently, build stability is not guaranteed. Thank you."
echo

"${ANDROID_BAZEL_PATH}" \
  --server_javabase="${ANDROID_BAZEL_JDK_PATH}" \
  --output_user_root="$(getoutdir)/bazel/output_user_root" \
  --bazelrc="${ANDROID_BAZELRC_PATH}" \
  "$@"
