# Copyright 2026 - The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Compact catalog of Android system images (API 24-37), CTS, and CTS-Verifier archives (API 29-37).

This module provides a table-driven registry loaded by `multisource_repo.bzl`.
For archives mirrored from `dl.google.com` to `gs://emu-next-bazel/`, each entry is a
single tuple `(api_level, abi_or_arch, filename, sha256)`, and the `aosp` and `goog`
URLs and BUILD file definitions are derived automatically.
"""

SYSIMG_DL_PREFIX = "https://dl.google.com/android/repository/sys-img/google_apis/"
SYSIMG_GCS_PREFIX = "gs://emu-next-bazel/sys-img/dl.google.com/google_apis/"

XTS_DL_PREFIX = "https://dl.google.com/dl/android/cts/"
XTS_GCS_PREFIX = "gs://emu-next-bazel/xts_releases/"

# Default API 37 (16K page size) system images used by @goldfish.
# Keep the BEGIN/END markers intact for build/bazel/utils/update_sysimage.py.
DEFAULT_SYSTEM_IMAGE_ARCHIVES = {
    # BEGIN android16k-x86_64
    "android16k-x86_64": {
        "abi": "x86_64",
        "aosp": {
            "sha256": "e31eb87a8e7afb279310d2a700a57e2ca460bac117ac14d3fff068472930b5df",
            "url": "https://dl.google.com/android/repository/sys-img/google_apis/x86_64-ps16k-37.2_r05.zip",
        },
        "goog": {
            "sha256": "6205aeb88603725bef23d37c50eabf91d11073cc03a963059234b87691630395",
            "url": "gs://emu-next-bazel/sys-img/sdk_gphone16k_x86_64-userdebug/sdk-repo-linux-system-images-16418371.zip",
        },
    },
    # END android16k-x86_64
    # BEGIN android16k-arm64-v8a
    "android16k-arm64-v8a": {
        "abi": "arm64-v8a",
        "aosp": {
            "sha256": "00681b54fe83facadca2aeddfdda09f1fcbde5fd5e3f4467a63619b011ccf33f",
            "url": "https://dl.google.com/android/repository/sys-img/google_apis/arm64-v8a-ps16k-37.2_r05.zip",
        },
        "goog": {
            "sha256": "7be050d1d592dab2a4945dd1651c7aa978ae160619374a1887c5995aff6dc9ae",
            "url": "gs://emu-next-bazel/sys-img/sdk_gphone16k_arm64-userdebug/sdk-repo-linux-system-images-16418371.zip",
        },
    },
    # END android16k-arm64-v8a
}

# (api_level, abi, filename, sha256)
# Each entry defines `@sysimg-android-<api_level>-<abi>`.
SYSTEM_IMAGE_ARCHIVES = [
    # API 24-28 guests lack CONFIG_VIRTIO_INPUT and exercise the legacy
    # goldfish-events ("qwerty2") input device. dl.google.com ships no
    # google_apis x86_64 image for API 27 (x86 only), so 27 is arm64 only.
    ("24", "x86_64", "x86_64-24_r27.zip", "c59f44a064d702c20fd0a40262cd77d710ab1d36758e00f0c66632482de3c6a2"),
    ("24", "arm64-v8a", "arm64-v8a-24_r29.zip", "9587ca047b0f7334e6fe70380e4f99b3611805e8ab45f46e267d8b858e9a0939"),
    ("25", "x86_64", "x86_64-25_r18.zip", "f4a56029786c0c2ab5e9d33e30be9a9153edb5c3bfaed2f7289bbb84452ffa4a"),
    ("25", "arm64-v8a", "arm64-v8a-25_r20.zip", "08617b7edaa438d062a08bfb387632b33a75f7cabb6729b4803fa3dcef584332"),
    ("26", "x86_64", "x86_64-26_r16.zip", "cd19a220610518b107ba8bca5da16088bb07d5ffedb53106ca9caf9adda06a4d"),
    ("26", "arm64-v8a", "arm64-v8a-26_r03.zip", "d004708c0792c97ded8f7f9f8d341eac9534437b3dcd1b9b4b7f5589b35203d3"),
    ("27", "arm64-v8a", "arm64-v8a-27_r03.zip", "2c2e9ad02de39a5278491dd2e132db36da543e3e12f323d4c4ff43f1726d327f"),
    ("28", "x86_64", "x86_64-28_r11.zip", "57fcdae393eac7dbe4bf854093e18d225ca7bfb9746321de70f01c5faa0c37ed"),
    ("28", "arm64-v8a", "arm64-v8a-28_r02.zip", "b71e924e08b18cb176b3466aa16f4b1f27778017f82223b70eac709a065ed706"),
    ("29", "x86_64", "x86_64-29_r13.zip", "eaf28fa8c267b97a874ffbb8156a1038cc66c1a95167f9b6954a62da2c3091ee"),
    ("29", "arm64-v8a", "arm64-v8a-29_r13.zip", "6f6afee33bd33576e88f5a3dc72ce525da89b31dfe0451f7e857175c10e20091"),
    ("30", "x86_64", "x86_64-30_r16.zip", "daae27654be74ae83a484daea4db2c0c77b4f4ad661a645bd5f36d96ce03e4d5"),
    ("30", "arm64-v8a", "arm64-v8a-30_r16.zip", "097c2808a738ba4c19038b75a085750dd61a7178c0234b14ac5f8270dd8cff54"),
    ("31", "x86_64", "x86_64-31_r14.zip", "7e7081f5784e98dd391ddae52573a75bc1db17a2fd286cb20be46d3eec251f94"),
    ("31", "arm64-v8a", "arm64-v8a-31_r11.zip", "dc2a5037982fad22462e8fa30a767f885fcdcad2ad437d45142d8a01b1094c8d"),
    ("32", "x86_64", "x86_64-32_r08.zip", "2709bcc5a4aa98539b12c2169df606dfe9184fc3b4a0aac7120f319721e63bf1"),
    ("32", "arm64-v8a", "arm64-v8a-32_r08.zip", "8c356d3b819cde8cbd34bed7deec4562f3935da4e46abf4f45b7019e23bca354"),
    ("33", "x86_64", "x86_64-33_r17.zip", "0455f853dcaf23e89b44f810e4b6391e8ef356326ec0e6c25b7f3f9de9ff5659"),
    ("33", "arm64-v8a", "arm64-v8a-33_r17.zip", "792e1fad067aa52c750b2bd0694a7bb2fdcab2942a58cda8f0d1e135b5bc65bc"),
    ("34", "x86_64", "x86_64-34_r14.zip", "783a40134baf4f3012d4464fbe1571b1612a0dbd2e7a44d14bd8328923443833"),
    ("34", "arm64-v8a", "arm64-v8a-34_r14.zip", "bd1c323cbdd3c9dd55dde54588b298d172fd126fe16e127a7bd7aeab6897890a"),
    ("35", "x86_64", "x86_64-35_r09.zip", "c67b9ba0ff5bc0eb6d046871bfa228af14d4d47b02f0cdae94f048e511b7566e"),
    ("35", "arm64-v8a", "arm64-v8a-35_r09.zip", "d2e7c6076e5df54d3677605a324daf9edf813b2808c216bdb1687f6b2b6aed99"),
    ("36", "x86_64", "x86_64-36_r07.zip", "b1bb0769d0bed7698e61f203d7dc9bf6e7c37cd01a39d0d8788a11186bc78160"),
    ("36", "arm64-v8a", "arm64-v8a-36_r07.zip", "fb47d861d6f87230ee0fe70f610d579935ca77f41a0eefbf391595d3dc4b5ee2"),
]

# (api_level, arch, filename, sha256)
# Each entry defines `@cts-android-<api_level>-<arch>` (and `@cts-<arch>` for API 37).
CTS_ARCHIVES = [
    ("29", "x86-64", "android-cts-10_r16-linux_x86-x86.zip", "ece4a19550ded59ad30af4b63ff286c42a1d59e132b77385d3a881fef7903542"),
    ("29", "arm64", "android-cts-10_r16-linux_x86-arm.zip", "ed170503008e57cfa9c7a54439c475f15f2f456c141298ab6c144a73c69ab5b5"),
    ("30", "x86-64", "android-cts-11_r16-linux_x86-x86.zip", "b51b7fe5caba8a58f2ca6021aa4773975d8ca499dbea290738f1ddb09a4aeddb"),
    ("30", "arm64", "android-cts-11_r16-linux_x86-arm.zip", "dc11b86d91de627e515720d80deefbd15edd30f887abc690459f7b312cc709bf"),
    ("31", "x86-64", "android-cts-12_r16-linux_x86-x86.zip", "25623588218bf8c2bbcf36e85d254b875814be73a95f5bc4c31f9224be69c5d4"),
    ("31", "arm64", "android-cts-12_r16-linux_x86-arm.zip", "2ad003fc7add69e0e4c1977e0b006e74aebf58755a50f51af306c84243c0708c"),
    ("32", "x86-64", "android-cts-12.1_r14-linux_x86-x86.zip", "67bf272b65946fa5069acf9e43270aaa01cc958d8eca9d86bf600a3aaf0fb87b"),
    ("32", "arm64", "android-cts-12.1_r14-linux_x86-arm.zip", "3f3519b8bcaf8fde7179a69aeacfd3115bfc0aa4ac048eb9b59fcbe0e7d6169c"),
    ("33", "x86-64", "android-cts-13_r15-linux_x86-x86.zip", "a95c654753af0156f1df8bc2d87cd92d16cd9d4259948cd0d96c2e8e68dfb909"),
    ("33", "arm64", "android-cts-13_r15-linux_x86-arm.zip", "573a965c92a6d3e60090b37d751bcc9cec7e73f629664758d64bfa88458a1c16"),
    ("34", "x86-64", "android-cts-14_r13-linux_x86-x86.zip", "2ade1799402eb5339d845cd25b6e948fa109af053d25e12828a3eff2033572a2"),
    ("34", "arm64", "android-cts-14_r13-linux_x86-arm.zip", "19482ffe8a2919f52c48a22e4edabdc97ac5e37e69c057768b5ffc15cdc2b7d9"),
    ("35", "x86-64", "android-cts-15_r9-linux_x86-x86.zip", "2f568465d2426376bc16983abee814c47b96db408aa95be3c408f874615325fb"),
    ("35", "arm64", "android-cts-15_r9-linux_x86-arm.zip", "08473d6b29eb0a5221b5edb120b53a42c70c2a5eff541158689a4355f83b6c42"),
    ("36", "x86-64", "android-cts-16_r6-linux_x86-x86.zip", "ff0adb4331a03f6ba098f563ecd3de6ed0981222727348387f89f597dde1ce25"),
    ("36", "arm64", "android-cts-16_r6-linux_x86-arm.zip", "44deb3366de5771762c7d16f211d0d8679caab5d2ef55e09048dce91c16db6fb"),
    ("37", "x86-64", "android-cts-17_r1-linux_x86-x86.zip", "e3b784016da9d9fb6aa34eb98835028a5a88fe8e5a40584fd6558b621c7a6306"),
    ("37", "arm64", "android-cts-17_r1-linux_x86-arm.zip", "868ed00224b0e754e928c43299843c2fa3ef04e9d35f3b273c8efecc3186eccc"),
]

# (api_level, arch, filename, sha256)
# Each entry defines `@cts-verifier-android-<api_level>-<arch>` (and `@cts-verifier` for API 37 x86-64).
CTS_VERIFIER_ARCHIVES = [
    ("29", "x86-64", "android-cts-verifier-10_r16-linux_x86-x86.zip", "1b535da7a4c0e14b101778e88e410d81383243fb5928338a1afe387e3a95d5bb"),
    ("29", "arm64", "android-cts-verifier-10_r16-linux_x86-arm.zip", "6d024b551175ad22d9da4c5f5ba04e464f8b6c9e213ac29b0ac3397135072fc1"),
    ("30", "x86-64", "android-cts-verifier-11_r16-linux_x86-x86.zip", "8a209fd78404d3a2a6ff16e639c573636398337e603ff5453f91c457e4ced72a"),
    ("30", "arm64", "android-cts-verifier-11_r16-linux_x86-arm.zip", "fd4bf7d4436844b809887d9c4399624b62184a3c8ca0336cc49b67a1cbf45db0"),
    ("31", "x86-64", "android-cts-verifier-12_r16-linux_x86-x86.zip", "9543f93dbe072e7a426f5096eb3aa390806e9ad674c39a928b1a0001570c9966"),
    ("31", "arm64", "android-cts-verifier-12_r16-linux_x86-arm.zip", "8955f10d7f81e55e7508275577391a4923813f91a8d2fbb85874f6bcdeabc4ab"),
    ("32", "x86-64", "android-cts-verifier-12.1_r14-linux_x86-x86.zip", "b753745454a515d2e6a33869c5a239497f7c6991286396651e3b7f00b8ff4628"),
    ("32", "arm64", "android-cts-verifier-12.1_r14-linux_x86-arm.zip", "c0dda48aed52d3a608d51edb76ddd2a2a4b0027ac0ac3057d34c2a5fdf736d83"),
    ("33", "x86-64", "android-cts-verifier-13_r15-linux_x86-x86.zip", "caa6289db619ec16ea23d47d6ef325f75e49f5e4670199004891b75054c2419e"),
    ("33", "arm64", "android-cts-verifier-13_r15-linux_x86-arm.zip", "c49ac3d4fdbb4e43ee37ed028e3dad07bdb67462c7be6191da5525963406ba77"),
    ("34", "x86-64", "android-cts-verifier-14_r13-linux_x86-x86.zip", "3d50e82e0966453af903fcf7588dbd549a232a9a49c6405f73a6d70a92d2cc72"),
    ("34", "arm64", "android-cts-verifier-14_r13-linux_x86-arm.zip", "67c08c0afbe6fbec258b7295613be7935a138a8f6450b95c650ffbe377015d87"),
    ("35", "x86-64", "android-cts-verifier-15_r9-linux_x86-x86.zip", "4c71b63734523fb8890642017a9dcd707253a718106c8d87ba3efa0415f7e880"),
    ("35", "arm64", "android-cts-verifier-15_r9-linux_x86-arm.zip", "e24bf47352b32fd3a86baaef7839a567fa1ffd7518f624215feae858dc43c03e"),
    ("36", "x86-64", "android-cts-verifier-16_r6-linux_x86-x86.zip", "a3b44065479e6158af5fa96ec85b70a796b78fdb312718d4c3ecbf5f5fe7c76b"),
    ("36", "arm64", "android-cts-verifier-16_r6-linux_x86-arm.zip", "0ab2f98734427cf392dc6fc574ba30003737d981b42db3ae2525b975543e3bb5"),
    ("37", "x86-64", "android-cts-verifier-17_r1-linux_x86-x86.zip", "a47bc094a90be4d05f081c5cc45a9f7fc3429c4ef3cabff440f429f64da68ab9"),
    ("37", "arm64", "android-cts-verifier-17_r1-linux_x86-arm.zip", "c65f92edc0b80e8e3dc3bdbe07fd5c2908a975230716c35c03aeebb1fc8b871e"),
]

_GENERIC_BUILD_CONTENT = """package(default_visibility = ["//visibility:public"])
filegroup(
    name = "all_files",
    srcs = glob(["**/*"]),
)
"""

def _sysimage_build_content(abi):
    return """load(
    "@goldfish_build//toolchains/cc:rules.bzl",
    "sysroot",
)

