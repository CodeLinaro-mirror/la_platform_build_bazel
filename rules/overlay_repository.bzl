"""A repository rule to create free-form overlay repositories."""

load(
    ":repository_utils.bzl",
    "create_repo_file",
    "merge_and_link_tree",
    "resolve_workspace_path",
)

def _overlay_repository_impl(repo_ctx):
    """Creates a repository with overlays."""
    if repo_ctx.attr.path:
        path = resolve_workspace_path(repo_ctx.attr.path, repo_ctx)
        if not path.exists and not repo_ctx.attr.not_found_ok:
            fail("path", path, "does not exist")
        repo_ctx.watch(path)
        if path.exists:
            overlay_paths = {tuple(k.split("/")): True for k in repo_ctx.attr.overlay_files.keys()}
            overlay_paths.update({tuple(k.split("/")): True for k in repo_ctx.attr.overlay_contents.keys()})
            merge_and_link_tree(repo_ctx, [str(path)], prune_filter = lambda _, p: p in overlay_paths)

    for dest_path, src in repo_ctx.attr.overlay_files.items():
        repo_ctx.symlink(src, dest_path)
    for dest_path, contents in repo_ctx.attr.overlay_contents.items():
        repo_ctx.file(dest_path, contents, executable = False)

    if not repo_ctx.path("REPO.bazel").exists:
        create_repo_file(repo_ctx)

overlay_repository = repository_rule(
    implementation = _overlay_repository_impl,
    local = True,
    doc = "Creates a repository with overlays.",
    attrs = {
        "path": attr.string(
            doc = "A directory whose contents are used as the base of the repository.",
        ),
        "not_found_ok": attr.bool(
            doc = "Ignore non-existent path.",
        ),
        "overlay_files": attr.string_keyed_label_dict(
            doc = "A dictionary where keys are dest paths in the repo and values are labels of the sources.",
        ),
        "overlay_contents": attr.string_dict(
            doc = "A dictionary where keys are dest paths in the repo and values are contents of the files.",
        ),
    },
)
