# Unified Community Component Format

This document specifies the single-source format for community components
in `community-config/`. Components written in this format are compiled by
`scripts/build-components.sh` into tool-specific outputs for Gemini CLI
and Claude Code.

## Principles

1. **One source file, multiple targets** — the prompt/logic content is
   written once and shared across all tools.
2. **Universal metadata** is required — `name`, `description`, `type`.
3. **Tool-specific overrides** are optional — only needed when a tool
   requires metadata beyond the universal fields.
4. **The body is never duplicated** — install scripts extract the body
   and wrap it in the target tool's format.

## Supported Component Types

| Type | Source location | Gemini CLI output | Claude Code output |
|------|----------------|-------------------|--------------------|
| `skill` | `skills/<name>/SKILL.md` | `.gemini/skills/<name>/SKILL.md` | `.claude/skills/<name>/SKILL.md` |
| `command` | `commands/<name>.md` | `.gemini/commands/<name>.toml` | `.claude/skills/<name>/SKILL.md` |
| `agent` | `agents/<name>/AGENT.md` | `.gemini/agents/<name>.md` | `.claude/agents/<name>/AGENT.md` |

Hooks, policies, and MCP servers use JSON formats and are handled
separately by the build script (merged into tool-specific config files).

## Source File Format

Every source file uses Markdown with YAML frontmatter:

```markdown
---
# === Universal metadata (required) ===
name: my-component
description: "Brief description used for discovery and activation"
type: skill           # skill | command | agent

# === Gemini CLI overrides (optional) ===
# Only include if Gemini needs different metadata than the universal fields.
# Omit entirely to use universal defaults.
gemini:
  # No extra fields needed for most skills.
  # For commands: no overrides needed (description + body used as-is).

# === Claude Code overrides (optional) ===
# Only include if Claude Code needs extra metadata.
# Omit entirely to use universal defaults.
claude:
  allowed-tools:
    - Read
    - Write
    - Edit
    - Bash
    - Grep
    - Glob
  user-invocable: true
  # disable-model-invocation: false  # default
---

# Component Title

Prompt content here — shared across ALL tools, written once.

## Sections

Detailed instructions, workflows, constraints...
```

## Field Reference

### Universal Fields (required)

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Component identifier (kebab-case) |
| `description` | string | Brief description for discovery. Used by both tools. |
| `type` | string | `skill`, `command`, or `agent` |

### Gemini CLI Overrides (optional)

The `gemini:` section is rarely needed. The build script uses universal
fields by default:

- For `skill`: generates a SKILL.md with `name` and `description` in
  the frontmatter, body as-is.
- For `command`: generates a `.toml` file with `description` and the
  body wrapped in `prompt = """..."""`.
- For `agent`: generates a flat `.gemini/agents/<name>.md` file with YAML
  frontmatter (`name`, `description`) — required by Gemini CLI's
  sub-agent discovery — followed by the body as the system prompt.

### Claude Code Overrides (optional)

The `claude:` section adds Claude Code-specific frontmatter fields:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `allowed-tools` | string[] | *(none)* | Tools the skill can use |
| `user-invocable` | boolean | `true` | Can the user invoke with `/name`? |
| `disable-model-invocation` | boolean | `false` | Prevent auto-invocation? |
| `context` | string | *(none)* | Run context (`fork` for isolated subagent) |
| `agent` | string | *(none)* | Agent type (`Explore`, `Plan`, etc.) |
| `model` | string | *(none)* | Model override |
| `effort` | string | *(none)* | Effort level override |

## Build Outputs

### Skill: `community-config/skills/<name>/SKILL.md`

Gemini CLI → `.gemini/skills/<name>/SKILL.md`

```yaml
---
name: <name>
description: <description>
---
<body>
```

Claude Code → `.claude/skills/<name>/SKILL.md`

```yaml
---
name: <name>
description: <description>
allowed-tools:        # from claude.allowed-tools (if present)
  - Read
  - Bash
user-invocable: true  # from claude.user-invocable (if present)
---
<body>
```

### Skill resource subfolders (`scripts/`, `references/`, `assets/`)

