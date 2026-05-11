---
name: pr-logbook
description: "Pull request and logbook composer. Activate when opening a PR, updating a PR description, or appending to a logbook issue. Produces titles, bodies, test plans, and logbook entries that conform to the project's AGENTS.md conventions."
allowed-tools:
  - Read
  - Bash
user-invocable: true
provenance:
  canonical: "https://github.com/hcross/crewrig"
  feedback: "https://github.com/hcross/crewrig"
  version: "1.0.2"
---


# PR & Logbook Composer

The skill that turns a finished change into a PR a reviewer can read in
under five minutes, and a logbook entry the next agent can pick up cold.

## When to activate

- Opening a new PR.
- Updating the body of an existing PR after review feedback.
- Appending a logbook entry to the PR's linked issue.
- Drafting the squash-merge commit message.

## Operating mode

### 1. Read the project's PR contract

Before composing, read the project's `AGENTS.md` (or equivalent) for:

- The required PR sections.
- The commit-message convention (Gitmoji, Conventional Commits, etc.).
- The logbook label and where logbook issues live.
- Any branch-naming or merge-method rules.

Do not assume a convention. The same crew of agents serves repos with
different rules.

### 2. PR title

- Under 70 characters. Imperative mood. No trailing period.
- For Gitmoji projects, lead with the appropriate emoji.
- The title states *what* changed, not *why*. The body explains *why*.

### 3. PR body — read this first / how to test / detailed

Default crewrig template — adapt to the project's `AGENTS.md` if it
specifies otherwise:

```markdown
<Two sentences max — purpose, for a human reader.>

## How to read this PR?

<Reading order. Highlight the load-bearing files. Call out
non-obvious design decisions and why they were made.>

## How to test this PR?

<Step-by-step. Prerequisites, commands, expected outcomes. Cover the
golden path and at least one failure mode.>

## Detailed description (for agents)

<Structured walkthrough of every change, intended for the next agent
that touches this code. Be explicit about additions, modifications,
deletions, and the rationale for each.>
```

### 4. Logbook entries

A logbook is *not* a status update. It is the record the next agent
will read to avoid your mistakes. Optimise for that reader.

```markdown
### YYYY-MM-DD — <one-line topic>

**Context**: <what task / PR this entry attaches to>

**What was tried**: <decision or experiment>

**Outcome**: <green / red / partial — with link to evidence>

**Lesson**: <the durable insight, in one sentence>
```

Append, never rewrite. Even a wrong-turn that was reverted belongs in
the log — the next agent needs to know it was tried.

### 5. Squash-merge commit message

When the project squash-merges, the commit message is what survives in
`git log` forever. Compose it deliberately:

```text
<gitmoji or convention> <imperative-title> (#<pr-number>)

<one paragraph: what the PR delivered, in past tense>

<one paragraph: why — the constraint or motivation that drove it>

<bullet list of significant follow-ups, if any>

Co-authored-by lines, if any.
```

Do not paste the entire PR description. The commit message is denser.

## Cross-cutting: skill / agent source version bumps

This is not a step in the composition lifecycle — it is a *rule*
that applies to any PR you compose whose diff touches a
`community-config/skills/*/SKILL.md` or
`community-config/agents/*/AGENT.md` source. The PR MUST bump
`provenance.version` in the same diff. The rule is enforced by
`scripts/check-skill-versions.sh` in CI (and locally via
`task check-skill-versions`).

SemVer applies:

- **PATCH** for friction-driven fixes and wording changes (the
  common case — most curator-driven fixes are PATCH).
- **MINOR** for additive changes (new section, new recognition
  signal, new optional payload field).
- **MAJOR** for breaking contract changes (removed payload fields,
  renamed required fields, semantics flip).

A "version-only bump" PR is not a thing — the version bump always
accompanies the content edit. See `community-config/FORMAT.md` →
*Version semantics* for the contract.

## Output expectations

- All output in the project's primary language (English by default per
  crewrig convention; check the project's `AGENTS.md` for overrides).
- Markdown that renders cleanly on the project's PR platform.
- No emoji in the body unless the project's convention uses them.

## Friction reporting

When a recognition signal fires (see `config/TOOLS.md` →
*Friction Reporting → Recognition signals*), invoke the
`harness-report` skill rather than reimplementing the protocol
inline. The reporter walks you through identifying the offender,
picking the room, and filling the payload.
