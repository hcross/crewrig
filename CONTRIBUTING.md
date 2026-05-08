# Contributing to AI Agent Configuration

This guide explains how to add new configurations, skills, and components
to the repository. The framework supports both **Gemini CLI** and
**Claude Code** as target platforms.

## Philosophy: The Community Sandbox

The `community-config/` directory serves as a **collaborative sandbox**:

- Share lightweight components (commands, skills, hooks) quickly.
- Write each component **once** in the unified source format — the build
  system generates outputs for both Gemini CLI and Claude Code.
- Once a component grows in complexity or requires executable code, migrate
  it to a full `extension/` with an `extension.json` manifest.

## Single-Source vs Project-Specific

| Directory | Scope | Duplication? |
|-----------|-------|:------------:|
| `community-config/` | Reusable, shared across tools | **No** — single source, build generates targets |
| `.gemini/commands/` | Gemini CLI project commands | **Yes** — native to Gemini |
| `.claude/skills/` | Claude Code project skills | **Yes** — native to Claude Code |

Community components use the unified format documented in
[`community-config/FORMAT.md`](community-config/FORMAT.md).

## Development Workflow

### Copy Mode (default — recommended)

Copy mode creates isolated snapshots that are immune to branch changes:

**Gemini CLI:**

```bash
task install-component TYPE=skills NAME=my-new-skill
task install-workspace
```

**Claude Code:**

```bash
task install-claude-component TYPE=claude-skills NAME=my-new-skill
task install-claude-workspace
```

### Link Mode (development only — security warning)

Link mode creates symbolic links for immediate feedback during
development. **Use only if you trust all branches in this repository.**

**Gemini CLI:**

```bash
task link-component TYPE=skills NAME=my-new-skill
task link-workspace
```

**Claude Code:**

```bash
task link-claude-component TYPE=claude-skills NAME=my-new-skill
task link-claude-workspace
```

### Removing a component

```bash
task unlink-component TYPE=skills NAME=my-new-skill
```

## Community Component Format

Community components use a **unified source format** (Markdown with YAML
frontmatter). See [`community-config/FORMAT.md`](community-config/FORMAT.md)
for the complete specification.

```markdown
---
name: my-skill
description: "Brief description used for activation"
type: skill
claude:
  allowed-tools:
    - Read
    - Bash
  user-invocable: true
---

# Skill Title

Prompt content — shared across ALL tools, written once.
```

Build outputs for each tool:

```bash
task build-components           # Both tools
task check-components           # Drift detection (CI)
```

### Component Types

| Type | Source | Gemini Output | Claude Code Output |
|------|--------|---------------|--------------------|
| Skill | `skills/<name>/SKILL.md` | `.gemini/skills/<name>/SKILL.md` | `.claude/skills/<name>/SKILL.md` |
| Command | `commands/<name>.md` | `.gemini/commands/<name>.toml` | `.claude/skills/<name>/SKILL.md` |
| Agent | `agents/<name>/AGENT.md` | `agents/<name>/PROMPT.md` | `.claude/agents/<name>/AGENT.md` |
| Hook | `hooks/` | hooks.json | settings.json merge |
| Policy | `policies/` | YAML rule file | settings.json permissions |
| MCP server | `mcp-servers/` | settings.json merge | `claude mcp add --scope user` |
| Theme | `themes/` | settings.json merge | *(not supported)* |

## Creating Extensions

When a capability requires executable code (TypeScript MCP server, custom
build steps), create a full extension with an `extension.json` manifest.

A single `extension.json` generates both a Gemini extension and a Claude
Code plugin. See
[`extension-skeleton/EXTENSION-FORMAT.md`](extension-skeleton/EXTENSION-FORMAT.md)
for the complete manifest specification.

Quick steps:

1. Copy `extension-skeleton/base/` into `extensions/<your-name>/`.
2. Add optional component directories from the skeleton.
3. Replace every `SKELETON_NAME` with your extension name.
4. Implement your MCP server in `src/index.ts`.
5. Test locally:
   - **Gemini**: `task link-extensions` then start a Gemini session.
   - **Claude Code**: `task build-claude-plugin EXT=<name>` then
     `claude --plugin-dir extensions/<name>/dist-claude-plugin/<name>`.

Each extension is an independent npm package with its own versioning. See
`extensions/hello-world/` for a complete working reference.

> **Warning:** never install the `extension-skeleton/` directory itself.
> It is a template container, not a functional extension.

## Standards

1. **Language**: all technical artifacts (code, commits, PRs) in **English**.
2. **Commits**: follow the [Gitmoji](https://gitmoji.dev/) convention.
3. **PRs**: follow the format described in `AGENTS.md` (summary, reading
   guide, test plan, detailed description, linked logbook issue).
4. **Secrets**: never commit credentials. Use `~/.gemini/.env` or shell
   environment variables for local tokens.
5. **Community components**: use the unified source format — one file,
   build generates both tool outputs. See `community-config/FORMAT.md`.
6. **Extensions**: use `extension.json` manifest for new extensions.
   See `extension-skeleton/EXTENSION-FORMAT.md`.
7. **Shell + Python glue**: follow the rules in
   [`docs/scripting-conventions.md`](docs/scripting-conventions.md). They
   exist because each one has already shipped a real bug.
