"""Cc toolchain features that works with clang-cl."""

load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load(
    "@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl",
    "env_entry",
    "env_set",
    "feature",
    "flag_group",
    "flag_set",
    "variable_with_value",
    "with_feature_set",
)
load(
    "//toolchains/cc:actions.bzl",
    "ARCHIVER_ACTIONS",
    "ASSEMBLE_ACTIONS",
    "CPP_COMPILE_ACTIONS",
    "CPP_SOURCE_ACTIONS",
    "C_COMPILE_ACTIONS",
    "LINK_ACTIONS",
    "OBJC_COMPILE_ACTIONS",
)
load(
    "//toolchains/cc:features_common.bzl",
    "dynamic_linking_mode_feature",
    "get_disable_all_warnings_feature",
    "get_reproducible_build_feature",
    "get_toolchain_assembler_flags_feature",
    "get_toolchain_compile_flags_feature",
    "get_toolchain_cxx_flags_feature",
    "get_warnings_as_errors_feature",
    "get_warnings_feature",
    "linkstamps_feature",
    "no_legacy_features",
    "no_stripping_feature",
    "rules_rust_unsupported_feature",
    "static_linking_mode_feature",
    "supports_dynamic_linker_feature",
    "toolchain_import_configs",
    "user_compile_flags_feature",
    "user_link_flags_feature",
)
load(
    "//toolchains/cc:rules.bzl",
    "CcFeatureConfigInfo",
    "CcToolchainImportInfo",
)
load(
    "//toolchains/cc:utils.bzl",
    "check_args",
    "filter_none",
    "flatten",
)
load(
    "//toolchains/cc/linux_clang:features.bzl",
    "linker_param_file_feature",
)

archive_param_file_feature = feature(
    name = "archive_param_file",
    enabled = True,
)

compiler_input_feature = feature(
    name = "compiler_input_flags",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = C_COMPILE_ACTIONS + OBJC_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS + ASSEMBLE_ACTIONS,
            flag_groups = [
                flag_group(
                    expand_if_available = "source_file",
                    flags = ["/c", "%{source_file}"],
                ),
            ],
        ),
    ],
)

compiler_output_feature = feature(
    name = "compiler_output_flags",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = C_COMPILE_ACTIONS + OBJC_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS + ASSEMBLE_ACTIONS,
            flag_groups = [
                flag_group(
                    expand_if_available = "output_file",
                    expand_if_not_available = "output_preprocess_file",
                    flag_groups = [
                        flag_group(
                            expand_if_not_available = "output_assembly_file",
                            flags = ["/Fo%{output_file}"],
                        ),
                    ],
                ),
                flag_group(
                    expand_if_available = "output_file",
                    flag_groups = [
                        flag_group(
                            expand_if_available = "output_assembly_file",
                            flags = ["/Fa%{output_file}"],
                        ),
                        flag_group(
                            expand_if_available = "output_preprocess_file",
                            flags = ["/P", "/Fi%{output_file}"],
                        ),
                    ],
                ),
            ],
        ),
    ],
)

compiler_param_file_feature = feature(
    name = "compiler_param_file",
    enabled = True,
)

copy_dynamic_libraries_to_binary_feature = feature(
    name = "copy_dynamic_libraries_to_binary",
    enabled = True,
)

dbg_feature = feature(
    name = "dbg",
    flag_sets = [
        flag_set(
            actions = C_COMPILE_ACTIONS + OBJC_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS,
            flag_groups = [
                flag_group(flags = ["/Od", "/Z7", "-fno-limit-debug-info"]),
            ],
        ),
        flag_set(
            actions = LINK_ACTIONS,
            flag_groups = [
                flag_group(flags = ["/INCREMENTAL:NO"]),
            ],
        ),
    ],
    implies = ["generate_pdb_file"],
)

def_file_feature = feature(
    name = "def_file",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = LINK_ACTIONS,
            flag_groups = [
                flag_group(
                    flags = ["/DEF:%{def_file_path}"],
                    expand_if_available = "def_file_path",
                ),
            ],
        ),
    ],
)

external_include_paths_feature = feature(
    name = "external_include_paths",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = CPP_SOURCE_ACTIONS + C_COMPILE_ACTIONS + OBJC_COMPILE_ACTIONS + [
                ACTION_NAMES.preprocess_assemble,
                ACTION_NAMES.linkstamp_compile,
            ],
            flag_groups = [
                flag_group(
                    flags = ["/external:I%{external_include_paths}"],
                    iterate_over = "external_include_paths",
                    expand_if_available = "external_include_paths",
                ),
            ],
        ),
    ],
)

