# Android Emulator Bazel Build System

This directory contains the Bazel build system configuration and utilities for
the Android Emulator (AEMU).

## Repository Overview

This repository is structured to support a hermetic, reproducible build of the
Android Emulator and its associated tools (e.g., `netsim`, `rootcanal`). It
integrates various components including QEMU, GFXstream, and Rutabaga, managing
their dependencies and build configurations through Bazel.

Key directories:

- `build/bazel`: Central Bazel configuration, extensions, and common rules.
- `hardware/generic/goldfish`: The main emulator source code and plugin logic.
- `third_party`: External dependencies mirrored or linked into the workspace.
- `prebuilts`: Host toolchains and pre-compiled binaries (SDKs, JDKs, etc.).

## Bazel Structure

The build utilizes **Bzlmod** for dependency management. The root `MODULE.bazel`
file (symlinked from `build/bazel/toplevel.MODULE.bazel`) defines the external
dependencies.

### Local Registry Override

To manage local modifications to upstream Bazel modules and to package internal
components as modules, we use a **Local Bazel Registry** located at
`build/bazel/registry`.

The `.bazelrc` configures Bazel to prioritize this local registry:

```bazel
common --registry=file:///%workspace%/build/bazel/registry
common --registry=https://bcr.bazel.build
```

Most modules in this repository (e.g., `@goldfish`, `@aemu`, `@qemu`) are
defined in `build/bazel/registry/modules` and use `source.json` to point to
their actual source locations within the git repo using `local_path`. This
allows us to treat different parts of the monorepo as distinct Bazel modules
while keeping them in a single git repository.

## AOSP Builds, Downloader URL Rewriting, Airlock Repositories, and GCS Mirrors

To support hermetic, reproducible builds across both Google-internal and
open-source Android Open Source Project (AOSP) environments, the build system
uses **Downloader URL Rewriting** (`--downloader_config`), **Airlock
Repositories**, and **Google Cloud Storage Mirrors**:

### Airlock Repositories for Maven, NPM, and Python (Preferred & Safe)

