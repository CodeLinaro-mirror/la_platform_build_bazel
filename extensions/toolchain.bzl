"""Module extension providing repositories for custom toolchains."""

load("@bazel_tools//tools/build_defs/repo:local.bzl", "new_local_repository")
load("@rules_gcs//gcs:repo_rules.bzl", "gcs_archive")
load("//rules:overlay_repository.bzl", "overlay_repository")
load("//toolchains/cc:repository_rules.bzl", "msvc_tools_repository", "windows_sdk_repository", "xcode_tools_repository")

_BAZEL_WINDOWS_URL = "https://releases.bazel.build/9.1.1/rc1/bazel-9.1.1rc1-windows-x86_64.exe"
_BAZEL_WINDOWS_SHA256 = "61b5fd85c4429b2a1633b3de66b1b40b3d83874f88a63f0aba9c0bf1ba069861"

def _windows_test_tools_repo_impl(repo_ctx):
    """Ensures tw.exe and xml.exe exist in @bazel_tools//tools/test for remote Windows test execution."""
    if not repo_ctx.os.name.lower().startswith("windows"):
        test_dir = repo_ctx.path(Label("@bazel_tools//tools/test:BUILD")).dirname
        tw_exe = test_dir.get_child("tw.exe")
        xml_exe = test_dir.get_child("xml.exe")
        if not tw_exe.exists or not xml_exe.exists:
            repo_ctx.download(
                url = _BAZEL_WINDOWS_URL,
                output = "bazel_windows.zip",
                sha256 = _BAZEL_WINDOWS_SHA256,
            )
            python = repo_ctx.which("python3")
            if python:
                repo_ctx.execute([
                    python,
                    "-c",
                    (
                        "import zipfile, shutil, os; " +
                        "d = r'{0}'; " +
                        "st = os.stat(os.path.join(d, 'BUILD')); " +
                        "z = zipfile.ZipFile('bazel_windows.zip'); " +
                        "[shutil.copyfileobj(z.open('embedded_tools/tools/test/' + f), open(os.path.join(d, f), 'wb')) for f in ('tw.exe', 'xml.exe')]; " +
                        "[os.chmod(os.path.join(d, f), 0o755) for f in ('tw.exe', 'xml.exe')]; " +
                        "[os.utime(os.path.join(d, f), (st.st_atime, st.st_mtime)) for f in ('tw.exe', 'xml.exe')]"
                    ).format(test_dir),
                ])
    repo_ctx.file("BUILD.bazel", "exports_files(['defs.bzl'])\n")
    repo_ctx.file("defs.bzl", "WINDOWS_TEST_TOOLS_READY = True\n")

windows_test_tools_repository = repository_rule(
    implementation = _windows_test_tools_repo_impl,
    local = True,
)

