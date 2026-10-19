"""Platform and tool independent toolchain rules."""

load(
    "@rules_cc//cc:cc_toolchain_config_lib.bzl",
    "ArtifactNamePatternInfo",
    "artifact_name_pattern",
    "env_entry",
    "env_set",
    "feature",
    "flag_group",
    "flag_set",
)
load("@rules_cc//cc:defs.bzl", "CcToolchainConfigInfo", "cc_common")
load(":actions.bzl", "create_action_configs")
load(":utils.bzl", "filter_none")

CcToolInfo = provider(
    "A provider that specifies metadata for a tool.",
    fields = {
        "tool": "A File object to be used as the tool executable.",
        "applied_actions": "Cc actions where this tool applies.",
        "with_features": "Feature names that need to be enabled to select this tool.",
        "with_no_features": "Feature names that need to be disabled to select this tool.",
        "env": "A map of environment variables applied when running the tool.",
        "args": "A list of args always passed to the tool",
    },
)

def _cc_tool_impl(ctx):
    runfiles = ctx.runfiles(
        files = [ctx.executable.tool] + ctx.files.runfiles,
    )
    runfiles = runfiles.merge(ctx.attr.tool[DefaultInfo].default_runfiles)
    expandable_targets = ctx.attr.runfiles + [ctx.attr.tool]
    expanded_env = {
        k: ctx.expand_location(v, expandable_targets)
        for k, v in ctx.attr.env.items()
    }
    expanded_args = [
        ctx.expand_location(arg, expandable_targets)
        for arg in ctx.attr.args
    ]
    return [
        CcToolInfo(
            tool = ctx.executable.tool,
            applied_actions = ctx.attr.applied_actions,
            with_features = ctx.features,
            with_no_features = ctx.disabled_features,
            env = expanded_env,
            args = expanded_args,
        ),
        DefaultInfo(
            files = depset([ctx.executable.tool] + ctx.files.runfiles),
            runfiles = runfiles,
        ),
    ]

cc_tool = rule(
    implementation = _cc_tool_impl,
    attrs = {
        "tool": attr.label(
            doc = "The tool target.",
            allow_files = True,
            executable = True,
            cfg = "exec",
            mandatory = True,
        ),
        "runfiles": attr.label_list(
            doc = "Other files needed to run the tool, in addition to what provided by the tool target.",
            allow_files = True,
            cfg = "exec",
        ),
        "applied_actions": attr.string_list(
            doc = "A list of cc action names where the tool applies.",
            mandatory = True,
            allow_empty = False,
        ),
        "env": attr.string_dict(
            doc = "A map of strings containing the environment variables applied. Values in the map are subject to location expansions.",
        ),
        "args": attr.string_list(
            doc = "A list of arguments to be passed to the tool, subject to location expansions.",
        ),
    },
    provides = [CcToolInfo, DefaultInfo],
)

CcToolchainImportInfo = provider(
    doc = "Provides info about the imported toolchain library.",
    fields = {
        "include_paths": "Include directories for this library.",
        "dynamic_runtimes": "Libraries used as the dynamic runtime library of cc_toolchain.",
        "framework_paths": "Framework search directories to add.",
        "lib_search_paths": "Additional library search paths.",
        "static_runtimes": "Libraries used as the static runtime library of cc_toolchain.",
    },
)

