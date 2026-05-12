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
        return 0

    opened = []
    failures = []
    for c in clusters:
        target = c["target_repo"]
        title = c["title"]
        print(f"--- Opening issue on {target}: {title}")
        cmd = _build_cmd(c)
        try:
            result = subprocess.run(cmd, check=True, capture_output=True, text=True)
            opened.append({"cluster": c["cluster_key"], "url": result.stdout.strip()})
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
