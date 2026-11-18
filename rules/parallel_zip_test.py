# Copyright 2026 The Android Open Source Project
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
"""Unit tests for parallel_zip archive creation."""

import os
from pathlib import Path
import shutil
import stat
import tempfile
import unittest
import zipfile

try:
    from build.bazel.rules import parallel_zip
except ImportError:
    import parallel_zip


class ParallelZipStoredStreamTest(unittest.TestCase):
    """Tests for zero-staging direct ZIP streaming under compression_level = 0."""

    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        self.output_zip = self.root / "output.zip"

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_empty_manifest_creates_valid_zip(self):
        manifest = []
        parallel_zip.create_zip_stored(
            output_path=self.output_zip,
            entries=manifest,
            dir_prefix="/",
            default_mode=0o555,
            timestamp=parallel_zip.DEFAULT_EPOCH,
        )
        self.assertTrue(self.output_zip.exists())
        with zipfile.ZipFile(self.output_zip, "r") as zf:
            self.assertEqual(len(zf.infolist()), 0)

    def test_regular_files_streaming_and_permissions(self):
        file1 = self.root / "bin1.bin"
        file1.write_bytes(b"HELLO_WORLD_BINARY")
        file2 = self.root / "data.txt"
        file2.write_bytes(b"SOME_TEXT_DATA")

        manifest = [
            {"type": "file", "src": str(file1), "dest": "bin/bin1", "mode": "0755"},
            {"type": "file", "src": str(file2), "dest": "share/data.txt", "mode": "0644"},
        ]

        parallel_zip.create_zip_stored(
            output_path=self.output_zip,
            entries=manifest,
            dir_prefix="emulator",
            default_mode=0o555,
            timestamp=1234567890,
        )

        with zipfile.ZipFile(self.output_zip, "r") as zf:
            names = zf.namelist()
            self.assertEqual(

                names,
                [
                    "emulator/",
                    "emulator/bin/",
                    "emulator/bin/bin1",
                    "emulator/share/",
                    "emulator/share/data.txt",
                ],
            )


            self.assertEqual(zf.read("emulator/bin/bin1"), b"HELLO_WORLD_BINARY")
            self.assertEqual(zf.read("emulator/share/data.txt"), b"SOME_TEXT_DATA")

            info1 = zf.getinfo("emulator/bin/bin1")
            self.assertEqual(info1.create_system, 3)
            mode1 = (info1.external_attr >> 16) & 0o7777
            self.assertEqual(mode1, 0o755)

            info2 = zf.getinfo("emulator/share/data.txt")
            self.assertEqual(info2.create_system, 3)
            mode2 = (info2.external_attr >> 16) & 0o7777
            self.assertEqual(mode2, 0o644)

    def test_directory_entries_retain_trailing_slash(self):
        manifest = [
            {"type": "dir", "dest": "empty_folder", "mode": "0755"},
            {"type": "dir", "dest": "nested/folder/", "mode": "0755"},
        ]

        parallel_zip.create_zip_stored(
            output_path=self.output_zip,
            entries=manifest,
            dir_prefix="/",
            default_mode=0o755,
            timestamp=parallel_zip.DEFAULT_EPOCH,
        )

        with zipfile.ZipFile(self.output_zip, "r") as zf:
            names = zf.namelist()
            self.assertIn("empty_folder/", names)
            self.assertIn("nested/folder/", names)
            for name in names:
                info = zf.getinfo(name)
                self.assertTrue(info.is_dir())
                self.assertEqual(info.create_system, 3)
                mode = stat.S_IFMT(info.external_attr >> 16)
                self.assertEqual(mode, stat.S_IFDIR)

    def test_symlink_entry_in_memory(self):
        manifest = [
            {
                "type": "symlink",
                "src": "libvulkan.so.1",
                "dest": "lib64/libvulkan.so",
            }
        ]

        parallel_zip.create_zip_stored(
            output_path=self.output_zip,
            entries=manifest,
            dir_prefix="emulator",
            default_mode=0o755,
            timestamp=parallel_zip.DEFAULT_EPOCH,
        )

        with zipfile.ZipFile(self.output_zip, "r") as zf:
            info = zf.getinfo("emulator/lib64/libvulkan.so")
            self.assertEqual(info.create_system, 3)
            file_type = stat.S_IFMT(info.external_attr >> 16)
            self.assertEqual(file_type, stat.S_IFLNK)
            payload = zf.read("emulator/lib64/libvulkan.so").decode("utf-8")
            self.assertEqual(payload, "libvulkan.so.1")

    def test_manifest_deduplication_overwrite(self):
        old_file = self.root / "old.txt"
        old_file.write_bytes(b"OLD_VERSION")
        new_file = self.root / "new.txt"
        new_file.write_bytes(b"NEW_VERSION")

        manifest = [
            {"type": "file", "src": str(old_file), "dest": "common.txt", "mode": "0644"},
            {"type": "file", "src": str(new_file), "dest": "common.txt", "mode": "0755"},
        ]

        parallel_zip.create_zip_stored(
            output_path=self.output_zip,
            entries=manifest,
            dir_prefix="/",
            default_mode=0o555,
            timestamp=parallel_zip.DEFAULT_EPOCH,
        )

        with zipfile.ZipFile(self.output_zip, "r") as zf:
            self.assertEqual(zf.namelist(), ["common.txt"])
            self.assertEqual(zf.read("common.txt"), b"NEW_VERSION")
            info = zf.getinfo("common.txt")
            self.assertEqual((info.external_attr >> 16) & 0o7777, 0o755)

    def test_tree_expansion_and_sorting(self):
        tree_dir = self.root / "mytree"
        tree_dir.mkdir(parents=True)
        (tree_dir / "sub").mkdir()
        (tree_dir / "sub" / "file_b.txt").write_bytes(b"FILE_B")
        (tree_dir / "file_a.txt").write_bytes(b"FILE_A")

        manifest = [
            {"type": "tree", "src": str(tree_dir), "dest": "assets", "mode": "0644"},
        ]

        parallel_zip.create_zip_stored(
            output_path=self.output_zip,
            entries=manifest,
            dir_prefix="/",
            default_mode=0o555,
            timestamp=parallel_zip.DEFAULT_EPOCH,
        )

        extract_dir = self.root / "extracted"
        extract_dir.mkdir(parents=True)
        try:
            with zipfile.ZipFile(self.output_zip, "r") as zf:
                names = zf.namelist()
                self.assertEqual(
                    names,
                    ["assets/", "assets/file_a.txt", "assets/sub/", "assets/sub/file_b.txt"],
                )
                for name in names:
                    info = zf.getinfo(name)
                    mode = (info.external_attr >> 16) & 0o7777
                    if name.endswith("/"):
                        self.assertEqual(
                            mode,
                            0o755,
                            f"Directory {name} should have 0755 permissions, got {oct(mode)}",
                        )
                    else:
                        self.assertEqual(
                            mode,
                            0o644,
                            f"File {name} should have 0644 permissions, got {oct(mode)}",
                        )
                    target = zf.extract(info, extract_dir)
                    if mode and os.name == "posix":
                        os.chmod(target, mode)
        finally:
            if os.name == "posix":
                for p in extract_dir.rglob("*"):
                    if p.is_dir():
                        p.chmod(0o755)
                extract_dir.chmod(0o755)


    def test_tree_preserves_intra_tree_symlinks_and_dereferences_external(self):
        if os.name != "posix":
            return
        external_file = self.root / "external_execroot_bin.txt"
        external_file.write_bytes(b"EXTERNAL_BYTES")

        tree_dir = self.root / "App.framework"
        (tree_dir / "Resources").mkdir(parents=True)
        (tree_dir / "Resources" / "täst_中文_🚀.txt").write_bytes(b"UTF8_RESOURCE")
        (tree_dir / "Versions" / "A").mkdir(parents=True)
        (tree_dir / "Versions" / "A" / "App").write_bytes(b"MACH_O_BINARY")
        (tree_dir / "Versions" / "Current").symlink_to("A")
        (tree_dir / "App").symlink_to("Versions/Current/App")
        (tree_dir / "sandbox_input").symlink_to(external_file)

        manifest = [
            {"type": "tree", "src": str(tree_dir), "dest": "App.framework", "mode": "0755"},
        ]

        parallel_zip.create_zip_stored(
            output_path=self.output_zip,
            entries=manifest,
            dir_prefix="emulator",
            default_mode=0o555,
            timestamp=parallel_zip.DEFAULT_EPOCH,
        )

        with zipfile.ZipFile(self.output_zip, "r") as zf:
            self.assertEqual(
                zf.namelist(),
                [
                    "emulator/",
                    "emulator/App.framework/",
                    "emulator/App.framework/App",
                    "emulator/App.framework/Resources/",
                    "emulator/App.framework/Resources/täst_中文_🚀.txt",
                    "emulator/App.framework/Versions/",
                    "emulator/App.framework/Versions/A/",
                    "emulator/App.framework/Versions/A/App",
                    "emulator/App.framework/Versions/Current",
                    "emulator/App.framework/sandbox_input",
                ],
            )
            self.assertEqual(
                zf.read("emulator/App.framework/Resources/täst_中文_🚀.txt"),
                b"UTF8_RESOURCE",
            )
            current_info = zf.getinfo("emulator/App.framework/Versions/Current")
            self.assertEqual(stat.S_IFMT(current_info.external_attr >> 16), stat.S_IFLNK)
            self.assertEqual(zf.read("emulator/App.framework/Versions/Current"), b"A")

            app_info = zf.getinfo("emulator/App.framework/App")
            self.assertEqual(stat.S_IFMT(app_info.external_attr >> 16), stat.S_IFLNK)
            self.assertEqual(
                zf.read("emulator/App.framework/App"),
                b"Versions/Current/App",
            )

            ext_info = zf.getinfo("emulator/App.framework/sandbox_input")
            self.assertEqual(stat.S_IFMT(ext_info.external_attr >> 16), stat.S_IFREG)
            self.assertEqual(zf.read("emulator/App.framework/sandbox_input"), b"EXTERNAL_BYTES")

    def test_tree_unwraps_bazel_sandbox_symlink_forest_for_directory_symlinks(self):
        if os.name != "posix":
            return
        rel_tree = Path("bazel-out/darwin_arm64-opt/bin/App.framework")
        real_tree = self.root / "execroot" / "_main" / rel_tree
        (real_tree / "Versions" / "A" / "Resources").mkdir(parents=True)
        (real_tree / "Versions" / "A" / "App").write_bytes(b"MACH_O_BINARY")
        (real_tree / "Versions" / "A" / "Resources" / "Info.plist").write_bytes(b"PLIST")
        (real_tree / "Versions" / "Current").symlink_to("A")
        (real_tree / "Resources").symlink_to("Versions/Current/Resources")
        (real_tree / "App").symlink_to("Versions/Current/App")

        # Simulate Bazel darwin-sandbox / linux-sandbox TreeArtifact materialization:
        # directory symlinks become real directories populated with absolute leaf symlinks.
        sandbox_root = self.root / "sandbox" / "darwin-sandbox" / "1" / "execroot" / "_main"
        sandbox_tree = sandbox_root / rel_tree
        (sandbox_tree / "Versions" / "A" / "Resources").mkdir(parents=True)
        (sandbox_tree / "Versions" / "Current" / "Resources").mkdir(parents=True)
        (sandbox_tree / "Resources").mkdir(parents=True)
        for rel_leaf in [
            "App",
            "Resources/Info.plist",
            "Versions/A/App",
            "Versions/A/Resources/Info.plist",
            "Versions/Current/App",
            "Versions/Current/Resources/Info.plist",
        ]:
            (sandbox_tree / rel_leaf).symlink_to(real_tree / rel_leaf)

        prev_cwd = os.getcwd()
        os.chdir(sandbox_root)
        try:
            manifest = [
                {"type": "tree", "src": rel_tree.as_posix(), "dest": "App.framework", "mode": "0755"},
            ]
            parallel_zip.create_zip_stored(
                output_path=self.output_zip,
                entries=manifest,
                dir_prefix="emulator",
                default_mode=0o555,
                timestamp=parallel_zip.DEFAULT_EPOCH,
            )
        finally:
            os.chdir(prev_cwd)

        with zipfile.ZipFile(self.output_zip, "r") as zf:
            self.assertEqual(
                zf.namelist(),
                [
                    "emulator/",
                    "emulator/App.framework/",
                    "emulator/App.framework/App",
                    "emulator/App.framework/Resources",
                    "emulator/App.framework/Versions/",
                    "emulator/App.framework/Versions/A/",
                    "emulator/App.framework/Versions/A/App",
                    "emulator/App.framework/Versions/A/Resources/",
                    "emulator/App.framework/Versions/A/Resources/Info.plist",
                    "emulator/App.framework/Versions/Current",
                ],
            )
            for link_entry, expected_target in [
                ("emulator/App.framework/App", b"Versions/Current/App"),
                ("emulator/App.framework/Resources", b"Versions/Current/Resources"),
                ("emulator/App.framework/Versions/Current", b"A"),
            ]:
                info = zf.getinfo(link_entry)
                self.assertEqual(stat.S_IFMT(info.external_attr >> 16), stat.S_IFLNK)
                self.assertEqual(zf.read(link_entry), expected_target)

    def test_deterministic_utc_timestamp(self):
        file1 = self.root / "file1.txt"
        file1.write_bytes(b"CONTENT")

        manifest = [{"type": "file", "src": str(file1), "dest": "file1.txt"}]

        parallel_zip.create_zip_stored(
            output_path=self.output_zip,
            entries=manifest,
            dir_prefix="/",
            default_mode=0o555,
            timestamp=parallel_zip.DEFAULT_EPOCH,
        )

        with zipfile.ZipFile(self.output_zip, "r") as zf:
            info = zf.getinfo("file1.txt")
            self.assertEqual(info.date_time, (1980, 1, 1, 0, 0, 0))