For Maven, NPM, and Python/PyPI dependencies, always use Google's internal
**Airlock repositories** ([go/airlock-repositories](http://go/airlock-repositories)).

- **Pre-vetted and Secure:** Artifacts in Airlock are scanned, vetted, and safe
  for internal Google development.
- **Do NOT upload to GCS:** Maven, NPM, and Python packages **must NOT** end up
  in our GCS mirror bucket (`gs://emu-next-bazel/`). Airlocked packages are
  hosted and served directly by Google's internal Artifact Registry
  (`pkg.dev`), our own Google Artifactory.
- **Automatic URL Rewriting:** `build/bazel/utils/downloader.cfg` automatically
  intercepts public repository URLs and rewrites them to the trusted Airlock
  mirrors:
  - **Maven:** `repo1.maven.org/maven2/` &rarr; `us-maven.pkg.dev/artifact-foundry-prod/maven-3p-trusted/`
  - **NPM:** `registry.npmjs.org/` &rarr; `us-npm.pkg.dev/artifact-foundry-prod/npm-3p-trusted/`
  - **Python / PyPI:** `pypi.org/simple/` &rarr; `us-python.pkg.dev/artifact-foundry-prod/python-3p-trusted/simple/`
- **Authentication:** Authenticated requests to `*.pkg.dev` are handled
  transparently by the Bazel credential helper configured in `base.bazelrc`.
- **Requesting New Packages:** If a required package or version is not yet
  available in Airlock, follow the onboarding process at
  [go/airlock-repositories](http://go/airlock-repositories) to request and vet
  it into the trusted repository.

---

### Rust Dependencies via Android Platform Crates (go/android-rust-importing-crates)

For Rust crates, dependencies should be obtained from Android Development:

- **Sourced from Android Monorepo:** Android platform crates are imported and
  managed under the `platform/external/rust/android-crates-io` monorepo using
  the `crate_tool` script. For instructions and workflow details, see
  [go/android-rust-importing-crates](http://go/android-rust-importing-crates).
- **Mirroring to GCS:** While we can upload crate archives (`.crate` files) to
  our internal GCS bucket (`gs://emu-next-bazel/crates/`) and rewrite download
  URLs via `downloader.cfg`, all crate dependencies should be sourced from the
  vetted Android platform crates rather than pulling arbitrary unvetted crates
  directly from `crates.io`.

---

### Internal Google Cloud Storage Bucket

- **Bucket URI**: `gs://emu-next-bazel/`
- **HTTP Mirror Base URL**: `https://storage.googleapis.com/emu-next-bazel/`
- **Access**: Google internal (`gcloud auth login`).

> [!NOTE]
> The GCS bucket is strictly reserved for assets **not** covered by Airlock,
> such as toolchains, C/C++ upstream source tarballs, Rust crates (sourced from
> Android Development via [go/android-rust-importing-crates](http://go/android-rust-importing-crates)),
> and Android system images. Do not mirror Maven, NPM, or Python packages to GCS.

---

### When and How to Use Internal GCS Buckets

There are two primary patterns for using internal GCS storage in this
repository:

#### Pattern 1: High-Speed Mirroring for Public Upstreams (Toolchains, C/C++ Tarballs, Rust Crates)

Use this pattern for third-party C/C++ source archives (BCR modules), toolchains
(Protoc, Python standalone, Perl, CMake, Ninja, Meson, Make, pkg-config, Gnome Win64, Rust toolchain), or Rust crates that
are publicly available but should be fetched internally from Google Cloud
Storage to eliminate build flakiness, CDN timeouts, and rate limits.

1. **Declare Public Upstream in Bazel:**
   - In `MODULE.bazel` or local registry `source.json`, declare the **canonical
     public URL** and its cryptographic `sha256` hash.
2. **Mirror Artifact to GCS:**
   ```bash
   gcloud storage cp /path/to/archive.tar.gz gs://emu-next-bazel/registry/<module_name>/<archive.tar.gz>
   # For Rust crates (sourced from Android Development):
   gcloud storage cp /path/to/<crate>-<version>.crate gs://emu-next-bazel/crates/<crate>/<version>/download
   # Or for toolchains:
   gcloud storage cp /path/to/tool.zip gs://emu-next-bazel/toolchains/<tool_name>/<tool.zip>
   ```
3. **Add Rewrite Rule in `build/bazel/utils/downloader.cfg`:**
   Note: Bazel evaluates rewrites against the URL without scheme (`withoutScheme`),
   so do not include `https://` in the regex pattern:
   ```properties
   rewrite upstream\.org/releases/(.*\.tar\.gz) storage.googleapis.com/emu-next-bazel/registry/<module_name>/$1
   ```
4. **Behavior:**
   - **Internal Builds (`goog` / default):** Bazel rewrites known URLs to GCS
     or Airlock mirrors via `downloader.cfg`. Unmapped URLs fall back to upstream.
   - **AOSP Builds (`--config aosp`):** `downloader_aosp.cfg` blocks GCS and
     downloads directly from the canonical public upstream.

---

#### Pattern 2: `multisource_repo` for Divergent / Internal-Only Assets

Use this pattern when the asset itself differs between Google internal
development (e.g. internal system images from Android Build `go/ab` or internal
test harnesses) and public open-source releases.

1. **Upload Asset to GCS:**
   ```bash
   gcloud storage cp /path/to/system-image.zip gs://emu-next-bazel/sys-img/<target>/<image.zip>
   ```
2. **Declare in `extensions/android_repos.bzl` (or override via `multisource_repo.archive`):**
   - Standard Android API 29–37 system images (`SYSTEM_IMAGE_ARCHIVES`), CTS
     suites (`CTS_ARCHIVES`), CTS-Verifier suites (`CTS_VERIFIER_ARCHIVES`), and
     the default API 37 16K system images (`DEFAULT_SYSTEM_IMAGE_ARCHIVES`) are
     declared in the compact table-driven catalog in
     [extensions/android_repos.bzl](extensions/android_repos.bzl) and loaded
     automatically by `multisource_repo.bzl`.
   - Individual `MODULE.bazel` files only need `use_extension` and `use_repo`
     (though explicit `multisource_repo.archive(...)` tags can still be used to
     add or override repositories).
3. **Automated Updating:**
   - Use [utils/update_sysimage.py](utils/update_sysimage.py) to automatically
     download default system images from `go/ab`, upload to GCS, and update
     [extensions/android_repos.bzl](extensions/android_repos.bzl).

---

### Usage & Build Modes

- **Internal Google Build (Default):**
  ```bash
  bzl build @goldfish//emulator:release
  bzl test @goldfish_test//ets:presubmit
  ```
- **Open-Source AOSP Build (`--config=aosp`):**
  ```bash
  bzl build --config=aosp @goldfish//emulator:release
  bzl test --config=aosp @goldfish_test//ets:presubmit
  ```
  This flag activates `build/bazel/utils/downloader_aosp.cfg` (blocking GCS) and
  sets `MULTISOURCE_REPO_TYPE=aosp`.

### Selecting Android API Levels (API 29–37) for Launcher, ETS, and xTS

All Android API levels from **29 through 37** (`x86_64` and `arm64-v8a`) are
registered for system images, CTS, and CTS-Verifier in
[extensions/android_repos.bzl](extensions/android_repos.bzl). When no API level
is specified, all targets default to **API 37** (`@android16k-x86_64` /
`@android16k-arm64-v8a`, `@cts-x86-64` / `@cts-arm64`, `@cts-verifier`).

You can target a specific API level (`29..37`) in two ways:

1. **Via `--define api_level=<29..37>` on default targets:**
   ```bash
   # Launch the emulator with an API 36 system image
   bzl run --define api_level=36 @goldfish//emulator/launcher:launch_emulator

   # Run ETS or xTS suites against API 36
   bzl test --define api_level=36 @goldfish_test//ets:boot_test
   bzl test --define api_level=36 @goldfish_test//xts:infodeqp
   bzl test --define api_level=36 @goldfish_test//xts:presubmit
   bzl test --define api_level=36 @goldfish_test//xts:cts-verifier
   ```

2. **Via explicit `*_api_<29..37>` targets:**
   ```bash
   bzl test @goldfish_test//ets:boot_test_api_36
   bzl test @goldfish_test//ets:presubmit_api_36
   bzl test @goldfish_test//xts:infodeqp_api_36
   bzl test @goldfish_test//xts:presubmit_api_36
   bzl test @goldfish_test//xts:cts-verifier_api_36
   ```

#### Expected Content & AOSP Status

#### 1. Toolchains

- **ARM Toolchain (`arm_sysroot`)**:
  - Declared as standard `http_archive` pointing to canonical
    `https://developer.arm.com/...`.
  - Internally rewritten to GCS mirror via `downloader.cfg`. Fully functional in
    AOSP builds.
- **Xcode Command Line Tools**:
  - `hermetic-xcode/xcode_command_line_tools-16.2-202505191216.zip`
  - **AOSP Status**: Users rely on host tools or provide their own.
- **MSVC & Windows SDK**:
  - `hermetic-msvc/msvc_tools_14_50_35717_202601231558.zip`
  - `hermetic-msvc/windows_11_sdk_10.0.22621.0_202506021733.zip`
  - **AOSP Status**: Users create their own packages using
    [create_hermetic_packages.py](utils/create_hermetic_packages.py). See
    [utils/README.md](utils/README.md) for details.

#### 2. System Images & xTS Suites for Testing

- **Configurable API 29–37 System Images & xTS Suites**:
  - `sysimg-android-<29..37>-{x86_64,arm64-v8a}`
  - `cts-android-<29..37>-{x86-64,arm64}`
  - `cts-verifier-android-<29..37>-{x86-64,arm64}`
- **Unversioned Latest-API Aliases (API 37)**:
  - `android16k-{x86_64,arm64-v8a}` (aliases for `sysimg-android-37-{x86_64,arm64-v8a}`)
  - `cts-{x86-64,arm64}` (aliases for `cts-android-37-{x86-64,arm64}`)
  - `cts-verifier` (alias for `cts-verifier-android-37-x86-64`)
  - **AOSP Status**: Available via official public `dl.google.com` SDK and CTS archives.

## Key Utilities

These scripts are located in [utils/](utils/).

### [create_hermetic_packages.py](utils/create_hermetic_packages.py)

Creates and uploads hermetic toolchain packages (MSVC, Windows SDK) to GCS.

**Usage:**

```bash
python utils/create_hermetic_packages.py {msvc|sdk} [options]
```

**Common Options:**

- `--upload`: Upload the resulting zip file to GCS.
- `--gcs-bucket <bucket>`: Override the default bucket.
- `--update-bzl`: Automatically update `extensions/toolchain.bzl` with the new
  URL and SHA256.

### [update_sysimage.py](utils/update_sysimage.py)

Manages the update and upload of system images to the GCS bucket, and updates
the `goog` source entries in `extensions/android_repos.bzl`. (Internal Google use only).

**Usage:**

```bash
python utils/update_sysimage.py -b BUILD_ID [options]
```

**Options:**

- `-b, --build-id <id>`: Fetch from internal Android Build.
- `--gcs-bucket <bucket>`: Override the target GCS bucket.
- `-f, --force`: Force download and upload even if the file exists on GCS.
- `-v, --verbose`: Enable verbose logging.

## Clang-Tidy Configuration

The build system includes first-class support for `clang-tidy` integration via
Bazel aspects. The `clang_tidy_test` rules operate over the C++ dependency graph
and ensure that code styling and static analysis modernize the codebase in an
automated, transactional basis.

### Enabling Clang-Tidy Validation

To invoke clang-tidy validation during a test or build phase, pass the following
flag:

```bash
--@aemu//tools/clang_tidy:clang_tidy_enabled=true
```

### Performance & Diagnostic Scoping

Parsing every C++ source file heavily burdens the build system and generates
significant noise from legacy code. We use a combination of flags to scope the
analysis down to single files and specific line numbers (e.g. for precommit
hooks or `emu-dev-cli tidy` refactoring pipelines):

1. **Limit the Aspect AST Evaluation (`clang_tidy_check_files`)** Use this to
   restrict the Bazel aspect to a minimal set of source files. This works via a
   string suffix match against file paths and drastically speeds up the
   evaluation time.

   ```bash
   --@aemu//tools/clang_tidy:clang_tidy_check_files="foo.cc"
   --@aemu//tools/clang_tidy:clang_tidy_check_files="bar.h"
   ```

2. **Restrict Emitted Diagnostics (`clang_tidy_line_filter`)** Even when parsing
   `foo.cc`, limit the generated report to lines actually modified by passing
   the native `clang-tidy` line filter block format encoded as JSON.
   ```bash
   --@aemu//tools/clang_tidy:clang_tidy_line_filter='[{"name": "foo.cc", "lines": [[10, 20]]}]'
   ```
