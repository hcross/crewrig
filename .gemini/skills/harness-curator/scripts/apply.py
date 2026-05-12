#!/usr/bin/env python3
"""harness_curate — Apply step.

Reads the cluster JSON emitted by ``curate.py`` on stdin and either opens
one GitHub issue per cluster via ``gh issue create`` (default) or, with
``--dry-run-apply``, prints the resolved ``gh`` argv as one JSON line per
cluster without running anything.

The script is invoked by ``curate.sh`` through ``$MEMPALACE_PYTHON``
rather than via shebang exec, so that any future ``from mempalace …``
import resolves against the same interpreter that ``curate.py`` uses.
The ``#!/usr/bin/env python3`` shebang above is kept so a human can still
run the script standalone for debugging.
"""

import argparse
import json
import os
import subprocess
import sys


def _build_cmd(cluster: dict) -> list[str]:
    target = cluster["target_repo"]
    title = cluster["title"]
    body = cluster["body"]
    labels = cluster.get("labels", ["harness-feedback"])
    cmd = [
        "gh", "issue", "create",
        "--repo", target.replace("https://github.com/", ""),
        "--title", title,
        "--body", body,
    ]
    for lbl in labels:
        cmd.extend(["--label", lbl])
    return cmd


def _collect_drawer_ids(cluster: dict) -> tuple[list[str], int]:
    """Return (present_ids, missing_count). Caller emits a stderr warning
    when missing > 0 so frictions without `_drawer_id` are surfaced rather
    than silently dropped from the write-back set."""
    ids: list[str] = []
    missing = 0
    for fr in cluster.get("frictions", []):
        did = fr.get("_drawer_id")
        if did:
            ids.append(did)
        else:
            missing += 1
    return ids, missing


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run-apply",
        action="store_true",
        help="Print the resolved gh argv per cluster as JSON lines and exit 0.",
    )
    args = parser.parse_args()

    data = json.load(sys.stdin)
    clusters = data.get("clusters", [])
    if not clusters:
        print("No clusters above threshold; no issues to open.")
        return 0

    if args.dry_run_apply:
        for c in clusters:
            print(json.dumps(_build_cmd(c)))
            # Issue #69: surface the drawers that would receive the
            # `opened_as` correlation stamp. Object shape (not array) so
            # existing argv-array assertions (`grep '^\['`) ignore it.
            drawer_ids, missing = _collect_drawer_ids(c)
            if missing:
                print(
                    f"  warn: cluster '{c['cluster_key']}' has {missing} "
                    "friction(s) without _drawer_id; will not be stamped.",
                    file=sys.stderr,
                )
            print(json.dumps({
                "would_update_drawers": drawer_ids,
                "cluster_key": c["cluster_key"],
            }))
        return 0

    # Real --apply path. Capture a duped fd 1 BEFORE importing
    # mempalace.mcp_server — that import swaps sys.stdout to keep the
    # MCP JSON-RPC channel clean (same hazard documented in
    # config/TOOLS.md and motivating curate.py's module-top dup). Result
    # URLs and the run summary go through _real_stdout so the caller
    # can capture them; progress messages route to stderr explicitly.
    _real_stdout = os.fdopen(os.dup(1), "w", encoding="utf-8", closefd=False)
    from mempalace.mcp_server import tool_get_drawer, tool_update_drawer

    opened = []
    failures = []
    writeback_failures = 0
    for c in clusters:
        target = c["target_repo"]
        title = c["title"]
        print(f"--- Opening issue on {target}: {title}", file=sys.stderr)
        cmd = _build_cmd(c)
        try:
            result = subprocess.run(cmd, check=True, capture_output=True, text=True)
            url = result.stdout.strip()
            opened.append({"cluster": c["cluster_key"], "url": url})
            # Write-back: stamp `opened_as: <url>` on every drawer that
            # contributed to the cluster (issue #69). Re-fetch then
            # update because tool_update_drawer REPLACES content; this
            # narrows the clobber window against concurrent edits.
            # Partial failures are counted and logged but do NOT mark
            # the cluster failed — the issue is already opened on
            # GitHub. The aggregate is surfaced in the final summary so
            # the maintainer sees that some drawers remain unstamped.
            drawer_ids, missing = _collect_drawer_ids(c)
            if missing:
                print(
                    f"  warn: cluster '{c['cluster_key']}' has {missing} "
                    "friction(s) without _drawer_id; will not be stamped.",
                    file=sys.stderr,
                )
            for did in drawer_ids:
                try:
                    drawer = tool_get_drawer(drawer_id=did)
                    new_content = drawer["content"].rstrip() + f"\nopened_as: {url}\n"
                    tool_update_drawer(drawer_id=did, content=new_content)
                except Exception as wb_err:  # noqa: BLE001 — best-effort write-back
                    writeback_failures += 1
                    print(
                        f"  warn: failed to stamp opened_as on drawer {did}: {wb_err}",
                        file=sys.stderr,
                    )
        except subprocess.CalledProcessError as e:
            failures.append({"cluster": c["cluster_key"], "error": e.stderr.strip()})

    print("", file=_real_stdout)
    print(f"Opened: {len(opened)} issue(s)", file=_real_stdout)
    for o in opened:
        print(f"  - {o['cluster']}: {o['url']}", file=_real_stdout)
    _real_stdout.flush()
    if writeback_failures:
        print(
            f"Write-back failures: {writeback_failures} drawer(s) not stamped; "
            "next curator run may re-open these issues.",
            file=sys.stderr,
        )
    if failures:
        print(f"Failures: {len(failures)}", file=sys.stderr)
        for f in failures:
            print(f"  - {f['cluster']}: {f['error']}", file=sys.stderr)
        return 4
    return 0


if __name__ == "__main__":
    sys.exit(main())
