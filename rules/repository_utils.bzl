"""Shared repository rule utilities"""

def default_workspace_file_content(name, rule_name):
    return """# DO NOT EDIT: automatically generated WORKSPACE file by {rule}
workspace(name = \"{name}\")
""".format(name = name, rule = rule_name)

def is_windows(repo_ctx):
    os = repo_ctx.os.name.lower()
    return os.startswith("windows")

def run_command(command, repo_ctx, check = True, **kwargs):
    """Runs a command and returns the execution result.

    Args:
        command: The command to run as a sequence of strings. If the first
          element is a bare executable name, it is then searched for in PATH.
        repo_ctx: The repository context.
        check: When true, raise an error if the command return code is not 0.
        **kwargs: Extra arguments passed to repository_ctx.execute().

    Returns:
        The exec_result as returned by repository_ctx.execute()
    """
    executable = command[0]
    if path_separator(repo_ctx) not in executable:
        executable = repo_ctx.which(executable)
        if not executable:
            fail("Cannot run", command, ":", command[0], "is not in PATH.")
    command = [str(executable)] + command[1:]

    result = repo_ctx.execute(command, **kwargs)
    if check and result.return_code != 0:
        fail(
            "Command failed:",
            " ".join(command),
            ",",
            "returns",
            result.return_code,
            result.stderr,
        )
    return result

def is_abs_path(path_str):
    return path_str[0] == "/" or path_str[1:3] == ":\\" or path_str[0] == "\\"

def path_separator(repo_ctx):
    return "\\" if is_windows(repo_ctx) else "/"

def resolve_workspace_path(path_str, repo_ctx):
    """Resolves path_str relative to the workspace root to an absolute path."""
    if is_abs_path(path_str):
        return repo_ctx.path(path_str)
    return repo_ctx.workspace_root.get_child(path_str)

def relative_path(path_str, root):
    """Returns the path relative to root for path_str.

    Works only if both path_str and root are absolute, and path_str is a subpath of root.
    """
    return path_str.removeprefix(root).lstrip("/\\")

def create_build_file(build_file, repo_ctx, substitutions = None):
    """Create a BUILD.bazel file at root of the repository.

    Args:
        build_file: The BUILD file.
        repo_ctx: The repository context.
        substitutions: If specified, substitutions to make when expanding
            build_file as a template.
    """
    repo_ctx.delete("BUILD.bazel")
    if not substitutions:
        repo_ctx.symlink(build_file, "BUILD.bazel")
    else:
        repo_ctx.template(
            "BUILD.bazel",
            build_file,
            substitutions,
            executable = False,
        )

def create_workspace_file(workspace_file, repo_ctx, default_content = None):
    """Create a WORKSPACE file at root of the repository. At least one of workspace_file and default_content must be passed.

    Args:
        workspace_file: The WORKSPACE file.
        repo_ctx: The repository context.
        default_content: WORKSPACE content if workspace_file is None.
    """
    repo_ctx.delete("WORKSPACE.bazel")
    if workspace_file:
        repo_ctx.symlink(workspace_file, "WORKSPACE.bazel")
    elif default_content:
        repo_ctx.file("WORKSPACE.bazel", default_content, executable = False)
    else:
        fail("Cannot create repository", repo_ctx.name, ": no WORKSPACE file defined.")

def create_repo_file(repo_ctx, overwrite = False):
    """Create a REPO.bazel file at root of the repository.

    Args:
        repo_ctx: The repository context.
        overwrite: Whether or not to overwrite an existing REPO.bazel file.
    """
    if overwrite:
        repo_ctx.delete("REPO.bazel")
    repo_ctx.file("REPO.bazel", "", executable = False)

def _list_files_recursive(path, repo_ctx):
    """Lists all the files / symlinks under path, recursively.

    Directories are recursed into but not included in the list. It does not
    follow symlinks.

    Args:
        path: The root to list. The behavior of path not being a directory is
          undefined.
        repo_ctx: A repository_ctx object.

    Returns:
        A list of path tuples, each containing path segments for each file,
          relative to the root path.
    """
    if is_windows(repo_ctx):
        path = path.replace("/", "\\")
        command = ["cmd.exe", "/c", "dir /a-d /s /b"]
        result = run_command(command, repo_ctx, working_directory = path)
        return [relative_path(f, path) for f in result.stdout.splitlines()]
    else:
        command = ["find", ".", "-type", "f,l"]
        result = run_command(command, repo_ctx, working_directory = path)
        return [f.removeprefix("./") for f in result.stdout.splitlines()]

