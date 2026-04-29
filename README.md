# AI Agent Configuration

Centralized configuration framework for
[Gemini CLI](https://github.com/google-gemini/gemini-cli) and
[Claude Code](https://claude.ai/code).
It provides a shared, layered context system that shapes how AI assistants
behave depending on the user's organization, team, role, seniority, and
personal preferences.

## Supported Platforms

| Platform | Config Target | Setup Command |
|----------|---------------|---------------|
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) | `~/.gemini/` | `task setup-gemini-interactive` |
| [Claude Code](https://claude.ai/code) | `~/.claude/rules/` | `task setup-claude-interactive` |

Both platforms share the same source configuration files in `config/`.
Setup scripts deploy them into platform-specific directories.

## How It Works

### Layered Context

Configuration files are organized by priority. Each file addresses a
specific concern (identity, policies, expertise, etc.) and they combine
to form the agent's full context:

| Priority | Source | Purpose |
|----------|--------|---------|
| 00 | `config/SOUL.md` | Agent identity and values |
| 10 | `config/level/<LEVEL>.md` | Seniority-adapted guidance |
| 20 | `config/ORGANIZATION.md` | Company-wide policies |
| 30 | `config/PROFILE.md` | Personal information |
| 40 | `config/expertise/<ROLE>.md` | Technical specialization |
| 50 | `config/teams/<TEAM>.md` | Team practices and norms |
| 60 | `config/TOOLS.md` | Memory architecture and MCP servers |

**Gemini CLI** loads these via numeric-prefix files in `~/.gemini/` with
enforced priority order. **Claude Code** loads them from `~/.claude/rules/`
as additive context (all files combine, no override).

### Security: Copy by Default

Context files are **copied** (not symlinked) to the target directory by
default. This prevents context poisoning from malicious branches. Symlink
mode is available for development only (with a security disclaimer).

### Memory Architecture

The framework implements a three-tier memory model:

| Tier | System | Role | Access |
|------|--------|------|--------|
| 1 | Sequential Thinking | Working memory (ephemeral) | Session only |
| 2 | MemPalace | Agent memory (persistent) | Read/write, cross-tool |
| 3 | Obsidian | User knowledge (Second Brain) | Read free, write user-controlled |

See `config/TOOLS.md` for the full memory protocol.

## Prerequisites

### Package Managers

| OS | Package Manager | Install |
|----|-----------------|---------|
| macOS | [Homebrew](https://brew.sh/) | `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` |
| Windows | [Chocolatey](https://chocolatey.org/install) | See [install guide](https://chocolatey.org/install) |
| Windows | [Scoop](https://scoop.sh/) | `irm get.scoop.sh \| iex` |
| Linux | apt / dnf / pacman | Bundled with your distribution |

### Required Tools

| Tool | macOS | Linux (Debian/Ubuntu) | Windows |
|------|-------|----------------------|---------|
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) | `npm i -g @google/gemini-cli` | same | same |
| [Claude Code](https://claude.ai/code) | `npm i -g @anthropic-ai/claude-code` | same | same |
| [Task](https://taskfile.dev/) | `brew install go-task` | `sh -c "$(curl -ssL https://taskfile.dev/install.sh)"` | `choco install go-task` or `scoop install task` |
| [fzf](https://github.com/junegunn/fzf) | `brew install fzf` | `sudo apt install fzf` | `choco install fzf` or `scoop install fzf` |
| [uv](https://github.com/astral-sh/uv) | `brew install uv` | `curl -LsSf https://astral.sh/uv/install.sh \| sh` | `powershell -c "irm https://astral.sh/uv/install.ps1 \| iex"` |
| [yq](https://github.com/mikefarah/yq) | `brew install yq` | `sudo snap install yq` | `choco install yq` |

> **Windows note:** setup scripts require a Bash-compatible shell
> ([Git Bash](https://gitforwindows.org/), [WSL](https://learn.microsoft.com/en-us/windows/wsl/install), or [MSYS2](https://www.msys2.org/)).

## Quick Start

### Gemini CLI

```bash
git clone git@github.com:hcross/gemini-configuration.git
cd gemini-configuration

# Generate your personal profile
gemini "/init-personal-profile"

# Customize the agent identity
gemini "/init-soul"

# Run the interactive setup (deploys to ~/.gemini/)
task setup-gemini-interactive
```

### Claude Code

```bash
git clone git@github.com:hcross/gemini-configuration.git
cd gemini-configuration

# Generate your personal profile
claude /init-personal-profile

# Customize the agent identity
claude /init-soul

# Run the interactive setup (deploys to ~/.claude/rules/)
task setup-claude-interactive
```

### What happens step by step

1. **`/init-personal-profile`** walks you through an interview to
   generate `config/PROFILE.md` with your identity, tooling preferences,
   projects, and working philosophy.
2. **`/init-soul`** lets you customize the agent's personality by
   refining the `config/SOUL.md` template section by section.
3. **`task setup-*-interactive`** copies shared configuration files to
   the target directory, then prompts you to select your **team**,
   **expertise**, and **experience level** via an interactive menu with
   live preview.

### Community Config (optional)

The `community-config/` directory is a collaborative sandbox for
lightweight, prompt-based components. Single-source files generate
outputs for both tools:

**Gemini CLI:**

```bash
task install-workspace
task install-component TYPE=skills NAME=ci-workflow-engineering
```

**Claude Code:**

```bash
task install-claude-workspace
task install-claude-component TYPE=claude-skills NAME=ci-workflow-engineering
```

**Build from source:**

```bash
task build-components           # Both tools
task build-components-gemini    # Gemini only
task build-components-claude    # Claude Code only
task check-components           # Drift detection (CI)
```

### Extensions (optional)

Extensions are code-based capabilities (TypeScript MCP servers) packaged
as independent npm modules. From a single `extension.json` manifest,
install scripts generate both Gemini extensions and Claude Code plugins:

**Gemini CLI:**

```bash
task install-deps
task install-extensions
task install-extension EXT=hello-world
```

**Claude Code:**

```bash
task install-deps
task build-claude-plugin EXT=hello-world
task install-claude-plugin EXT=hello-world
```

See `extensions/hello-world/` for a complete example,
`extension-skeleton/EXTENSION-FORMAT.md` for the manifest specification,
and `extension-skeleton/` as a starting template.

## Repository Structure

```text
extensions/
└── hello-world/           # Example extension (MCP server + command + skill)

extension-skeleton/        # Template for creating new extensions
├── EXTENSION-FORMAT.md    # extension.json specification

config/
├── gemini/
│   └── settings.json      # Gemini CLI settings and MCP servers
├── claude/
│   └── settings.json.template
├── ORGANIZATION.md        # Company-wide policies
├── TOOLS.md               # Memory architecture and MCP server guidelines
├── SOUL.md.template       # Agent identity template
├── PROFILE.md.template    # Personal profile template
├── level/                 # INTERN, JUNIOR, CONFIRMED, EXPERT
├── expertise/             # BACKEND-JAVA, FRONTEND-REACT, FULLSTACK-PYTHON,
│                          # DEVOPS-CLOUD, QA-AUTOMATION, PRODUCT-OWNER
└── teams/                 # ATLAS, NOVA, FORGE, SENTINEL, HORIZON

community-config/
├── FORMAT.md              # Unified source format specification
├── skills/                # Reusable agent skills (single-source)
│   └── ci-workflow-engineering/
├── commands/              # Shared slash commands
├── hooks/                 # Lifecycle hooks
├── agents/                # Sub-agent definitions
├── policies/              # Security policies
├── mcp-servers/           # MCP server configurations
└── themes/                # UI themes

.gemini/commands/                     # Gemini CLI project commands
├── init-soul.toml
└── init-personal-profile.toml

.claude/                              # Claude Code project config
├── settings.json                     # Project permissions
└── skills/                           # Claude Code project skills
    ├── init-soul/SKILL.md
    └── init-personal-profile/SKILL.md

hooks/                                # Shared hook scripts
├── mempalace-transcript.sh           # Session recording (opt-in)
├── gemini-transcript-hooks.json      # Gemini hook registration
└── claude-transcript-hooks.json      # Claude Code hook registration

scripts/
├── setup-gemini-interactive.sh       # Gemini CLI setup
├── setup-claude-interactive.sh       # Claude Code setup (copy default)
├── build-components.sh               # Community component builder
├── build-claude-plugin.sh            # Claude Code plugin generator
├── install-claude-plugin.sh          # Claude Code plugin installer
├── manage-claude-component.sh        # Claude Code component manager
├── manage-workspace-component.sh     # Gemini component manager
├── install-workspace.sh              # Bulk Gemini install
├── install-extension.sh              # Gemini extension installer
├── create-extension.sh               # Extension scaffolding
└── ...

Taskfile.yml                          # Task runner configuration
AGENTS.md                             # Agent working rules
CLAUDE.md                             # Claude Code entry point (@AGENTS.md)
CONTRIBUTING.md                       # Contribution guide
DEVELOPMENT.md                        # Extension development guide
```

## Talks

| Date | Event | Title | Links |
|------|-------|-------|-------|
| 2026-03-17 | GDG Cloud Paris | L'IA ne fera rien sans nous | [README](communication/talks/gdg-cloud-paris-2026-03-17/README.md) · [Slides](https://hcross.github.io/gemini-configuration/talks/gdg-cloud-paris-2026-03-17/) |

## MCP Servers

### Gemini CLI (`config/gemini/settings.json`)

- **GitHub** — GitHub MCP server via OAuth.
- **MemPalace** — Unified agent memory (replaces KG Memory + Deep Memory).
- **Sequential Thinking** — Working memory for structured reasoning.

### Claude Code (`~/.claude.json`, managed by `claude mcp add`)

Claude Code reads MCP servers from `~/.claude.json`, not from any `mcp.json`
file. The `setup-claude-interactive.sh` script registers them via
`claude mcp add --scope user`. To inspect or manage them later:

```bash
claude mcp list                      # Show registered servers
claude mcp add --scope user <name> -- <command> [args...]
claude mcp remove <name>
```

- **Sequential Thinking** — Working memory; registered as user-scope.
- **MemPalace** — Persistent agent memory; registered as user-scope (the
  setup script auto-detects the right Python interpreter).
- **GitHub** — Available via Claude Code's built-in connectors.

## Contributing

All contributions go through feature branches merged into `main` via Pull
Request. See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the full guide,
[`DEVELOPMENT.md`](DEVELOPMENT.md) for the extension development lifecycle,
and [`AGENTS.md`](AGENTS.md) for commit conventions (Gitmoji), PR format,
and logbook issue requirements.