generate_pdb_file_feature = feature(
    name = "generate_pdb_file",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = ASSEMBLE_ACTIONS,
            flag_groups = [flag_group(flags = [
                # Generate full debug information
                "/Zi",
            ])],
        ),
        flag_set(
            actions = C_COMPILE_ACTIONS + OBJC_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS,
            flag_groups = [flag_group(flags = [
                # Generate full debug information
                "/Zi",
                # Emit type record hashes in .debug$H for fast parallel type merging
                "-gcodeview-ghash",
            ])],
        ),
        flag_set(
            actions = LINK_ACTIONS,
            flag_groups = [flag_group(flags = ["/DEBUG:GHASH"])],
        ),
    ],
)

fastbuild_feature = feature(
    name = "fastbuild",
    flag_sets = [
        flag_set(
            actions = C_COMPILE_ACTIONS + OBJC_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS,
            flag_groups = [
                flag_group(flags = [
                    "/O1",
                ]),
            ],
        ),
    ],
)

def get_archiver_flags_feature(user_flags):
    return feature(
        name = "archiver_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = ARCHIVER_ACTIONS,
                flag_groups = filter_none([
                    check_args(len, flag_group, flags = user_flags),
                ]) + [
                    flag_group(
                        expand_if_available = "output_execpath",
                        flags = ["/OUT:%{output_execpath}"],
                    ),
                    flag_group(
                        expand_if_available = "libraries_to_link",
                        iterate_over = "libraries_to_link",
                        flag_groups = [
                            flag_group(
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "object_file_group",
                                ),
                                iterate_over = "libraries_to_link.object_files",
                                flag_groups = [
                                    flag_group(flags = ["%{libraries_to_link.object_files}"]),
                                ],
                            ),
                            flag_group(
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "object_file",
                                ),
                                flag_groups = [
                                    flag_group(flags = ["%{libraries_to_link.name}"]),
                                ],
                            ),
                            flag_group(
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "static_library",
                                ),
                                flag_groups = [
                                    flag_group(flags = ["%{libraries_to_link.name}"]),
                                ],
                            ),
                        ],
                    ),
                ],
            ),
        ],
    )

def get_toolchain_include_paths_feature(import_config):
    return feature(
        name = "toolchain_include_paths",
        enabled = True,
        flag_sets = [
            flag_set(
                # Exclude preprocess_assemble because x64 uses ml64.exe, which
                # does not accept /imsvc (it reads INCLUDE from env_sets below).
                actions = CPP_SOURCE_ACTIONS + C_COMPILE_ACTIONS + OBJC_COMPILE_ACTIONS + [
                    ACTION_NAMES.linkstamp_compile,
                ],
                flag_groups = filter_none([
                    check_args(
                        len,
                        flag_group,
                        flags = [
                            "/imsvc" + path
                            for path in import_config.include_paths
                        ],
                    ),
                ]),
            ),
        ],
        env_sets = [
            env_set(
                actions = CPP_SOURCE_ACTIONS + C_COMPILE_ACTIONS + OBJC_COMPILE_ACTIONS + [
                    ACTION_NAMES.preprocess_assemble,
                    ACTION_NAMES.linkstamp_compile,
                ],
                env_entries = [
                    env_entry(
                        key = "INCLUDE",
                        value = ";".join(import_config.include_paths),
                    ),
                ],
            ),
        ],
    )

def get_toolchain_lib_search_paths_feature(import_config):
    return feature(
        name = "toolchain_library_search_directories",
        enabled = True,
        env_sets = [
            env_set(
                actions = LINK_ACTIONS,
                env_entries = [
                    env_entry(
                        key = "LIB",
                        value = ";".join(import_config.lib_search_paths),
                    ),
                ],
            ),
        ],
    )

def get_toolchain_link_flags_feature(flags):
    return feature(
        name = "toolchain_link_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = LINK_ACTIONS,
                flag_groups = filter_none([
                    check_args(len, flag_group, flags = flags),
                ]),
            ),
        ],
    )

has_configured_linker_path_feature = feature(
    name = "has_configured_linker_path",
    enabled = True,
)

