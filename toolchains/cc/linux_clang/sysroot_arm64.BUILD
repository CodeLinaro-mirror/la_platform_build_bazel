load("@//build/bazel/toolchains/cc:rules.bzl", "sysroot")

# BUILD file for the Debian Bullseye (glibc 2.31) arm64 sysroot published by Chromium. See
# https://chromium.googlesource.com/chromium/src/+/9754d6acd2be/build/linux/sysroot_scripts/sysroots.json.
#
# Clang derives the include and library search paths from --sysroot, so we only need to
# ship the relevant files into the sandbox. We only expose the glibc/libgcc pieces that we
# link against (including those required by the Rust standard library), so that we do not
# accidentally depend on other libraries in the sysroot.
#
# Note: this was originally added in a rush to support Android CLI on Googlebooks (b/549892162).
# We don't know yet if it's suitable beyond that purpose.
sysroot(
    name = "sysroot",
    all_files = glob(
        ["usr/include/**"],
        # C++ isn't supported yet (we don't expose libstdc++), so hide its headers for now.
        exclude = [
            "usr/include/aarch64-linux-gnu/c++/**",
            "usr/include/c++/**",
        ],
    ) + [
        # Dynamic loader, glibc, and libgcc_s.
        "lib/aarch64-linux-gnu/ld-2.31.so",
        "lib/aarch64-linux-gnu/ld-linux-aarch64.so.1",
        "lib/aarch64-linux-gnu/libc-2.31.so",
        "lib/aarch64-linux-gnu/libc.so.6",
        "lib/aarch64-linux-gnu/libdl-2.31.so",
        "lib/aarch64-linux-gnu/libdl.so.2",
        "lib/aarch64-linux-gnu/libgcc_s.so.1",
        "lib/aarch64-linux-gnu/libm-2.31.so",
        "lib/aarch64-linux-gnu/libm.so.6",
        "lib/aarch64-linux-gnu/libpthread-2.31.so",
        "lib/aarch64-linux-gnu/libpthread.so.0",
        "lib/aarch64-linux-gnu/librt-2.31.so",
        "lib/aarch64-linux-gnu/librt.so.1",
        "lib/aarch64-linux-gnu/libutil-2.31.so",
        "lib/aarch64-linux-gnu/libutil.so.1",
        "lib/ld-linux-aarch64.so.1",
        # C runtime startup objects, and the linker scripts/symlinks used at link time.
        "usr/lib/aarch64-linux-gnu/Scrt1.o",
        "usr/lib/aarch64-linux-gnu/crt1.o",
        "usr/lib/aarch64-linux-gnu/crti.o",
        "usr/lib/aarch64-linux-gnu/crtn.o",
        "usr/lib/aarch64-linux-gnu/libc.so",
        "usr/lib/aarch64-linux-gnu/libc_nonshared.a",
        "usr/lib/aarch64-linux-gnu/libdl.so",
        "usr/lib/aarch64-linux-gnu/libm.so",
        "usr/lib/aarch64-linux-gnu/libpthread.so",
        "usr/lib/aarch64-linux-gnu/librt.so",
        "usr/lib/aarch64-linux-gnu/libutil.so",
        # GCC runtime. Clang also uses this directory to detect the GCC installation.
        "usr/lib/gcc/aarch64-linux-gnu/10/crtbegin.o",
        "usr/lib/gcc/aarch64-linux-gnu/10/crtbeginS.o",
        "usr/lib/gcc/aarch64-linux-gnu/10/crtend.o",
        "usr/lib/gcc/aarch64-linux-gnu/10/crtendS.o",
        "usr/lib/gcc/aarch64-linux-gnu/10/crtfastmath.o",
        "usr/lib/gcc/aarch64-linux-gnu/10/libgcc.a",
        "usr/lib/gcc/aarch64-linux-gnu/10/libgcc_s.so",
    ],
    visibility = ["@//build/bazel/toolchains/cc:__subpackages__"],
)
