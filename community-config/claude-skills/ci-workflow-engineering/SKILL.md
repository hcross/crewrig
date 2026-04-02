---
name: ci-workflow-engineering
description: "Structured approach for building, debugging, and hardening CI/CD
  pipelines. Activate when the agent needs to: create new workflow definitions,
  diagnose failing jobs, validate pipeline changes on a branch before merge,
  or integrate platform-specific resources (secrets, registries, certificates)."
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
---

# CI Workflow Engineering

A disciplined methodology for developing reliable CI/CD pipelines in any
project structure.

## Lifecycle

### 1. Assess and Plan

Before touching any pipeline file, map the current situation:

- Identify the failing job or the desired new workflow.
- List hypotheses as a numbered table (H1, H2, ...) with status
  (untested / confirmed / rejected).
- Persist the plan in the memory MCP server (or a local note) under a
  dedicated path (e.g., `ci-plans/<ticket-or-topic>`).

### 2. Branch-Level Proof

Never assume a pipeline change works until a real runner confirms it green.

- Temporarily adjust workflow trigger rules so the target job executes on
  the current feature branch.
- If simulating tag-triggered jobs, use a throwaway tag suffix
  (e.g., `-dry-run-1`) and adapt regex filters accordingly.
- Always use the project's trusted certificate chain for HTTPS calls.
  Never bypass TLS verification.

### 3. Iterate: Change, Run, Read

- Apply a focused, minimal change to the pipeline definition or its
  supporting scripts.
- Push and let the runner execute.
- Fetch the full job log (API or UI) to pinpoint the exact failure line.
  Do not guess from partial output.
- Update the hypothesis table in memory: confirm, reject, or refine.
- Repeat until the job passes reliably.

**Guideline:** prefer a single permissive workflow trigger (run on all
events by default) and manage exclusions at the individual job level.
Exhaustive branch lists are fragile and hard to maintain.

### 4. Harden and Clean Up

Once the pipeline is green and stable:

- Remove all temporary trigger overrides, debug logs, and dry-run tags.
- Replace any hardcoded values with CI variables
  (e.g., `$CI_PROJECT_URL`, `$GITHUB_REPOSITORY`).
- Delete simulation tags from the remote.
- Confirm the final pipeline runs green on a clean push without
  special overrides.

## Documentation Expectations

### Logbook Entries

Every significant experiment must be logged as a comment in the linked
issue:

- What was tried and what the hypothesis was.
- Outcome (green / red) with a link to the job or run.
- Any traps or counter-intuitive behaviors discovered.

### Pull Request Description

- **Summary:** 1-2 sentences.
- **Related issue:** reference.
- **Experiments:** what was tried and why it failed or succeeded.
- **Final approach:** detailed explanation of the chosen solution.
- **Evidence:** link to the passing pipeline run.