def _cc_toolchain_import_impl(ctx):
    include_paths = [p.path for p in ctx.files.include_paths]
    framework_paths = [p.path for p in ctx.files.framework_paths]
    lib_search_paths = [p.path for p in ctx.files.lib_search_paths]
    static_runtimes = ctx.files.static_mode_libs
    dynamic_runtimes = ctx.files.dynamic_mode_libs

    dep_include_paths = [
        dep[CcToolchainImportInfo].include_paths
        for dep in ctx.attr.deps
    ]
    dep_framework_paths = [
        dep[CcToolchainImportInfo].framework_paths
        for dep in ctx.attr.deps
    ]
    dep_lib_search_paths = [
        dep[CcToolchainImportInfo].lib_search_paths
        for dep in ctx.attr.deps
    ]
    dep_dynamic_runtimes = [
        dep[CcToolchainImportInfo].dynamic_runtimes
        for dep in ctx.attr.deps
    ]
    dep_static_runtimes = [
        dep[CcToolchainImportInfo].static_runtimes
        for dep in ctx.attr.deps
    ]

    return [
        CcToolchainImportInfo(
            include_paths = depset(
                direct = include_paths,
                transitive = dep_include_paths,
                order = "topological",
            ),
            framework_paths = depset(
                direct = framework_paths,
                transitive = dep_framework_paths,
                order = "topological",
            ),
            lib_search_paths = depset(
                direct = lib_search_paths,
                transitive = dep_lib_search_paths,
                order = "topological",
            ),
            dynamic_runtimes = depset(
                direct = dynamic_runtimes,
                transitive = dep_dynamic_runtimes,
                order = "topological",
            ),
            static_runtimes = depset(
                direct = static_runtimes,
                transitive = dep_static_runtimes,
                order = "topological",
            ),
        ),
        DefaultInfo(
            files = depset(
                direct = ctx.files.dynamic_mode_libs +
                         ctx.files.static_mode_libs +
                         ctx.files.support_files,
                transitive = [dep[DefaultInfo].files for dep in ctx.attr.deps],
            ),
        ),
    ]

cc_toolchain_import = rule(
    implementation = _cc_toolchain_import_impl,
    doc = "A rule that works like cc_import but at the toolchain level.",
    attrs = {
        "include_paths": attr.label_list(
            default = [],
            doc = "Include paths to search for headers.",
            allow_files = True,
        ),
        "framework_paths": attr.label_list(
            default = [],
            doc = "Framework search paths to add. This has no effect on Windows.",
            allow_files = True,
        ),
        "dynamic_mode_libs": attr.label_list(
            default = [],
            doc = "Libraries to be linked in dynamic linking mode." +
                  "\n" +
                  "These libraries will be passed to cc_toolchain as " +
                  "'dynamic_runtime_lib', which places them in the runpath.",
            allow_files = True,
        ),
        "static_mode_libs": attr.label_list(
            default = [],
            doc = "Libraries to be linked in static linking mode." +
                  "\n" +
                  "These libraries will be passed to cc_toolchain as " +
                  "'static_runtime_lib' (requires all libs to be static).",
            allow_files = True,
        ),
        "lib_search_paths": attr.label_list(
            default = [],
            doc = "Additional library search paths." +
                  "\n" +
                  "Useful to add search paths without always linking a lib.",
            allow_files = True,
        ),
        "support_files": attr.label_list(
            default = [],
            doc = "Files needed but not forcefully linked.",
            allow_files = True,
        ),
        "deps": attr.label_list(
            default = [],
            doc = "Other cc_toolchain_import rules to depend on.",
            providers = [CcToolchainImportInfo, DefaultInfo],
        ),
    },
    provides = [CcToolchainImportInfo, DefaultInfo],
)

def _cc_toolchain_runtime_impl(ctx):
    if ctx.attr._use_dynamic:
        get_field = lambda x: x.dynamic_runtimes
    else:
        get_field = lambda x: x.static_runtimes

    lib_files = depset(
        transitive = [get_field(lib[CcToolchainImportInfo]) for lib in ctx.attr.libs],
        order = "topological",
    )
    return DefaultInfo(
        files = lib_files,
    )

cc_toolchain_dynamic_runtime = rule(
    implementation = _cc_toolchain_runtime_impl,
    doc = "Creates the runtime library for dynamically linked libraries, matching the dynamic_runtime_lib attribute of a cc_toolchain.",
    attrs = {
        "libs": attr.label_list(
            doc = "The cc_toolchain_import rules to consume.",
            providers = [CcToolchainImportInfo],
            mandatory = True,
        ),
        "_use_dynamic": attr.bool(default = True),
    },
)

