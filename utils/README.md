# Bazel Build Utilities

This directory contains utility scripts for managing the Bazel build environment.

## `create_hermetic_packages.py`

This script creates hermetic zip packages for the Microsoft Visual C++ (MSVC) toolchain and the Windows SDK. These packages are uploaded to Google Cloud Storage (GCS) and used by Bazel to ensure reproducible builds on Windows.

### Requirements

*   **OS:** Windows (required for creating packages and listing available versions). The script queries the Windows Registry and uses `vswhere.exe`.
*   **Python 3**
*   **Visual Studio:** Installed with C++ Desktop Development workload (for `msvc` command).
*   **Google Cloud SDK (`gcloud storage`):** Required if using the `--upload` or `--update-bzl` flags.

### Usage

The script has two main commands: `msvc` and `sdk`. It is recommended to run it directly with Python to ensure that the `extensions/toolchain.bzl` file is correctly updated in your local workspace.

#### Running via Python (Recommended)

```bash
python utils/create_hermetic_packages.py msvc --update-bzl
```

#### Running via Bazel

While you can run it via Bazel, you must use `--` to separate Bazel arguments from script arguments:

```bash
bazel run //utils:create_hermetic_packages -- msvc --update-bzl
```

#### Common Arguments

*   `--upload`: Upload the resulting zip file to GCS.
*   `--update-bzl`: Automatically update `extensions/toolchain.bzl` with the new URL and SHA256 hash. This **implies** `--upload`.
    *   `msvc` updates the `vctools_hermetic` target.
    *   `sdk` updates the `windows_sdk_hermetic` target.
*   `--gcs-bucket <url>`: Specify a custom GCS bucket (default: `gs://emu-next-bazel/hermetic-msvc`). Can also be set via the `AEMU_BUILD_GCS_BUCKET` environment variable.
*   `-o, --output-dir <dir>`: Directory to save the zip file (default: current directory).
*   `-v, --verbose`: Enable verbose logging.

#### Creating an MSVC Package

```bash
# Create package for the latest MSVC version, upload, and update Bazel config
python utils/create_hermetic_packages.py msvc --update-bzl

# List available MSVC versions
python utils/create_hermetic_packages.py msvc --list-versions

# Package a specific version
python utils/create_hermetic_packages.py msvc --version 14.38.33130 --update-bzl
```

#### Creating a Windows SDK Package

```bash
# Create package for the latest Windows SDK, upload, and update Bazel config
python utils/create_hermetic_packages.py sdk --update-bzl

# List available SDK versions
python utils/create_hermetic_packages.py sdk --list-versions
```

## `update_sysimage.py`

This script updates the default system images used for emulator testing in `extensions/android_repos.bzl`. It fetches the images from the internal Android Build server, calculates their SHA256 hash, uploads them to GCS, and updates the corresponding `goog` source entries in `extensions/android_repos.bzl`.

**Note: This script is for internal Google use only.** AOSP users should use the public URLs defined in the `aosp` source entries in `extensions/android_repos.bzl`.

### Requirements
*   **Python 3**
*   **Google Cloud SDK (`gcloud storage`)**
*   **Access to internal Android build artifacts** (requires the `fetch_artifact` tool).

### Usage
```bash
python utils/update_sysimage.py -b <build_id> [options]
```

### Common Arguments
*   `-b, --build-id <id>`: **Required**. The Android build ID to fetch from.
*   `--gcs-bucket <bucket>`: Override the target GCS bucket.
*   `-f, --force`: Force download and upload even if the file exists on GCS.
*   `-v, --verbose`: Enable verbose logging.

### Workflow for MSVC/SDK

1.  Run the script on a Windows machine that has the desired Visual Studio / SDK version installed.
2.  Use `--upload` and `--update-bzl` to streamline the process.
3.  Commit the changes to `extensions/toolchain.bzl`.

## `update_repo_bazel.py`

This script uses `bazel mod show_repo --all_repos` to discover all external repositories pointing to workspace subdirectories, optionally merges extra ignored glob patterns from a file, shortens the list by removing nested paths and collapsing fully ignored sibling directories, and updates the `ignore_directories([...])` list in a target `REPO.bazel` file (such as `build/bazel/toplevel.REPO.bazel`).

### Usage

```bash
# Update toplevel.REPO.bazel in-place
bazel run @goldfish_build//utils:update_repo_bazel -- \
    --repo_file=build/bazel/toplevel.REPO.bazel

# Update with an extra ignore file
bazel run @goldfish_build//utils:update_repo_bazel -- \
    --repo_file=build/bazel/toplevel.REPO.bazel \
    --extra_ignore_file=path/to/extra.ignore

# Check if toplevel.REPO.bazel needs an update (prints unified diff and exits with 1 if out of date)
bazel run @goldfish_build//utils:update_repo_bazel -- \
    --repo_file=build/bazel/toplevel.REPO.bazel \
    --extra_ignore_file=path/to/extra.ignore \
    --diff
```

### Arguments
*   `--repo_file <file>`: **Required**. Path to the `REPO.bazel` file to update or check.
*   `--extra_ignore_file <file>`: Path to a file containing extra ignored glob patterns (one per line, allowing `#` line comments and blank lines).
*   `--diff`: Output a unified diff and exit with status `1` if the file needs updating, without modifying the file.

