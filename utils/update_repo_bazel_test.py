"""Unit tests for update_repo_bazel."""

import io
from pathlib import Path
import tempfile
import unittest
from unittest import mock

from utils import update_repo_bazel


class UpdateRepoBazelTest(unittest.TestCase):
    def setUp(self) -> None:
        super().setUp()
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)

    def tearDown(self) -> None:
        self.temp_dir.cleanup()
        super().tearDown()

    def _mkdirs(self, *rel_paths: str) -> None:
        for rel in rel_paths:
            (self.root / rel).mkdir(parents=True, exist_ok=True)

    def test_parse_local_repo_paths(self) -> None:
        self._mkdirs(
            "build/bazel",
            "hardware/generic/goldfish",
            "prebuilts/android/android-sdk",
            "prebuilts/gcc/linux-x86",
            "third_party/rust/crates/tempfile",
        )
        show_repo_output = f"""
## @@goldfish_build+:
load("@@bazel_tools//tools/build_defs/repo:local.bzl", "local_repository")
local_repository(
  name = "goldfish_build+",
  path = "{self.root}/build/bazel",
)

## @@root_repo+:
local_repository(
  name = "root_repo+",
  path = "{self.root}",
)

## @@outside_repo+:
local_repository(
  name = "outside_repo+",
  path = "/nonexistent/outside/path",
)

## @@goldfish++local_repository+prebuilt_android_sdk:
local_repository(
  name = "goldfish++local_repository+prebuilt_android_sdk",
  path = "prebuilts/android/android-sdk",
)

## @@goldfish_build++toolchain+gcc_lib:
load("@@goldfish_build+//rules:overlay_repository.bzl", "overlay_repository")
overlay_repository(
  name = "goldfish_build++toolchain+gcc_lib",
  path = "prebuilts/gcc/linux-x86",
)

## @@goldfish_build++toolchain+vctools:
overlay_repository(
  name = "goldfish_build++toolchain+vctools",
  path = "build/bazel/no-such-dir",
)

## @@goldfish_crates++lrc+tempfile:
load("@@goldfish_crates+//:repository_rules.bzl", "patched_new_local_repository")
patched_new_local_repository(
  name = "goldfish_crates++lrc+tempfile",
  path = "third_party/rust/crates/tempfile",
)
"""
        paths = update_repo_bazel.parse_local_repo_paths(
            show_repo_output, self.root
        )
        self.assertEqual(
            paths,
            {
                "build/bazel",
                "prebuilts/android/android-sdk",
                "prebuilts/gcc/linux-x86",
                "third_party/rust/crates/tempfile",
            },
        )

    def test_load_extra_patterns_and_coverage(self) -> None:
        extra_file = self.root / "extra_ignore.txt"
        extra_file.write_text(
            "# Top-level comment\n"
            "\n"
            "prebuilts/clang/host/*  # inline comment\n"
            "third_party/rust/android-crates-io/\n"
            "**/node_modules\n",
            encoding="utf-8",
        )
        patterns = update_repo_bazel.load_extra_patterns(extra_file)
        self.assertEqual(
            patterns,
            [
                "prebuilts/clang/host/*",
                "third_party/rust/android-crates-io",
                "**/node_modules",
            ],
        )

        self.assertTrue(
            update_repo_bazel.is_covered_by_patterns(
                "prebuilts/clang/host/linux-x86/clang-r596125", patterns
            )
        )
        self.assertTrue(
            update_repo_bazel.is_covered_by_patterns(
                "third_party/rust/android-crates-io/crates/serde", patterns
            )
        )
        self.assertTrue(
            update_repo_bazel.is_covered_by_patterns(
                "emulator/ui/node_modules/pkg", patterns
            )
        )
        self.assertFalse(
            update_repo_bazel.is_covered_by_patterns(
                "prebuilts/android/android-sdk", patterns
            )
        )

    def test_shorten_paths_nested_and_immediate_parent_glob(self) -> None:
        self._mkdirs(
            "build/bazel",
            "hardware/generic/goldfish/third_party/rust/crates/aead",
            "hardware/google/aemu",
            "hardware/google/gfxstream",
            "prebuilts/android-emulator-build/common/x264",
            "prebuilts/android-emulator-build/qt",
            "tools/emulator",
            "tools/netsim",
            "tools/repohooks",
        )
        discovered = {
            "build/bazel",
            "hardware/generic/goldfish",
            "hardware/generic/goldfish/third_party/rust/crates",
            "hardware/generic/goldfish/third_party/rust/crates/aead",
            "hardware/google/aemu",
            "hardware/google/gfxstream",
            "prebuilts/android-emulator-build/common",
            "prebuilts/android-emulator-build/common/x264",
            "prebuilts/android-emulator-build/qt",
            "tools/emulator",
            "tools/netsim",
        }
        result = update_repo_bazel.shorten_paths(discovered, [], self.root)
        # - nested paths under goldfish and common are removed
        # - hardware/google/{aemu,gfxstream} collapses to hardware/google/*
        #   (stops at immediate parent; hardware/generic has only 1 subdir)
        # - prebuilts/android-emulator-build/{common,qt} collapses to
        #   prebuilts/android-emulator-build/*
        # - tools/{emulator,netsim} is NOT collapsed because tools/repohooks
        #   is not ignored
        self.assertEqual(
            result,
            [
                "build/bazel",
                "hardware/generic/goldfish",
                "hardware/google/*",
                "prebuilts/android-emulator-build/*",
                "tools/emulator",
                "tools/netsim",
            ],
        )

    def test_shorten_paths_with_extra_patterns(self) -> None:
        self._mkdirs(
            "third_party/rust/android-crates-io/crates/aho-corasick",
            "third_party/rust/android-crates-io/crates/serde",
            "third_party/rust/android-crates-io/crates/unused",
            "third_party/qemu",
        )
        discovered = {
            "third_party/rust/android-crates-io/crates/aho-corasick",
            "third_party/rust/android-crates-io/crates/serde",
            "third_party/qemu",
        }
        extra = [
            "third_party/rust/android-crates-io/crates/*",
            "custom/glob/**",
        ]
        result = update_repo_bazel.shorten_paths(discovered, extra, self.root)
        self.assertEqual(
            result,
            [
                "custom/glob/**",
                "third_party/qemu",
                "third_party/rust/android-crates-io/crates/*",
            ],
        )

    @mock.patch.object(update_repo_bazel, "run_bazel_show_repo")
    def test_main_write_and_diff_modes(
        self, mock_show_repo: mock.MagicMock
    ) -> None:
        self._mkdirs("hardware/google/aemu", "hardware/google/gfxstream")
        mock_show_repo.return_value = """
## @@aemu+:
local_repository(
  name = "aemu+",
  path = "hardware/google/aemu",
)
## @@gfxstream+:
local_repository(
  name = "gfxstream+",
  path = "hardware/google/gfxstream",
)
"""
        repo_file = self.root / "toplevel.REPO.bazel"
        extra_file = self.root / "extra.ignore"
        extra_file.write_text("# comment\nprebuilts/**\n", encoding="utf-8")

        with mock.patch.dict(
            "os.environ",
            {
                "BUILD_WORKING_DIRECTORY": str(self.root),
                "BUILD_WORKSPACE_DIRECTORY": str(self.root),
            },
        ):
            # Diff on non-existent file returns 1 and writes diff + stderr error.
            stdout_buf = io.StringIO()
            stderr_buf = io.StringIO()
            with (
                mock.patch("sys.stdout", stdout_buf),
                mock.patch("sys.stderr", stderr_buf),
            ):
                rc = update_repo_bazel.main(
                    [
                        "--repo_file=toplevel.REPO.bazel",
                        "--extra_ignore_file=extra.ignore",
                        "--diff",
                    ]
                )
            self.assertEqual(rc, 1)
            self.assertIn('+    "hardware/google/*",', stdout_buf.getvalue())
            self.assertIn('+    "prebuilts/**",', stdout_buf.getvalue())
            self.assertIn("is out of date", stderr_buf.getvalue())
            self.assertFalse(repo_file.exists())

            # Write mode creates the file.
            rc = update_repo_bazel.main(
                [
                    "--repo_file=toplevel.REPO.bazel",
                    "--extra_ignore_file=extra.ignore",
                ]
            )
            self.assertEqual(rc, 0)
            self.assertEqual(
                repo_file.read_text(encoding="utf-8"),
                'ignore_directories([\n    "hardware/google/*",\n    "prebuilts/**",\n])\n',
            )

            # Diff mode now returns 0.
            rc = update_repo_bazel.main(
                [
                    "--repo_file=toplevel.REPO.bazel",
                    "--extra_ignore_file=extra.ignore",
                    "--diff",
                ]
            )
            self.assertEqual(rc, 0)


if __name__ == "__main__":
    unittest.main()
