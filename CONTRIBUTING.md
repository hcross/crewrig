# Contributing to AI Agent Configuration

This guide explains how to add new configurations, skills, and components
to the repository. The framework supports both **Gemini CLI** and
**Claude Code** as target platforms.

## Philosophy: The Community Sandbox

The `community-config/` directory serves as a **collaborative sandbox**:

- Share lightweight components (commands, skills, hooks) quickly.
- Let colleagues experiment with your improvements before they stabilize.
- Once a component grows in complexity or requires executable code, migrate
  it to a full `extension/` (covered in a future contribution guide).

## Development Workflow

### Link Mode (recommended during development)

Link mode creates symbolic links from your local repository to the target
directory, so changes take effect immediately without reinstalling:

**Gemini CLI** (`~/.gemini/`):

```bash
task link-component TYPE=skills NAME=my-new-skill
task link-workspace
```

**Claude Code** (`~/.claude/`):

```bash
task link-claude-component TYPE=claude-skills NAME=my-new-skill
task link-claude-workspace
```

### Install Mode (stable snapshot)

Install mode copies files, producing a snapshot that does not change when
you edit the repository:

```bash
# Gemini CLI
task install-component TYPE=skills NAME=my-new-skill

# Claude Code
task install-claude-component TYPE=claude-skills NAME=my-new-skill
```

### Removing a component

```bash
task unlink-component TYPE=skills NAME=my-new-skill
```

## Component Types

### Custom Commands (`community-config/commands/`)

Simple `.toml` files defining slash commands for Gemini CLI.

```toml
description = "Short description of what the command does"
prompt = """
Detailed instructions for the model...
"""
```

### Agent Skills

Skills are `SKILL.md` files providing specialized instructions for specific
tasks. Each skill lives in its own directory.

**Gemini CLI** (`community-config/skills/`):

```markdown
---
name: my-skill
description: "Brief description used for activation"
---

# Skill Title

Detailed workflows and instructions...
```

**Claude Code** (`community-config/claude-skills/`):

Same YAML frontmatter format. You can add Claude Code-specific fields like
`allowed-tools`, `user-invocable`, `model`, or `effort`:

```markdown
---
name: my-skill
description: "Brief description used for activation"
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Bash
---

# Skill Title

Detailed workflows and instructions...
```

When creating a new skill, provide versions for both platforms if the
prompt content differs (e.g., Gemini uses `ask_user` while Claude Code
uses conversational patterns).

### Lifecycle Hooks (`community-config/hooks/`)

Scripts that intercept Gemini CLI events: `BeforeAgent`, `AfterAgent`,
`BeforeTool`, `AfterTool`.

### Sub-Agents (`community-config/agents/`)

Prompt-based specialized agents for delegated tasks.

### Security Policies (`community-config/policies/`)

Rules that govern tool execution permissions.

### MCP Servers (`community-config/mcp-servers/`)

JSON configuration fragments merged into `settings.json` on install.
Requires `jq` for the merge operation.

### Themes (`community-config/themes/`)

JSON theme definitions merged into `settings.json` on install.

## Creating Extensions

When a capability requires executable code (TypeScript MCP server, custom
build steps), create a full extension instead of a community-config component.

Use the `extension-skeleton/` directory as a starting point:

1. Copy `extension-skeleton/base/` into `extensions/<your-name>/`.
2. Add optional component directories you need (command, skill, agent, hook,
   mcp-server, theme) from the skeleton.
3. Replace every occurrence of `SKELETON_NAME` with your extension name.
4. Implement your MCP server in `src/index.ts`.
5. Test locally with `task link-extensions` and start a Gemini session.

Each extension is an independent npm package with its own versioning. See
`extensions/hello-world/` for a complete working reference.

> **Warning:** never install or link the `extension-skeleton/` directory
> itself. It is a template container, not a functional extension.

## Standards

1. **Language**: all technical artifacts (code, commits, PRs) in **English**.
2. **Commits**: follow the [Gitmoji](https://gitmoji.dev/) convention.
3. **PRs**: follow the format described in `AGENTS.md` (summary, reading
   guide, test plan, detailed description, linked logbook issue).
4. **Secrets**: never commit credentials. Use `~/.gemini/.env` or shell
   environment variables for local tokens.
5. **Dual-platform**: when adding skills or commands, provide versions for
   both Gemini CLI (`.toml` / `community-config/skills/`) and Claude Code
   (`SKILL.md` / `community-config/claude-skills/`).
