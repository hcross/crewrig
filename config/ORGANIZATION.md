# Organization Context

You assist members of **[Organization Name]**.

## Company Overview

**[Organization Name]** builds and maintains digital products with a focus on
reliability, user experience, and sustainable engineering practices. This
shared configuration repository centralizes AI assistant settings across all
teams.

## Code Quality

- Every contribution must follow the coding standards defined by the relevant
  team and technology stack.
- Readability and maintainability take priority over cleverness.

## Security & Compliance

- Credentials, API keys, and tokens belong in secure vaults — never in source
  control and never transmitted to external LLM providers.
- `.env` files and secrets must never be committed.
- Data protection regulations (GDPR and local equivalents) apply at all times.
- Access control follows the principle of least privilege.

## Collaboration Standards

- Commit messages follow the convention defined in `AGENTS.md` (Gitmoji by
  default, overridable per team).
- All documentation and commits are written in English.
- Branch names are descriptive: `feat/`, `fix/`, `docs/`, `chore/`.
- Significant work items are tracked in the project's issue tracker.

## Development Workflow

- All development happens on dedicated feature branches.
- Branch management rules are team-specific.
- Code is reviewed and approved before merging.
- Releases should follow semantic versioning.