# Forced includes. Bazel passes the build-info header (which defines
# BUILD_EMBED_LABEL etc.) to linkstamp_compile only through the "includes"
# variable, so without this linkstamped sources never see the stamped values.
# Mirrors includes_feature in linux_clang/features.bzl, using clang-cl's /FI.
includes_feature = feature(
    name = "includes",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = CPP_SOURCE_ACTIONS + C_COMPILE_ACTIONS + OBJC_COMPILE_ACTIONS + [
                ACTION_NAMES.preprocess_assemble,
                ACTION_NAMES.linkstamp_compile,
            ],
            flag_groups = [
                flag_group(
                    expand_if_available = "includes",
                    iterate_over = "includes",
                    flags = ["/FI%{includes}"],
                ),
            ],
        ),
    ],
)

include_paths_feature = feature(
    name = "include_paths",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = CPP_SOURCE_ACTIONS + C_COMPILE_ACTIONS + OBJC_COMPILE_ACTIONS + [
                ACTION_NAMES.preprocess_assemble,
                ACTION_NAMES.linkstamp_compile,
            ],
            flag_groups = [
                flag_group(
                    flags = ["/I%{quote_include_paths}"],
                    iterate_over = "quote_include_paths",
                ),
                flag_group(
                    flags = ["/I%{include_paths}"],
                    iterate_over = "include_paths",
                ),
                flag_group(
                    flags = ["/I%{system_include_paths}"],
                    iterate_over = "system_include_paths",
                ),
            ],
        ),
    ],
)

interface_library_output_feature = feature(
    name = "interface_library_output_path",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = [
                ACTION_NAMES.cpp_link_dynamic_library,
                ACTION_NAMES.cpp_link_nodeps_dynamic_library,
            ],
            flag_groups = [
                flag_group(
                    expand_if_available = "interface_library_output_path",
                    flags = ["/IMPLIB:%{interface_library_output_path}"],
                ),
            ],
        ),
    ],
)

libraries_to_link_feature = feature(
    name = "libraries_to_link",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = LINK_ACTIONS,
            flag_groups = [
                flag_group(
                    expand_if_available = "libraries_to_link",
                    iterate_over = "libraries_to_link",
                    flag_groups = [
                        flag_group(
                            expand_if_equal = variable_with_value(
                                name = "libraries_to_link.type",
                                value = "object_file_group",
                            ),
                            expand_if_false = "libraries_to_link.is_whole_archive",
                            flags = ["/start-lib"],
                        ),
                        flag_group(
                            expand_if_equal = variable_with_value(
                                name = "libraries_to_link.type",
                                value = "object_file_group",
                            ),
                            iterate_over = "libraries_to_link.object_files",
                            flag_groups = [
                                flag_group(flags = ["%{libraries_to_link.object_files}"]),
                            ],
                        ),
                        flag_group(
                            expand_if_equal = variable_with_value(
                                name = "libraries_to_link.type",
                                value = "object_file_group",
                            ),
                            expand_if_false = "libraries_to_link.is_whole_archive",
                            flags = ["/end-lib"],
                        ),
                        flag_group(
                            expand_if_equal = variable_with_value(
                                name = "libraries_to_link.type",
                                value = "object_file",
                            ),
                            flag_groups = [
                                flag_group(flags = ["%{libraries_to_link.name}"]),
                            ],
                        ),
                        flag_group(
                            expand_if_equal = variable_with_value(
                                name = "libraries_to_link.type",
                                value = "interface_library",
                            ),
                            flag_groups = [
                                flag_group(flags = ["%{libraries_to_link.name}"]),
                            ],
                        ),
                        flag_group(
                            expand_if_equal = variable_with_value(
                                name = "libraries_to_link.type",
                                value = "static_library",
                            ),
                            flag_groups = [
                                flag_group(
                                    expand_if_false = "libraries_to_link.is_whole_archive",
                                    flags = ["%{libraries_to_link.name}"],
                                ),
                                flag_group(
                                    expand_if_true = "libraries_to_link.is_whole_archive",
                                    flags = ["/WHOLEARCHIVE:%{libraries_to_link.name}"],
                                ),
                            ],
                        ),
                    ],
                ),
            ],
        ),
    ],
)