def _toolchain_impl(ctx):
    # type: (module_ctx) -> None
    windows_test_tools_repository(name = "windows_test_tools")
    tool_versions = {}  # type: dict[string, string]
    version_file_tag = _get_singleton_tag(ctx.modules, "version_file")
    if version_file_tag:
        tool_versions = json.decode(ctx.read(version_file_tag.label))  # type: dict[string, string]

    clang_tag = _get_singleton_tag(ctx.modules, "clang")
    if clang_tag:
        if clang_tag.version:
            tool_versions["clang"] = clang_tag.version
        if not tool_versions.get("clang"):
            fail("clang version is missing from tag", clang_tag)

        # Repositories that provide the clang compilers
        new_local_repository(
            name = "clang_linux_x64",
            build_file = "//toolchains/cc/linux_clang:clang.BUILD",
            path = "{}/linux-x86/{}".format(clang_tag.root_path, tool_versions["clang"]),
        )
        new_local_repository(
            name = "clang_mac_all",
            build_file = "//toolchains/cc/mac_clang:clang.BUILD",
            path = "{}/darwin-x86/{}".format(clang_tag.root_path, tool_versions["clang"]),
        )
        new_local_repository(
            name = "clang_win_x64",
            build_file = "//toolchains/cc/windows_clang:clang.BUILD",
            path = "{}/windows-x86/{}".format(clang_tag.root_path, tool_versions["clang"]),
        )

        overlay_repository(
            name = "gcc_lib",
            path = "prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.17-4.8",
            not_found_ok = True,
            overlay_files = {"BUILD.bazel": "//toolchains/cc/linux_clang:gcc_lib.BUILD"},
        )

        # Hermetic SDKs
        gcs_archive(
            name = "xcode_tools_hermetic",
            build_file = "//toolchains/cc/mac_clang:xcode.BUILD",
            sha256 = "e1fca4bee5f88bd6d3108e380235860a5a0cb5cec17d664e98ad0c3e58675f77",
            url = "gs://emu-next-bazel/hermetic-xcode/xcode_command_line_tools-16.2-202505191216.zip",
        )
        gcs_archive(
            name = "vctools_hermetic",
            build_file = "//toolchains/cc/windows_clang:vctools.BUILD",
            sha256 = "91e742c5c664aec3e9d9c742077c7319439ffb55be35e68f0232a755e56bb821",
            url = "gs://emu-next-bazel/hermetic-msvc/msvc_tools_14_50_35717_202610121913.zip",
        )
        gcs_archive(
            name = "windows_sdk_hermetic",
            build_file = "//toolchains/cc/windows_clang:sdk.BUILD",
            sha256 = "6af8e86ac2cf13905a0d6dda3e51e2eb72a98d944458b3da42300814c67394f5",
            url = "gs://emu-next-bazel/hermetic-msvc/windows_sdk_10_0_26100_0_202601231845.zip",
        )

        # Host SDKs
        if ctx.os.name.lower().startswith("windows") and ctx.getenv("CC_ALLOW_HOST_SDK", "1") in ("1", "true"):
            msvc_tools_repository(
                name = "vctools",
                build_file = "//toolchains/cc/windows_clang:vctools.BUILD",
            )
            windows_sdk_repository(
                name = "windows_sdk",
                build_file = "//toolchains/cc/windows_clang:sdk.BUILD",
                sdk_path = "C:\\Program Files (x86)\\Windows Kits\\10",
            )
            overlay_repository(
                name = "dism_adk",
                path = "C:\\Program Files (x86)\\Windows Kits\\10\\Assessment and Deployment Kit\\Deployment Tools\\SDKs\\DismApi",
                not_found_ok = True,
                overlay_files = {"BUILD.bazel": "//toolchains/cc/windows_clang:dism_adk.BUILD"},
            )
        else:
            # dummy
            overlay_repository(
                name = "vctools",
                path = "build/bazel/no-such-dir",
                not_found_ok = True,
                overlay_files = {"BUILD.bazel": "//toolchains/cc/windows_clang:vctools.BUILD"},
            )
            overlay_repository(
                name = "windows_sdk",
                path = "build/bazel/no-such-dir",
                not_found_ok = True,
                overlay_files = {"BUILD.bazel": "//toolchains/cc/windows_clang:sdk.BUILD"},
            )
            gcs_archive(
                name = "dism_adk",
                build_file = "//toolchains/cc/windows_clang:dism_adk.BUILD",
                sha256 = "4baf8013556e402fc3c07584ba0ca6f92aedd5a191664b4d813eccc84884edc9",
                url = "gs://emu-next-bazel/hermetic-msvc/windows_11_adk_dismapi_10.1.26100.9457.zip",
            )

        if ctx.os.name.lower().startswith("mac") and ctx.getenv("CC_ALLOW_HOST_SDK", "1") in ("1", "true"):
            xcode_tools_repository(
                name = "xcode_tools",
                build_file = "//toolchains/cc/mac_clang:xcode.BUILD",
                sdk_versions = [
                    "16.2",
                    "16",
                    "15",
                    "26",
                    "",
                ],
            )
        else:
            # dummy
            overlay_repository(
                name = "xcode_tools",
                path = "build/bazel/no-such-dir",
                not_found_ok = True,
                overlay_files = {"BUILD.bazel": "//toolchains/cc/mac_clang:xcode.BUILD"},
            )

    java_tag = _get_singleton_tag(ctx.modules, "java")
    if java_tag:
        if java_tag.version:
            tool_versions["java"] = java_tag.version
        if not tool_versions.get("java"):
            fail("java version is missing from tag", java_tag)

        new_local_repository(
            name = "jdk_linux",
            build_file = "//toolchains/java:linux_jdk.BUILD",
            path = "{}/{}/linux".format(java_tag.root_path, tool_versions["java"]),
        )
        new_local_repository(
            name = "jdk_mac_arm64",
            build_file = "//toolchains/java:mac_jdk.BUILD",
            path = "{}/{}/mac-arm64/Contents/Home".format(java_tag.root_path, tool_versions["java"]),
        )
        new_local_repository(
            name = "jdk_windows",
            build_file = "//toolchains/java:windows_jdk.BUILD",
            path = "{}/{}/win".format(java_tag.root_path, tool_versions["java"]),
        )

    toolchain_hub_files = {
        "cc/linux_clang/BUILD.bazel": "//toolchains/cc/linux_clang:toolchain.BUILD" if clang_tag else None,
        "cc/mac_clang/BUILD.bazel": "//toolchains/cc/mac_clang:toolchain.BUILD" if clang_tag else None,
        "cc/windows_clang/BUILD.bazel": "//toolchains/cc/windows_clang:toolchain.BUILD" if clang_tag else None,
        "java/linux/BUILD.bazel": "//toolchains/java:linux_toolchain.BUILD" if java_tag else None,
        "java/mac_arm64/BUILD.bazel": "//toolchains/java:mac_arm64_toolchain.BUILD" if java_tag else None,
        "java/windows/BUILD.bazel": "//toolchains/java:windows_toolchain.BUILD" if java_tag else None,
        "toolchains/cc/rules.bzl": "//toolchains/cc:rules.bzl",
    }
    overlay_repository(
        name = "toolchain_hub",
        overlay_files = {k: v for k, v in toolchain_hub_files.items() if v},
        overlay_contents = {k: "" for k, v in toolchain_hub_files.items() if not v},
    )

    return ctx.extension_metadata(reproducible = True)