def _find_sevenzip() -> Path:
    srcdir = os.environ.get("TEST_SRCDIR")
    if srcdir:
        for p in Path(srcdir).rglob("7za*"):
            if p.is_file() and os.access(p, os.X_OK):
                return p
    which = shutil.which("7za")
    if which:
        return Path(which)
    raise FileNotFoundError("7za executable not found in test environment")


class ParallelZipDeflatedTest(unittest.TestCase):
    """Tests for zero-staging 7-Zip path-mapping listfiles under compression_level > 0."""

    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        self.output_zip = self.root / "output_deflated.zip"
        self.sevenzip_bin = _find_sevenzip()

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_empty_manifest_creates_valid_zip(self):
        manifest = []
        parallel_zip.create_zip_deflated(
            sevenzip_bin=self.sevenzip_bin,
            output_path=self.output_zip,
            entries=manifest,
            dir_prefix="/",
            default_mode=0o555,
            timestamp=parallel_zip.DEFAULT_EPOCH,
            compression_args=["-mm=Deflate", "-mx=6"],
        )
        self.assertTrue(self.output_zip.exists())
        with zipfile.ZipFile(self.output_zip, "r") as zf:
            self.assertEqual(len(zf.infolist()), 0)

    def test_deflated_regular_files_streaming_and_permissions(self):
        file1 = self.root / "bin1.bin"
        file1.write_bytes(b"HELLO_WORLD_BINARY")
        file2 = self.root / "data.txt"
        file2.write_bytes(b"SOME_TEXT_DATA")

        manifest = [
            {"type": "file", "src": str(file1), "dest": "bin/bin1", "mode": "0755"},
            {"type": "file", "src": str(file2), "dest": "share/data.txt", "mode": "0644"},
        ]

        parallel_zip.create_zip_deflated(
            sevenzip_bin=self.sevenzip_bin,
            output_path=self.output_zip,
            entries=manifest,
            dir_prefix="emulator",
            default_mode=0o555,
            timestamp=parallel_zip.DEFAULT_EPOCH,
            compression_args=["-mm=Deflate", "-mx=6"],
        )

        with zipfile.ZipFile(self.output_zip, "r") as zf:
            names = zf.namelist()
            self.assertEqual(
                names,
                [
                    "emulator/",
                    "emulator/bin/",
                    "emulator/bin/bin1",
                    "emulator/share/",
                    "emulator/share/data.txt",
                ],
            )
            self.assertEqual(zf.read("emulator/bin/bin1"), b"HELLO_WORLD_BINARY")
            self.assertEqual(zf.read("emulator/share/data.txt"), b"SOME_TEXT_DATA")

            info1 = zf.getinfo("emulator/bin/bin1")
            self.assertEqual(info1.create_system, 3)
            self.assertEqual((info1.external_attr >> 16) & 0o7777, 0o755)

            info2 = zf.getinfo("emulator/share/data.txt")
            self.assertEqual(info2.create_system, 3)
            self.assertEqual((info2.external_attr >> 16) & 0o7777, 0o644)

    def test_deflated_directory_entries_trailing_slash(self):
        manifest = [
            {"type": "dir", "dest": "empty_folder", "mode": "0755"},
            {"type": "dir", "dest": "nested/folder/", "mode": "0755"},
        ]

        parallel_zip.create_zip_deflated(
            sevenzip_bin=self.sevenzip_bin,
            output_path=self.output_zip,
            entries=manifest,
            dir_prefix="/",
            default_mode=0o755,
            timestamp=parallel_zip.DEFAULT_EPOCH,
            compression_args=["-mm=Deflate", "-mx=6"],
        )

        with zipfile.ZipFile(self.output_zip, "r") as zf:
            names = zf.namelist()
            self.assertIn("empty_folder/", names)
            self.assertIn("nested/folder/", names)
            for name in names:
                info = zf.getinfo(name)
                self.assertTrue(info.is_dir())
                self.assertEqual(info.create_system, 3)
                mode = stat.S_IFMT(info.external_attr >> 16)
                self.assertEqual(mode, stat.S_IFDIR)

    def test_deflated_symlink_entry(self):
        manifest = [
            {
                "type": "symlink",
                "src": "libvulkan.so.1",
                "dest": "lib64/libvulkan.so",
                "mode": "0777",
            }
        ]

        parallel_zip.create_zip_deflated(
            sevenzip_bin=self.sevenzip_bin,
            output_path=self.output_zip,
            entries=manifest,
            dir_prefix="emulator",
            default_mode=0o755,
            timestamp=parallel_zip.DEFAULT_EPOCH,
            compression_args=["-mm=Deflate", "-mx=6"],
        )

        with zipfile.ZipFile(self.output_zip, "r") as zf:
            info = zf.getinfo("emulator/lib64/libvulkan.so")
            self.assertEqual(info.create_system, 3)
            file_type = stat.S_IFMT(info.external_attr >> 16)
            self.assertEqual(file_type, stat.S_IFLNK)
            payload = zf.read("emulator/lib64/libvulkan.so").decode("utf-8")
            self.assertEqual(payload, "libvulkan.so.1")

    def test_deflated_empty_file_entry(self):
        manifest = [
            {
                "type": "empty_file",
                "dest": "marker.txt",
                "mode": "0644",
            }
        ]

        parallel_zip.create_zip_deflated(
            sevenzip_bin=self.sevenzip_bin,
            output_path=self.output_zip,
            entries=manifest,
            dir_prefix="/",
            default_mode=0o644,
            timestamp=parallel_zip.DEFAULT_EPOCH,
            compression_args=["-mm=Deflate", "-mx=6"],
        )

        with zipfile.ZipFile(self.output_zip, "r") as zf:
            self.assertIn("marker.txt", zf.namelist())
            info = zf.getinfo("marker.txt")
            self.assertEqual(info.create_system, 3)
            self.assertEqual(info.file_size, 0)
            self.assertEqual((info.external_attr >> 16) & 0o7777, 0o644)

    def test_deflated_tree_expansion_and_sorting(self):
        tree_dir = self.root / "mytree"
        tree_dir.mkdir(parents=True)
        (tree_dir / "sub").mkdir()
        (tree_dir / "sub" / "file_b.txt").write_bytes(b"FILE_B")
        (tree_dir / "file_a.txt").write_bytes(b"FILE_A")

        manifest = [
            {"type": "tree", "src": str(tree_dir), "dest": "assets", "mode": "0644"},
        ]

        parallel_zip.create_zip_deflated(
            sevenzip_bin=self.sevenzip_bin,
            output_path=self.output_zip,
            entries=manifest,
            dir_prefix="/",
            default_mode=0o555,
            timestamp=parallel_zip.DEFAULT_EPOCH,
            compression_args=["-mm=Deflate", "-mx=6"],
        )

        extract_dir = self.root / "extracted"
        extract_dir.mkdir(parents=True)
        try:
            with zipfile.ZipFile(self.output_zip, "r") as zf:
                names = zf.namelist()
                self.assertEqual(
                    names,
                    ["assets/", "assets/file_a.txt", "assets/sub/", "assets/sub/file_b.txt"],
                )
                for name in names:
                    info = zf.getinfo(name)
                    mode = (info.external_attr >> 16) & 0o7777
                    if name.endswith("/"):
                        self.assertEqual(
                            mode,
                            0o755,
                            f"Directory {name} should have 0755 permissions, got {oct(mode)}",
                        )
                    else:
                        self.assertEqual(
                            mode,
                            0o644,
                            f"File {name} should have 0644 permissions, got {oct(mode)}",
                        )
                    target = zf.extract(info, extract_dir)
                    if mode and os.name == "posix":
                        os.chmod(target, mode)
        finally:
            if os.name == "posix":
                for p in extract_dir.rglob("*"):
                    if p.is_dir():
                        p.chmod(0o755)
                extract_dir.chmod(0o755)

    def test_deflated_tree_preserves_intra_tree_symlinks_and_dereferences_external(self):
        if os.name != "posix":
            return
        external_file = self.root / "external_execroot_bin.txt"
        external_file.write_bytes(b"EXTERNAL_BYTES")

        tree_dir = self.root / "App.framework"
        (tree_dir / "Versions" / "A").mkdir(parents=True)
        (tree_dir / "Versions" / "A" / "App").write_bytes(b"MACH_O_BINARY")
        (tree_dir / "Versions" / "Current").symlink_to("A")
        (tree_dir / "App").symlink_to("Versions/Current/App")
        (tree_dir / "sandbox_input").symlink_to(external_file)

        manifest = [
            {"type": "tree", "src": str(tree_dir), "dest": "App.framework", "mode": "0755"},
        ]

        parallel_zip.create_zip_deflated(
            sevenzip_bin=self.sevenzip_bin,
            output_path=self.output_zip,
            entries=manifest,
            dir_prefix="emulator",
            default_mode=0o555,
            timestamp=parallel_zip.DEFAULT_EPOCH,
            compression_args=["-mm=Deflate", "-mx=6"],
        )

        with zipfile.ZipFile(self.output_zip, "r") as zf:
            current_info = zf.getinfo("emulator/App.framework/Versions/Current")
            self.assertEqual(stat.S_IFMT(current_info.external_attr >> 16), stat.S_IFLNK)
            self.assertEqual(zf.read("emulator/App.framework/Versions/Current"), b"A")

            app_info = zf.getinfo("emulator/App.framework/App")
            self.assertEqual(stat.S_IFMT(app_info.external_attr >> 16), stat.S_IFLNK)
            self.assertEqual(
                zf.read("emulator/App.framework/App"),
                b"Versions/Current/App",
            )

            ext_info = zf.getinfo("emulator/App.framework/sandbox_input")
            self.assertEqual(stat.S_IFMT(ext_info.external_attr >> 16), stat.S_IFREG)
            self.assertEqual(zf.read("emulator/App.framework/sandbox_input"), b"EXTERNAL_BYTES")

    def test_deflated_tree_unwraps_bazel_sandbox_symlink_forest_for_directory_symlinks(self):
        if os.name != "posix":
            return
        rel_tree = Path("bazel-out/darwin_arm64-opt/bin/App.framework")
        real_tree = self.root / "execroot" / "_main" / rel_tree
        (real_tree / "Versions" / "A" / "Resources").mkdir(parents=True)
        (real_tree / "Versions" / "A" / "App").write_bytes(b"MACH_O_BINARY")
        (real_tree / "Versions" / "A" / "Resources" / "Info.plist").write_bytes(b"PLIST")
        (real_tree / "Versions" / "Current").symlink_to("A")
        (real_tree / "Resources").symlink_to("Versions/Current/Resources")
        (real_tree / "App").symlink_to("Versions/Current/App")

        # Simulate Bazel darwin-sandbox / linux-sandbox TreeArtifact materialization:
        # directory symlinks become real directories populated with absolute leaf symlinks.
        sandbox_root = self.root / "sandbox" / "darwin-sandbox" / "1" / "execroot" / "_main"
        sandbox_tree = sandbox_root / rel_tree
        (sandbox_tree / "Versions" / "A" / "Resources").mkdir(parents=True)
        (sandbox_tree / "Versions" / "Current" / "Resources").mkdir(parents=True)
        (sandbox_tree / "Resources").mkdir(parents=True)
        for rel_leaf in [
            "App",
            "Resources/Info.plist",
            "Versions/A/App",
            "Versions/A/Resources/Info.plist",
            "Versions/Current/App",
            "Versions/Current/Resources/Info.plist",
        ]:
            (sandbox_tree / rel_leaf).symlink_to(real_tree / rel_leaf)

        prev_cwd = os.getcwd()
        os.chdir(sandbox_root)
        try:
            manifest = [
                {"type": "tree", "src": rel_tree.as_posix(), "dest": "App.framework", "mode": "0755"},
            ]
            parallel_zip.create_zip_deflated(
                sevenzip_bin=self.sevenzip_bin,
                output_path=self.output_zip,
                entries=manifest,
                dir_prefix="emulator",
                default_mode=0o555,
                timestamp=parallel_zip.DEFAULT_EPOCH,
                compression_args=["-mm=Deflate", "-mx=6"],
            )
        finally:
            os.chdir(prev_cwd)

        with zipfile.ZipFile(self.output_zip, "r") as zf:
            self.assertEqual(
                zf.namelist(),
                [
                    "emulator/",
                    "emulator/App.framework/",
                    "emulator/App.framework/App",
                    "emulator/App.framework/Resources",
                    "emulator/App.framework/Versions/",
                    "emulator/App.framework/Versions/A/",
                    "emulator/App.framework/Versions/A/App",
                    "emulator/App.framework/Versions/A/Resources/",
                    "emulator/App.framework/Versions/A/Resources/Info.plist",
                    "emulator/App.framework/Versions/Current",
                ],
            )
            for link_entry, expected_target in [
                ("emulator/App.framework/App", b"Versions/Current/App"),
                ("emulator/App.framework/Resources", b"Versions/Current/Resources"),
                ("emulator/App.framework/Versions/Current", b"A"),
            ]:
                info = zf.getinfo(link_entry)
                self.assertEqual(stat.S_IFMT(info.external_attr >> 16), stat.S_IFLNK)
                self.assertEqual(zf.read(link_entry), expected_target)

    def test_deflated_deterministic_timestamp(self):
        file1 = self.root / "file1.txt"
        file1.write_bytes(b"CONTENT")

        manifest = [{"type": "file", "src": str(file1), "dest": "file1.txt"}]

        parallel_zip.create_zip_deflated(
            sevenzip_bin=self.sevenzip_bin,
            output_path=self.output_zip,
            entries=manifest,
            dir_prefix="/",
            default_mode=0o555,
            timestamp=parallel_zip.DEFAULT_EPOCH,
            compression_args=["-mm=Deflate", "-mx=6"],
        )

        with zipfile.ZipFile(self.output_zip, "r") as zf:
            info = zf.getinfo("file1.txt")
            self.assertEqual(info.date_time, (1980, 1, 1, 0, 0, 0))


if __name__ == "__main__":
    unittest.main()