cc_toolchain_static_runtime = rule(
    implementation = _cc_toolchain_runtime_impl,
    doc = "Creates the runtime library for statically linked libraries, matching the static_runtime_lib attribute of a cc_toolchain.",
    attrs = {
        "libs": attr.label_list(
            doc = "The cc_toolchain_import rules to consume.",
            providers = [CcToolchainImportInfo],
            mandatory = True,
        ),
        "_use_dynamic": attr.bool(default = False),
    },
)

CcFeatureConfigInfo = provider(
    doc = "Provides info about the configured features.",
    fields = {
        "features": "A list of ordered FeatureInfo",
    },
)

SysrootInfo = provider(
    doc = "Contains a sysroot path.",
    fields = ["path"],
)

def _sysroot_impl(ctx):
    sysroot_path = ctx.attr.path or ""
    if not sysroot_path.startswith("/"):
        sysroot_path = "/".join([s for s in (
            ctx.label.workspace_root,
            ctx.label.package,
            sysroot_path.rstrip("/"),
        ) if s])
    return [
        SysrootInfo(path = sysroot_path),
        DefaultInfo(files = depset(direct = ctx.files.all_files)),
    ]

sysroot = rule(
    implementation = _sysroot_impl,
    attrs = {
        "path": attr.string(
            doc = "Package relative path to the sysroot directory.",
        ),
        "all_files": attr.label_list(
            default = [],
            doc = "All relevant files shipped to the sandbox.",
            allow_files = True,
        ),
    },
)

def _cc_artifact_name_impl(ctx):
    return artifact_name_pattern(
        category_name = ctx.attr.category,
        prefix = ctx.attr.prefix,
        extension = ctx.attr.extension,
    )

cc_artifact_name = rule(
    implementation = _cc_artifact_name_impl,
    doc = "Creates an artifact filename pattern for generated artifacts.",
    attrs = {
        "category": attr.string(
            doc = "Category name of the artifact.",
            mandatory = True,
            values = [
                "static_library",
                "alwayslink_static_library",
                "dynamic_library",
                "executable",
                "interface_library",
                "pic_file",
                "included_file_list",
                "serialized_diagnostics_file",
                "object_file",
                "pic_object_file",
                "cpp_module",
                "generated_assembly",
                "processed_header",
                "generated_header",
                "preprocessed_c_source",
                "preprocessed_cpp_source",
                "coverage_data_file",
                "clif_output_proto",
            ],
        ),
        "prefix": attr.string(doc = "Filename prefix.", default = ""),
        "extension": attr.string(doc = "File extension.", default = ""),
    },
    provides = [ArtifactNamePatternInfo],
)

def _toolchain_files(ctx):
    toolchain_import_files = [
        lib[DefaultInfo].files
        for lib in ctx.attr.toolchain_imports
    ]
    tool_files = [tool[DefaultInfo].files for tool in ctx.attr.cc_tools]
    tool_runfiles = [
        tool[DefaultInfo].default_runfiles.files
        for tool in ctx.attr.cc_tools
    ]
    sysroot_files = [
        ctx.attr.sysroot[DefaultInfo].files,
    ] if ctx.attr.sysroot else []
    return depset(
        transitive = toolchain_import_files + tool_files + tool_runfiles +
                     sysroot_files,
    )