def _add_file_tree_stat(files, directories, root, file_paths, path_sep, prune_filter = None, conf_resolver = None):
    pruned_prefixes = set()
    for file_path in file_paths:
        path_seg = tuple(file_path.split(path_sep))
        prune = False
        if prune_filter:
            prune = prune_filter(root, path_seg)

        # We explicitly compare against False to exclude prune being an empty tuple.
        if prune == False and path_seg not in files:
            _add_path_stat(files, root, path_seg)
            for ancestor in _path_ancestors(path_seg):
                _add_path_stat(directories, root, ancestor)
        else:
            if type(prune) == "tuple":
                pruned_prefixes.add(prune)
            is_pruned = _handle_file_conflict(files, directories, root, path_seg, conf_resolver)
            for ancestor in _path_ancestors(path_seg):
                _add_path_stat(directories, root, ancestor, is_pruned)
    return pruned_prefixes

def _handle_file_conflict(files, directories, new_root, path_seg, resolver):
    if path_seg not in files:
        return True
    current_root = files[path_seg].keys()[0]
    resolved_root = None
    if resolver:
        resolved_root = resolver(current_root, new_root, path_seg)
    if resolved_root == current_root:
        return True
    if resolved_root == new_root:
        _prune_file(files, directories, path_seg)
        _add_path_stat(files, new_root, path_seg)
        return False
    fail("conflict when merging file tree", new_root, ":", "/".join(path_seg), "already exists in", current_root)

def _prune_file(files, directories, path_seg):
    file_stat = files.pop(path_seg)
    root = file_stat.keys()[0]
    for ancestor in _path_ancestors(path_seg):
        c = directories[ancestor][root]
        c[1] += 1

def _add_path_stat(existing_tree, root, path_seg, is_pruned = False):
    # We use the following data structure for tree stats:
    #
    # tree = {
    #   dest_path1: {
    #     contributing_root1: [#_total_files_in_tree, #_pruned_files_in_tree],
    #     ...
    #   },
    #   ...
    # }
    #
    # dest_path is a path tuple relative to the root. If dest_path is a file, it
    # will have only 1 contributing_root, and looks like:
    # dest_path: {contributing_root: [1, 0]}
    # All its ancestor directories will have #_total_files_in_tree increased.
    # If dest_path is a directory, it may have one or more contributing_roots.
    # We don't add pruned files to the tree, but we do increase the #_total_files_in_tree
    # and #_pruned_files_in_tree counts for their ancestor directories.
    #
    # When #_pruned_files_in_tree is 0, it means the whole subtree is preserved
    # from the corresponding contributing_root. When #_pruned_files_in_tree ==
    # #_total_files_in_tree, it means the whole subtree is pruned from that root.
    #
    # This structure flattens the paths so we can traverse the file tree without
    # recursion or while-loop (which are not available in starlark).
    stat = existing_tree.setdefault(path_seg, {})
    total, pruned = stat.setdefault(root, [0, 0])
    stat[root][0] = total + 1
    if is_pruned:
        stat[root][1] = pruned + 1

def _path_ancestors(path_seg):
    return [path_seg[:i] for i in range(1, len(path_seg))]

def _check_directory_conflicts(files, directories):
    for path_seg, path_stat in directories.items():
        if path_seg not in files:
            continue
        contributing_roots = [p for p, c in path_stat.items() if c[0] != c[1]]
        if contributing_roots:
            file_root = files[path_seg].keys()[0]
            fail("conflict when merging file tree", file_root, ":", "/".join(path_seg), "is a directory from", contributing_roots)