def _get_singleton_tag(modules, tag_class_name):
    for mod in modules:
        if not mod.is_root:
            continue
        tags = getattr(mod.tags, tag_class_name)
        if len(tags) == 1:
            return tags[0]
        elif len(tags) > 1:
            fail("multiple tags defined for", tag_class_name, ": ", tags)
    return None

_clang = tag_class(
    doc = "Hermetic CC toolchain based on android clang and gcc prebuilts.",
    attrs = {
        "root_path": attr.string(doc = "Workspace relative path up to (but excluding) host platform triples", mandatory = True),
        "version": attr.string(doc = "Directory name of the versioned clang toolchain."),
    },
)
_java = tag_class(
    doc = "The Java toolchain based on studio jdk prebuilts.",
    attrs = {
        "root_path": attr.string(doc = "Workspace relative path up to (but excluding) host platform triples", mandatory = True),
        "version": attr.string(doc = "Directory name of the versioned java toolchain."),
    },
)
_version_file = tag_class(
    doc = "A json file defining default toolchain versions.",
    attrs = {
        "label": attr.label(doc = "The label to the file.", allow_single_file = True, mandatory = True),
    },
)
toolchain = module_extension(
    doc = """Import custom toolchains from either the repo or the host.

    Has no effect if called from a submodule. Each tag class can only be called once.
    """,
    implementation = _toolchain_impl,
    tag_classes = {
        "clang": _clang,
        "java": _java,
        "version_file": _version_file,
    },
    os_dependent = True,
)