Per the [Agent Skills spec](https://agentskills.io/specification), a
skill may ship three optional resource subfolders alongside its
`SKILL.md`:

| Subfolder | Purpose |
|---|---|
| `scripts/` | Executable code the skill invokes (Python, Bash, JavaScript). |
| `references/` | Additional documentation loaded on demand. |
| `assets/` | Templates, fixtures, static resources. |

When present in a source under `community-config/skills/<name>/`,
these subfolders are **propagated verbatim** to both build outputs
(`.gemini/skills/<name>/<subfolder>/...` and
`.claude/skills/<name>/<subfolder>/...`). Executable bits are
preserved. Skill bodies should reference resources by path relative
to the skill root (e.g. `scripts/curate.sh`), so the same invocation
works regardless of whether the skill lives at project level
(`.gemini/.claude/`) or user level (`~/.gemini/`, `~/.claude/`).

### Command: `community-config/commands/<name>.md`

Gemini CLI → `.gemini/commands/<name>.toml`

```toml
description = "<description>"

prompt = """
<body>
"""
```

Claude Code → `.claude/skills/<name>/SKILL.md`

```yaml
---
name: <name>
description: <description>
user-invocable: true
---
<body>
```

### Agent: `community-config/agents/<name>/AGENT.md`

Gemini CLI → `.gemini/agents/<name>.md`

```yaml
---
name: <name>
description: <description>
provenance:        # propagated when present in source
  canonical: ...
  feedback: ...
  version: ...
---
<body — becomes the agent's system prompt>
```

Claude Code → `.claude/agents/<name>/AGENT.md`

```yaml
---
name: <name>
description: <description>
---
<body>
```

## Provenance & Forks

Components carry a `provenance:` block in their frontmatter that survives
forks and lets feedback flow back to the right repo. The block is
optional but recommended for any component intended to be re-shared.

```yaml
---
name: my-component
description: "..."
type: skill
provenance:
  canonical: "${CANONICAL_REPO}"   # origin (audit + license trace)
  feedback:  "${FEEDBACK_REPO}"    # MR target (defaults to canonical)
  version:   "1.0.0"               # version at build/import
---
```

### Placeholder resolution

`${SHELL_LIKE}` placeholders are resolved at **build time** by
`scripts/build-components.sh` from `crewrig.config.toml` at the repo
root. Each line in the config file maps an uppercased key to a value:

```toml
canonical_repo = "https://github.com/hcross/crewrig"
feedback_repo  = "https://github.com/hcross/crewrig"
```

The build substitutes every `${KEY}` placeholder it encounters in the
generated outputs (`.gemini/`, `.claude/`) — frontmatter **and** body —
not only inside the `provenance:` block. This is intentional: components
may reference `${CANONICAL_REPO}` or other config keys in their prompt
body too. Source files keep the placeholders untouched.

### Forking workflow

When you fork crewrig (or a fork of it):

1. Edit `crewrig.config.toml` to point at your URLs. Typically:
   - Keep `canonical_repo` pointing at the upstream you forked from
     (audit trail).
   - Set `feedback_repo` to your own repo so harness feedback lands
     internally.
2. Run `task build-components` to regenerate the outputs with your
   values.
3. Commit both `crewrig.config.toml` and the regenerated outputs.

The `version:` field in `provenance:` is a literal per-component
string, not a placeholder. It tracks the component's own evolution
independently from the host repo.

### Components without a `provenance:` block

Components shipped before the provenance contract existed (or
intentionally unscoped) build unchanged — the resolver only acts on
content that actually contains placeholders. There is no automatic
backfill.

## Parser Requirements

The build script (`scripts/build-components.sh`) requires:

- **`yq`** (preferred) for YAML frontmatter parsing, or a lightweight
  Python helper as fallback.
- **`jq`** for JSON merging (hooks, policies, MCP servers).
- **Bash 4+** for associative arrays and advanced string handling.

## Validation Rules

1. Every source file MUST have `name`, `description`, and `type` in
   the frontmatter.
2. The `type` field MUST be one of: `skill`, `command`, `agent`.
3. The body (content after the closing `---`) MUST NOT be empty.
4. Tool-specific sections (`gemini:`, `claude:`) are optional.
5. Unknown fields in tool-specific sections are silently ignored.