def _cc_tools_env_args_feature(tool_configs):
    """Creates a feature that applies the env variables and arguments from the CcToolInfo providers.

    Args:
        tool_configs: A list of CcToolInfo providers.

    Returns:
        None if no args or env variables are passed by the providers. Otherwise
        a FeatureInfo.
    """
    flag_sets = [
        flag_set(
            actions = t.applied_actions,
            flag_groups = flag_group(flags = t.args),
        )
        for t in tool_configs
        if t.args
    ]
    env_sets = [
        env_set(
            actions = t.applied_actions,
            env_entries = [env_entry(k, v) for k, v in t.env.items()],
        )
        for t in tool_configs
        if t.env
    ]
    if not flag_sets and not env_sets:
        return None
    return feature(
        name = "cc_tool_feature",
        enabled = True,
        flag_sets = flag_sets,
        env_sets = env_sets,
    )

def _cc_toolchain_config_impl(ctx):
    sysroot = ctx.attr.sysroot[SysrootInfo].path if ctx.attr.sysroot else None
    features = filter_none([
        _cc_tools_env_args_feature(
            [tool[CcToolInfo] for tool in ctx.attr.cc_tools],
        ),
    ])
    features.extend(ctx.attr.cc_features[CcFeatureConfigInfo].features)
    return [
        cc_common.create_cc_toolchain_config_info(
            ctx = ctx,
            toolchain_identifier = ctx.attr.identifier,
            features = features,
            action_configs = create_action_configs(
                [(tool.label, tool[CcToolInfo]) for tool in ctx.attr.cc_tools],
            ),
            artifact_name_patterns = [
                p[ArtifactNamePatternInfo]
                for p in ctx.attr.artifact_name_patterns
            ],
            builtin_sysroot = sysroot,
            cxx_builtin_include_directories = ctx.attr.legacy_builtin_include_directories,
            target_cpu = ctx.attr.target_cpu,
            # This is needed by targets using legacy compiler flag value.
            compiler = ctx.attr.compiler_name,
            # The attributes below are required by the constructor, but don't
            # affect actions at all.
            target_system_name = "__toolchain_target_system_name__",
            target_libc = "__toolchain_target_libc__",
            abi_version = "__toolchain_abi_version__",
            abi_libc_version = "__toolchain_abi_libc_version__",
        ),
        DefaultInfo(
            files = _toolchain_files(ctx),
        ),
    ]

cc_toolchain_config = rule(
    implementation = _cc_toolchain_config_impl,
    attrs = {
        "identifier": attr.string(
            doc = "Unique toolchain identifier.",
            mandatory = True,
        ),
        "cc_tools": attr.label_list(
            doc = "A list of targets that provides CcToolInfo.",
            mandatory = True,
            allow_empty = False,
            providers = [CcToolInfo, DefaultInfo],
        ),
        "cc_features": attr.label(
            doc = "A target that provides CcFeatureConfigInfo.",
            mandatory = True,
            providers = [CcFeatureConfigInfo],
        ),
        "artifact_name_patterns": attr.label_list(
            doc = "A list of name patterns for generated artifacts.",
            providers = [ArtifactNamePatternInfo],
            default = [],
        ),
        "target_cpu": attr.string(
            doc = "Target CPU architecture. This only affects the directory name of execution and output trees.",
            mandatory = True,
        ),
        "compiler_name": attr.string(
            doc = "C compiler name. Used by targets to select on the compiler name.",
            default = "unknown",
            values = ["clang", "clang-cl", "gcc", "msvc-cl", "mingw", "unknown"],
        ),
        "toolchain_imports": attr.label_list(
            doc = "A list of cc_toolchain_import targets.",
            providers = [DefaultInfo],
            default = [],
        ),
        "sysroot": attr.label(
            doc = "A target that provides SysrootInfo and related files.",
            providers = [SysrootInfo, DefaultInfo],
        ),
        "legacy_builtin_include_directories": attr.string_list(
            doc = "Built-in include directories in addition to the ones passed from " +
                  "'toolchain_imports'. This accepts absolute paths and therefore " +
                  "is considerred non-hermetic. Prefer 'toolchain_imports' if possible",
        ),
    },
    provides = [CcToolchainConfigInfo, DefaultInfo],
)
