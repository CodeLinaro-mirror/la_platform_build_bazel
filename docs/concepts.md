# Android Build System Concepts

This document provides high level explanations and mapping of the build system
concepts in the current Android build system and Bazel.

## High level components

|Android build system component|Description|Mapping to Bazel concepts|
|---|---|---|
|Blueprint|Build definition syntax. Build syntax parser. Internal data structures like Modules/Variations/Context/Scope. Ninja file generator.|Starlark.|
|Kati|Make-compatible front-end. Encodes build logic in `.mk` scripts. Declares buildable units in `Android.mk`. Generates Ninja file directly.|Loading and analysis phase. Conceptually similar to `bazel build --nobuild`.|
|Soong|Bazel-like front-end. Encodes build logic in Go. Declares build units in `Android.bp`, parsed by Blueprint. Uses Blueprint to generate Ninja file.  Generates a `.mk` file with prebuilt module stubs to Kati.|Loading and analysis phase. Conceptually similar to `bazel build --nobuild command`.|
|Ninja|Serialized command line action graph executor. Executes Ninja graph generated from Kati and Soong.|Bazel's execution phase.|
|atest|Test executor and orchestrator.|Conceptually similar to `bazel test` command.|
|Blueprint + Kati + Soong + Ninja + atest|The entire build pipeline for Android.|Conceptually similar to `bazel build` or `bazel test` commands.|
|`<script>.sh`|Running arbitrary scripts in AOSP.|Conceptually similar to `bazel run` command.|
|Make (replaced in-place by Kati)|No longer in use. Entire build system, replaced by the tools above.|Loading, analysis, execution phases. Conceptually similar to `bazel build` command.|
