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
            drawer_ids = [
                fr.get("_drawer_id", "")
                for fr in c.get("frictions", [])
                if fr.get("_drawer_id")
            ]
            print(json.dumps({
                "would_update_drawers": drawer_ids,
                "cluster_key": c["cluster_key"],
            }))
        return 0

    # Lazy import: only the real --apply path needs mempalace MCP. The
    # dry-run path above must stay import-free (curate.py owns the
    # stdout-hijack workaround at module load — apply.py runs as a
    # standalone process and would inherit no such protection).
    from mempalace.mcp_server import tool_get_drawer, tool_update_drawer

    opened = []
    failures = []
    for c in clusters:
        target = c["target_repo"]
        title = c["title"]
        print(f"--- Opening issue on {target}: {title}")
        cmd = _build_cmd(c)
        try:
            result = subprocess.run(cmd, check=True, capture_output=True, text=True)
            url = result.stdout.strip()
            opened.append({"cluster": c["cluster_key"], "url": url})
            # Write-back: stamp `opened_as: <url>` on every drawer that
            # contributed to the cluster (issue #69). Re-fetch then
            # update because tool_update_drawer REPLACES content; this
            # narrows the clobber window against concurrent edits.
            # Partial failures are logged but do NOT mark the cluster
            # failed — the issue is already opened on GitHub.
            for fr in c.get("frictions", []):
                did = fr.get("_drawer_id")
                if not did:
                    continue
                try:
                    drawer = tool_get_drawer(drawer_id=did)
                    new_content = drawer["content"].rstrip() + f"\nopened_as: {url}\n"
                    tool_update_drawer(drawer_id=did, content=new_content)
                except Exception as wb_err:  # noqa: BLE001 — best-effort write-back
                    print(
                        f"  warn: failed to stamp opened_as on drawer {did}: {wb_err}",
                        file=sys.stderr,
                    )
        except subprocess.CalledProcessError as e:
            failures.append({"cluster": c["cluster_key"], "error": e.stderr.strip()})

    print()
    print(f"Opened: {len(opened)} issue(s)")
    for o in opened:
        print(f"  - {o['cluster']}: {o['url']}")
    if failures:
        print(f"Failures: {len(failures)}", file=sys.stderr)
        for f in failures:
            print(f"  - {f['cluster']}: {f['error']}", file=sys.stderr)
        return 4
    return 0


if __name__ == "__main__":
    sys.exit(main())