package(default_visibility = ["//visibility:public"])

sysroot(
    name = "system_image",
    all_files = glob(["{abi}/**"]),
    path = "",
)

sysroot(
    name = "systemimg",
    all_files = ["{abi}/system.img"],
    path = "",
)

filegroup(
    name = "all_files",
    srcs = glob(["**/*"]),
)
""".format(abi = abi)

def get_android_archive_specs():
    """Returns a dict mapping repository name -> archive spec struct.

    Returns:
      A dictionary mapping repository name strings to archive spec structs.
    """
    specs = {}

    for name, cfg in DEFAULT_SYSTEM_IMAGE_ARCHIVES.items():
        for repo_name in [name, "sysimg-android-37-%s" % cfg["abi"]]:
            specs[repo_name] = struct(
                name = repo_name,
                aosp = cfg["aosp"],
                goog = cfg["goog"],
                build_file = None,
                build_file_content = _sysimage_build_content(cfg["abi"]),
                strip_prefix = "",
                patch_strip = 0,
                patches = [],
            )

    for api, abi, filename, sha256 in SYSTEM_IMAGE_ARCHIVES:
        name = "sysimg-android-%s-%s" % (api, abi)
        specs[name] = struct(
            name = name,
            aosp = {"url": SYSIMG_DL_PREFIX + filename, "sha256": sha256},
            goog = {"url": SYSIMG_GCS_PREFIX + filename, "sha256": sha256},
            build_file = None,
            build_file_content = _sysimage_build_content(abi),
            strip_prefix = "",
            patch_strip = 0,
            patches = [],
        )

    for api, arch, filename, sha256 in CTS_ARCHIVES:
        names = ["cts-android-%s-%s" % (api, arch)]
        if api == "37":
            names.append("cts-%s" % arch)
        for name in names:
            specs[name] = struct(
                name = name,
                aosp = {"url": XTS_DL_PREFIX + filename, "sha256": sha256},
                goog = {"url": XTS_GCS_PREFIX + filename, "sha256": sha256},
                build_file = None,
                build_file_content = _GENERIC_BUILD_CONTENT,
                strip_prefix = "",
                patch_strip = 0,
                patches = [],
            )

    for api, arch, filename, sha256 in CTS_VERIFIER_ARCHIVES:
        names = ["cts-verifier-android-%s-%s" % (api, arch)]
        if api == "37" and arch == "x86-64":
            names.append("cts-verifier")
        for name in names:
            specs[name] = struct(
                name = name,
                aosp = {"url": XTS_DL_PREFIX + filename, "sha256": sha256},
                goog = {"url": XTS_GCS_PREFIX + filename, "sha256": sha256},
                build_file = None,
                build_file_content = _GENERIC_BUILD_CONTENT,
                strip_prefix = "",
                patch_strip = 0,
                patches = [],
            )

    return specs