msvc_runtimes_feature = feature(
    name = "msvc_runtimes",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = C_COMPILE_ACTIONS + OBJC_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS,
            flag_groups = [flag_group(flags = ["/MD"])],
            with_features = [
                with_feature_set(not_features = ["static_link_msvcrt", "dbg"]),
            ],
        ),
        flag_set(
            actions = C_COMPILE_ACTIONS + OBJC_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS,
            flag_groups = [flag_group(flags = ["/MDd"])],
            with_features = [
                with_feature_set(not_features = ["static_link_msvcrt"], features = ["dbg"]),
            ],
        ),
        flag_set(
            actions = LINK_ACTIONS,
            flag_groups = [flag_group(flags = ["/DEFAULTLIB:msvcrt.lib"])],
            with_features = [
                with_feature_set(not_features = ["static_link_msvcrt", "dbg"]),
            ],
        ),
        flag_set(
            actions = LINK_ACTIONS,
            flag_groups = [flag_group(flags = ["/DEFAULTLIB:msvcrtd.lib"])],
            with_features = [
                with_feature_set(not_features = ["static_link_msvcrt"], features = ["dbg"]),
            ],
        ),
        flag_set(
            actions = C_COMPILE_ACTIONS + OBJC_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS,
            flag_groups = [flag_group(flags = ["/MT"])],
            with_features = [
                with_feature_set(features = ["static_link_msvcrt"], not_features = ["dbg"]),
            ],
        ),
        flag_set(
            actions = C_COMPILE_ACTIONS + OBJC_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS,
            flag_groups = [flag_group(flags = ["/MTd"])],
            with_features = [
                with_feature_set(features = ["static_link_msvcrt", "dbg"]),
            ],
        ),
        flag_set(
            actions = LINK_ACTIONS,
            flag_groups = [flag_group(flags = ["/DEFAULTLIB:libcmt.lib"])],
            with_features = [
                with_feature_set(features = ["static_link_msvcrt"], not_features = ["dbg"]),
            ],
        ),
        flag_set(
            actions = LINK_ACTIONS,
            flag_groups = [flag_group(flags = ["/DEFAULTLIB:libcmtd.lib"])],
            with_features = [
                with_feature_set(features = ["static_link_msvcrt", "dbg"]),
            ],
        ),
    ],
)

no_windows_export_all_symbols_feature = feature(name = "no_windows_export_all_symbols")

opt_feature = feature(
    name = "opt",
    flag_sets = [
        flag_set(
            actions = C_COMPILE_ACTIONS + OBJC_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS,
            flag_groups = [
                flag_group(flags = [
                    "/O2",
                    # Allow removal of unused sections and code folding at link
                    # time.
                    "/Gy",
                    "/Gw",
                    "/DNDEBUG",
                    # Disable security checks, "we know what we are doing"
                    "/GS-",
                    "/GR",
                ]),
            ],
        ),
        flag_set(
            actions = LINK_ACTIONS,
            flag_groups = [
                flag_group(flags = [
                    # Control flow guards
                    "/GUARD:CF",
                    "/OPT:REF",
                    "/OPT:ICF",
                ]),
            ],
        ),
    ],
)

no_ndebug_feature = feature(
    name = "no_ndebug",
    enabled = False,
    flag_sets = [
        flag_set(
            actions = C_COMPILE_ACTIONS + OBJC_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS,
            flag_groups = [
                flag_group(
                    flags = ["/UNDEBUG"],
                ),
            ],
        ),
    ],
)

output_execpath_feature = feature(
    name = "output_execpath_flags",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = LINK_ACTIONS,
            flag_groups = [
                flag_group(
                    flags = ["/OUT:%{output_execpath}"],
                    expand_if_available = "output_execpath",
                ),
            ],
        ),
    ],
)

parse_showincludes_feature = feature(
    name = "parse_showincludes",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = C_COMPILE_ACTIONS + OBJC_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS,
            flag_groups = [flag_group(flags = ["/showIncludes"])],
        ),
    ],
)

preprocessor_defines_feature = feature(
    name = "preprocessor_defines",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = C_COMPILE_ACTIONS + OBJC_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS + ASSEMBLE_ACTIONS,
            flag_groups = [
                flag_group(
                    iterate_over = "preprocessor_defines",
                    flags = ["/D%{preprocessor_defines}"],
                ),
            ],
        ),
    ],
)

shared_flag_feature = feature(
    name = "shared_flag",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = [
                ACTION_NAMES.cpp_link_dynamic_library,
                ACTION_NAMES.cpp_link_nodeps_dynamic_library,
            ],
            flag_groups = [flag_group(flags = ["/DLL"])],
        ),
    ],
)

static_link_msvcrt_feature = feature(name = "static_link_msvcrt")

