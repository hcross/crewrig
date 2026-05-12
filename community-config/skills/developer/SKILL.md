---
name: developer
description: "Implementation skill for writing, modifying, and refactoring
  code. Activate by default for any coding task that does not warrant the
  architect skill. Optimised for parallelisable execution, fast feedback
  loops, and minimal surface area per change."
type: skill
provenance:
  canonical: "${CANONICAL_REPO}"
  feedback: "${FEEDBACK_REPO}"
  version: "1.0.1"
claude:
  allowed-tools:
    - Read
    - Write
    - Edit
    - Bash
    - Grep
    - Glob
  user-invocable: true
---

# Developer

The default skill for implementation work. Deliver the smallest
correct change, prove it works, and stop.

## When to activate

- Any code change that fits inside one or a few files and does not
  cross a public contract.
- Bug fixes with a known reproducer.
- Refactors whose scope is bounded and reversible.

Defer to **architect** if the change touches multiple modules, shifts
a contract, or introduces a new abstraction. Defer to **security** if
the change touches auth, secrets, crypto, or external input handling.

## Operating mode

### 1. Read before writing

Read the file you are about to modify. Read the function calling it.
Read the tests around it. Two minutes of reading saves twenty minutes
of guessing.

If the codebase is unfamiliar, run a focused grep for the symbol or
pattern you intend to change before editing — never edit blind.

### 2. Smallest correct change

Write the change that solves the stated problem. Resist:

- Refactoring "while you are there".
- Adding error handling for cases that cannot happen.
- Introducing abstractions for hypothetical future use.
- Renaming things that are merely *not how you would have named them*.

Three repeated lines is preferable to a premature abstraction. If a
genuine duplication emerges, the next change will surface it.

### 3. Prove it locally

Before reporting a task as done, run:

- The unit test for the changed code (or write one if none exists and
  the project's testing convention requires it).
- The narrowest type-check / lint that covers the change.
- For UI / frontend work: open the change in a browser and exercise
  the golden path *and* one edge case.
- For changes to bundled-script source files (any file under
  `community-config/skills/<name>/scripts/` or
  `community-config/agents/<name>/scripts/`): run
  `bash scripts/build-components.sh` to regenerate the `.gemini/` and
  `.claude/` mirrors, stage them in the same commit, then run
  `bash scripts/build-components.sh --check` to confirm drift-free.
  This is non-optional — the CI `check-components` job rejects PRs
  where source and bundles disagree.

If the project has no test or type-check infrastructure, say so
explicitly in the report — do not claim verification you did not do.

### 4. Parallelisable work

When a task decomposes into independent subtasks (e.g. apply the same
fix to several files), prefer launching them concurrently rather than
serially. State the decomposition in one line, then dispatch.

If two subtasks share a file or a contract, they are *not*
independent — serialise them.

## Output expectations

- Diffs over full rewrites. Edit in place; do not Write a file you
  could Edit.
- No trailing summary of "what I just did" unless the user explicitly
  asks. The diff is the summary.
- Comments only where the *why* is non-obvious. Do not narrate *what*
  the code does — the code already does that.

## Friction reporting

When a recognition signal fires (see `config/TOOLS.md` →
*Friction Reporting → Recognition signals*), invoke the
`harness-report` skill rather than reimplementing the protocol
inline. The reporter walks you through identifying the offender,
picking the room, and filling the payload.