def _get_paths_to_link_or_watch(files, directories, pruned_prefixes):
    to_link = []
    to_watch = []
    linkable_roots = _get_linkable_roots(files, directories)
    for path_seg, stat in files.items() + directories.items():
        if path_seg in linkable_roots:
            # link this path only if its parent is not linkable
            if path_seg[:-1] not in linkable_roots:
                to_link.append((linkable_roots[path_seg], path_seg))
        else:
            for r, c in stat.items():
                if c[0] != c[1] or not _has_pruned_prefix(r, path_seg, pruned_prefixes):
                    to_watch.append((r, path_seg))
    return to_link, to_watch

def _get_linkable_roots(files, directories):
    linkable = {}
    for path_seg, path_stat in files.items():
        linkable[path_seg] = path_stat.keys()[0]
    for path_seg, path_stat in directories.items():
        # A root is contributing to the subtree if we need a file from it.
        contributing_roots = [p for p, c in path_stat.items() if c[0] != c[1]]
        if not contributing_roots:
            continue
        candidate = contributing_roots[0]

        # You can link the path directly from candidate if candidate is the only root
        # contributing to the subtree, and the whole subtree is preserved.
        if len(contributing_roots) == 1 and path_stat[candidate][1] == 0:
            linkable[path_seg] = candidate
    return linkable

def _has_pruned_prefix(root, path_seg, pruned_prefixes):
    if not path_seg:
        return False
    if path_seg in pruned_prefixes[root]:
        return True
    for p in _path_ancestors(path_seg):
        if p in pruned_prefixes[root]:
            return True
    return False

def merge_and_link_tree(repo_ctx, tree_roots, dest_path = "", *, prune_filter = None, conf_resolver = None):
    """Merges multiple file trees to a single symlink tree at dest path.

    An optional prune_filter can be used to prune certain paths. If multiple
    source files map to the same destination path, a conflict resolver function
    can be passed to determine which one to keep (or report as error) This
    function gaurantees to create the minimum number of symlinks in the
    destination.

    Args:
        repo_ctx: The repository_ctx object.
        tree_roots: (list[str]) The root paths of files trees.
        dest_path: (str | file) The destination root path of the symlink tree.
          If it already exists, it must be an empty directory.
        prune_filter: (function[str, tuple] -> bool | tuple) A predicate function with
          2 args (root_path, subpath_tuple). The path is preserved if it returns
          False, or pruned if it returns any other value. If returning a tuple,
          it indicates a subpath prefix that caused the prune to happen - this
          will avoid bazel watching the path for new files.
        conf_resolver: (function[str, str, tuple] -> str | None) A function for
          resolving file conflicts. It has 3 args: (root1, root2, subpath_tuple),
          and returns which root the conflict should reolve to. Returning None
          indicates that the conflict is an error. Examples:
          lambda r1, _, _: r1  # always ignore
          lambda _, r2, _: r2  # always overwrite
          lambda r1, r2, p: min(r1, r2, key=len) if "bin" in p else None  # prefer shorter path for binaries, error otherwise
    """
    dest_path = repo_ctx.path(dest_path)
    if dest_path.exists:
        if not dest_path.is_dir:
            fail("dest path", dest_path, "is an existing file.")
        entries = dest_path.readdir()
        if entries:
            fail("dest path", dest_path, "is a non-empty directory containing:", entries)
    file_stat = {}
    directory_stat = {}
    pruned_prefixes = {}
    path_sep = path_separator(repo_ctx)
    for root in tree_roots:
        file_paths = _list_files_recursive(root, repo_ctx)
        pruned_prefixes[root] = _add_file_tree_stat(file_stat, directory_stat, root, file_paths, path_sep, prune_filter, conf_resolver)
    _check_directory_conflicts(file_stat, directory_stat)
    to_link, to_watch = _get_paths_to_link_or_watch(file_stat, directory_stat, pruned_prefixes)
    for r, p in to_link:
        subpath = path_sep.join(p)
        src = repo_ctx.path(r).get_child(subpath)
        dest = subpath
        if dest_path:
            dest = dest_path.get_child(subpath)
        repo_ctx.symlink(src, dest)
    for r, p in to_watch:
        subpath = path_sep.join(p)
        repo_ctx.path(r).get_child(subpath).readdir()
