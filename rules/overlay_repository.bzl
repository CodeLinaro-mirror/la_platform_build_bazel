"""A repository rule to create free-form overlay repositories."""

load(
    ":repository_utils.bzl",
    "create_repo_file",
    "merge_and_link_tree",
    "resolve_workspace_path",
)

def _validate_overlay_dest(dest, attr_name):
    """Fails unless dest is a legal relative path, and returns its segments."""
    segs = tuple(dest.split("/"))
    for s in segs:
        if s in ("", ".", ".."):
            fail(attr_name, "destination path must be a normalized relative path:", repr(dest))
    return segs

def _collect_and_validate_overlays(repo_ctx):
    """Checks that overlay destinations are disjoint and returns them as a set of segment tuples."""
    entries = []
    for attr_name, overlays in [
        ("overlay_files", repo_ctx.attr.overlay_files),
        ("overlay_contents", repo_ctx.attr.overlay_contents),
        ("overlay_paths", repo_ctx.attr.overlay_paths),
    ]:
        for dest in overlays:
            entries.append((_validate_overlay_dest(dest, attr_name), attr_name))

    # Sorting path segment tuples puts any path right after a path that is
    # equal to it or one of its ancestors, so checking neighbors finds overlaps.
    sorted_entries = sorted(entries)
    for i in range(len(sorted_entries) - 1):
        prev_segs, prev_attr = sorted_entries[i]
        curr_segs, curr_attr = sorted_entries[i + 1]
        if curr_segs[:len(prev_segs)] == prev_segs:
            fail(
                "Overlapping overlays are not allowed: '{}' (in {}) and '{}' (in {})".format(
                    "/".join(prev_segs),
                    prev_attr,
                    "/".join(curr_segs),
                    curr_attr,
                ),
            )

    return set([segs for segs, _ in entries])

def _make_prune_filter(dests):
    """Prunes any base path at or under an overlay destination."""

    def _prune(_, p):
        for i in range(1, len(p) + 1):
            if p[:i] in dests:
                return p[:i]
        return False

    return _prune

def _overlay_repository_impl(repo_ctx):
    """Creates a repository with overlays."""
    dests = _collect_and_validate_overlays(repo_ctx)

    if repo_ctx.attr.path:
        path = resolve_workspace_path(repo_ctx.attr.path, repo_ctx)
        if not path.exists and not repo_ctx.attr.not_found_ok:
            fail("path", path, "does not exist")
        repo_ctx.watch(path)
        if path.exists:
            merge_and_link_tree(repo_ctx, [str(path)], prune_filter = _make_prune_filter(dests))

    for dest, src in repo_ctx.attr.overlay_paths.items():
        if not src:
            fail("overlay_paths source for", dest, "must not be empty")
        src_path = resolve_workspace_path(src, repo_ctx)
        if not src_path.exists and not repo_ctx.attr.not_found_ok:
            fail("path", src_path, "does not exist")
        repo_ctx.watch(src_path)
        if src_path.exists:
            repo_ctx.symlink(src_path, dest)
    for dest, src in repo_ctx.attr.overlay_files.items():
        repo_ctx.symlink(src, dest)
    for dest, contents in repo_ctx.attr.overlay_contents.items():
        repo_ctx.file(dest, contents, executable = False)

    if not repo_ctx.path("REPO.bazel").exists:
        create_repo_file(repo_ctx)

overlay_repository = repository_rule(
    implementation = _overlay_repository_impl,
    local = True,
    doc = "Creates a repository with disjoint overlays (destinations across overlay_* attributes must not overlap).",
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
        "overlay_paths": attr.string_dict(
            doc = "A dictionary where keys are dest paths in the repo and values are source paths (absolute, or relative to workspace root). Must not overlap with other overlay_* destinations.",
        ),
    },
)
