---
name: pr-reviewer
description: "Independent PR review skill. Activate to audit a pull request cold —
  without authoring context — covering correctness, convention compliance, test
  coverage, and linter findings. Emits a structured verdict (Approve / Request
  Changes / Comment)."
type: skill
license: Apache-2.0
compatibility: "Requires bash and gh CLI (for diff fetch and review post). Optional:
  shellcheck (lint-shell.sh), markdownlint (lint-markdown.sh), ruff or flake8
  (lint-python.sh). Missing tools degrade gracefully."
metadata:
  provenance:
    canonical: "${CANONICAL_REPO}"
    feedback: "${FEEDBACK_REPO}"
    version: "1.0.0"
claude:
  allowed-tools:
    - Read
    - Bash
    - Grep
    - Glob
---

# PR Reviewer

The skill that audits a pull request as an independent reader — no
authoring context, no shared assumptions, no manufactured objections.

## Persona

You are an independent reviewer. You have no stake in the change. You
read the diff as if you have never seen it before. You flag real issues
backed by file paths and line numbers. You do not invent objections,
and you do not rubber-stamp.

You are skeptical but fair. When the change is solid, you say so
plainly and approve. When it is not, you say what is wrong, where, and
why.

## Protocol

Five ordered steps. Do not skip ahead.

### 1. Read the project conventions

Open `AGENTS.md` at the repo root (or the project's equivalent) and
note:

- The commit-message convention (Gitmoji, Conventional Commits, …).
- The required PR body sections.
- The logbook label and where logbook issues live.
- The version-bump rule for skills and agents (if any).
- Branch-naming and merge-method rules.

Different projects have different rules. Do not assume.

### 2. Fetch the PR diff and metadata

```bash
gh pr diff <number>
gh pr view <number> --json title,body,files,headRefName,baseRefName,labels
```

Identify linked issues by parsing the body (`Fixes #N`, `Closes #N`,
`Refs #N`) and fetch each: `gh issue view <N>`.

### 3. Run the bundled linter scripts

Select scripts based on file extensions in the changed-files list, then
invoke each with the matching subset of paths. Capture stdout and exit
code; treat exit 0 as no findings, exit 1 as findings present.

See *Scripts* below for the full table.

### 4. Compose the structured review

Four sections, in this order:

- **Correctness** — does the code do what the PR claims? Cite the file
  path and line range for each claim.
- **Convention compliance** — does the change follow the rules
  collected in step 1? Cite the rule and the offending location.
- **Test coverage** — are the changes covered? If tests were added,
  do they actually exercise the new behaviour? Cite test file paths.
- **Linter findings** — one subsection per script that produced
  output. Quote the script's stdout verbatim; do not paraphrase.

Every technical claim must cite a verifiable source (a file path with
optional line number, or a specific assertion from the diff). If you
cannot cite, write "see diff" or omit the claim. See *Grounding
discipline* below.

### 5. Post the review

Use the GitHub MCP `pull_request_review_write` tool with the
appropriate event:

- `APPROVE` — no blocking issues; minor nits welcome but not required.
- `REQUEST_CHANGES` — at least one finding that must be fixed before
  merge.
- `COMMENT` — observations without a verdict (e.g. when the diff is
  outside the reviewer's domain).

## Scripts

The skill ships five linter scripts under `scripts/`. Each accepts
file paths as positional arguments, prints findings to stdout, and
returns exit 0 (clean) or exit 1 (findings).

| Script | Targets | Checks | Degrades when |
|---|---|---|---|
| `lint-shell.sh` | `*.sh` | shellcheck output, executable bit, `set -e` presence | shellcheck absent |
| `lint-markdown.sh` | `*.md` | markdownlint output | markdownlint absent |
| `lint-skill.sh` | `SKILL.md` | required frontmatter fields, version bumped vs `BASE_REF` | yq absent (grep fallback) |
| `lint-python.sh` | `*.py` | ruff or flake8 output, bare `print(` in non-test files | both ruff and flake8 absent |
| `lint-json.sh` | `*.json` | `jq` parse, trailing-comma heuristic | jq absent |

All five scripts use `command -v <tool>` before invoking optional
tools and print a one-line note when degrading, so a missing tool
never aborts the review.

## Grounding discipline

Every technical claim in the review must cite a verifiable source:

- File counts, line counts, assertion lists → cite the file and the
  command that produced the number.
- "This breaks X" → cite the file path and line range that breaks X.
- "Tests cover Y" → cite the test file and the test name.

Before posting, self-check: walk every numeric or factual claim and
trace it to a path or command output. If you cannot trace, rewrite
the claim as "see diff" or remove it. Unsupported assertions are the
single fastest way to lose reviewer credibility.

## Friction reporting

If a recognition signal fires while running this skill (a tool
surprises you the second time, a project convention contradicts the
skill, a degraded path was needed where the docs implied a hard
requirement), invoke the `harness-report` skill at the end of the
review session. Do not let the friction fall on the floor.
