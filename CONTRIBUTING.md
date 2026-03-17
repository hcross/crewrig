# Contributing to Gemini Configuration

This guide explains how to add new configurations, skills, and components
to the repository.

## Philosophy: The Community Sandbox

The `community-config/` directory serves as a **collaborative sandbox**:
- Share lightweight components (commands, skills, hooks) quickly.
- Let colleagues experiment with your improvements before they stabilize.
- Once a component grows in complexity or requires executable code, migrate
  it to a full `extension/` (covered in a future contribution guide).

## Development Workflow

### Link Mode (recommended during development)

Link mode creates symbolic links from your local repository to `~/.gemini/`,
so changes take effect immediately without reinstalling:

```bash
# Link a single skill you are working on
task link-component TYPE=skills NAME=my-new-skill

# Link everything at once
task link-workspace
```

### Install Mode (stable snapshot)

Install mode copies files, producing a snapshot that does not change when
you edit the repository:

```bash
task install-component TYPE=skills NAME=my-new-skill
task install-workspace
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

### Agent Skills (`community-config/skills/`)

Markdown files (`SKILL.md`) providing specialized instructions for specific
tasks. Each skill lives in its own directory.

```markdown
---
name: my-skill
description: "Brief description used for activation"
---

# Skill Title

Detailed workflows and instructions...
```

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

## Standards

1. **Language**: all technical artifacts (code, commits, PRs) in **English**.
2. **Commits**: follow the [Gitmoji](https://gitmoji.dev/) convention.
3. **PRs**: follow the format described in `AGENTS.md` (summary, reading
   guide, test plan, detailed description, linked logbook issue).
4. **Secrets**: never commit credentials. Use `~/.gemini/.env` for local
   tokens.