supports_interface_shared_libraries_feature = feature(
    name = "supports_interface_shared_libraries",
    enabled = True,
)

targets_windows_feature = feature(
    name = "targets_windows",
    enabled = True,
)

reproducible_build_feature = get_reproducible_build_feature(
    compile_flags = [
        # Force the timestamps to a fixed value.
        "-Wno-builtin-macro-redefined",
        "/D__DATE__=\"redacted\"",
        "/D__TIMESTAMP__=\"redacted\"",
        "/D__TIME__=\"redacted\"",
        # Do not expand any symbolic links, resolve references to ‘/../’ or ‘/./’, or make
        # the path absolute when generating a relative prefix.
        "-no-canonical-prefixes",
        # Do not add the builtin lib/clang/*/include directory. This directory is already
        # added as a cc_toolchain_import using a relative path. Not setting this will
        # make the directory prepended as an absolute path, and cause include checking
        # errors when the action is cached remotely.
        "-nobuiltininc",
    ],
)

windows_export_all_symbols_feature = feature(
    name = "windows_export_all_symbols",
    enabled = True,
)

def _cc_features_impl(ctx):
    import_config = toolchain_import_configs(ctx.attr.toolchain_imports)
    all_features = flatten([
        # features set / consumed by bazel
        no_legacy_features,
        no_stripping_feature,
        dynamic_linking_mode_feature,
        static_linking_mode_feature,
        supports_dynamic_linker_feature,
        supports_interface_shared_libraries_feature,
        has_configured_linker_path_feature,
        archive_param_file_feature,
        compiler_param_file_feature,
        copy_dynamic_libraries_to_binary_feature,
        targets_windows_feature,
        windows_export_all_symbols_feature,
        no_windows_export_all_symbols_feature,
        # features for tool invocations
        rules_rust_unsupported_feature,
        preprocessor_defines_feature,
        parse_showincludes_feature,
        includes_feature,
        include_paths_feature,
        external_include_paths_feature,
        get_toolchain_include_paths_feature(import_config),
        shared_flag_feature,
        linkstamps_feature,
        output_execpath_feature,
        interface_library_output_feature,
        def_file_feature,
        static_link_msvcrt_feature,
        msvc_runtimes_feature,
        generate_pdb_file_feature,
        get_toolchain_lib_search_paths_feature(import_config),
        get_archiver_flags_feature(ctx.attr.archive_flags),
        # Start flag ordering: the order of following features impacts how
        # flags override each other.
        opt_feature,
        dbg_feature,
        fastbuild_feature,
        no_ndebug_feature,
        libraries_to_link_feature,
        get_toolchain_link_flags_feature(ctx.attr.link_flags),
        user_link_flags_feature,
        get_toolchain_compile_flags_feature(ctx.attr.compile_flags),
        get_toolchain_assembler_flags_feature(ctx.attr.assembler_flags),
        get_toolchain_cxx_flags_feature(ctx.attr.cxx_flags),
        user_compile_flags_feature,
        reproducible_build_feature,
        get_disable_all_warnings_feature(flags = ["/w"]),
        get_warnings_feature(flags = ctx.attr.warning_flags),
        get_warnings_as_errors_feature(flags = ["/WX"]),
        ### End flag ordering ##
        linker_param_file_feature,
        compiler_output_feature,
        compiler_input_feature,
    ])
    return CcFeatureConfigInfo(features = all_features)

cc_features = rule(
    implementation = _cc_features_impl,
    doc = "A rule to create features for cc toolchain config.",
    attrs = {
        "archive_flags": attr.string_list(
            doc = "Flags always added to archive actions.",
            default = [],
        ),
        "compile_flags": attr.string_list(
            doc = "Flags always added to compile actions.",
            default = [],
        ),
        "assembler_flags": attr.string_list(
            doc = "Flags always added to assembler actions.",
            default = [],
        ),
        "cxx_flags": attr.string_list(
            doc = "Flags always added to c++ compile actions.",
            default = [],
        ),
        "warning_flags": attr.string_list(
            doc = "Flags controlling compiler warnings.",
            default = [],
        ),
        "link_flags": attr.string_list(
            doc = "Flags always added to link actions in MSVC driving mode.",
            default = [],
        ),
        "toolchain_imports": attr.label_list(
            doc = "A list of cc_toolchain_import targets in MSVC driving mode.",
            providers = [CcToolchainImportInfo],
            default = [],
        ),
    },
    provides = [CcFeatureConfigInfo],
)
