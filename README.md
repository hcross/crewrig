# AI Agent Configuration

Centralized configuration framework for
[Gemini CLI](https://github.com/google-gemini/gemini-cli) and
[Claude Code](https://claude.com/claude-code).
It provides a shared, layered context system that shapes how AI assistants
behave depending on the user's organization, team, role, seniority, and
personal preferences.

## Supported Platforms

| Platform | Config Target | Setup Command |
|----------|---------------|---------------|
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) | `~/.gemini/` | `task setup-gemini-interactive` |
| [Claude Code](https://claude.com/claude-code) | `~/.claude/rules/` | `task setup-claude-interactive` |

Both platforms share the same source configuration files. The setup scripts
create symlinks into platform-specific directories.

## How It Works

### Gemini CLI

Gemini CLI loads context files from `~/.gemini/` in a priority order defined
by numeric prefixes. This repository contains all the source files that get
symlinked into that directory during setup:

| Priority | File | Source | Purpose |
|----------|------|--------|---------|
| 00 | `00_SOUL.md` | `config/SOUL.md` | Agent identity and values |
| 10 | `10_USER_LEVEL.md` | `config/level/<LEVEL>.md` | Seniority-adapted guidance |
| 20 | `20_ORGANIZATION.md` | `config/ORGANIZATION.md` | Company-wide policies |
| 30 | `30_USER_PROFILE.md` | `config/PROFILE.md` | Personal information |
| 40 | `40_USER_EXPERTISE.md` | `config/expertise/<ROLE>.md` | Technical specialization |
| 50 | `50_USER_TEAM.md` | `config/teams/<TEAM>.md` | Team practices and norms |
| 60 | `60_TOOLS.md` | `config/TOOLS.md` | Available tools and MCP servers |
| Last | `AGENTS.md` | Project root | Per-project overrides |

Lower numbers load first. Later files can override or refine earlier context.

### Claude Code

Claude Code loads instructions from `~/.claude/CLAUDE.md` (personal profile)
and automatically loads all rule files from `~/.claude/rules/`. The same
source files are symlinked with a dash-separated naming convention:

| Priority | File | Source | Purpose |
|----------|------|--------|---------|
| 00 | `00-soul.md` | `config/SOUL.md` | Agent identity and values |
| 10 | `10-level.md` | `config/level/<LEVEL>.md` | Seniority-adapted guidance |
| 20 | `20-organization.md` | `config/ORGANIZATION.md` | Company-wide policies |
| 30 | `CLAUDE.md` | `config/PROFILE.md` | Personal information |
| 40 | `40-expertise.md` | `config/expertise/<ROLE>.md` | Technical specialization |
| 50 | `50-team.md` | `config/teams/<TEAM>.md` | Team practices and norms |
| 60 | `60-tools.md` | `config/TOOLS.md` | Available tools and MCP servers |

MCP servers are configured in `~/.claude/mcp.json`. Skills (slash commands)
are installed in `~/.claude/skills/`.

## Prerequisites

### Package Managers

The installation commands below rely on platform-specific package managers.
Install the one matching your OS if you don't have it yet:

| OS | Package Manager | Install |
|----|-----------------|---------|
| macOS | [Homebrew](https://brew.sh/) | `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` |
| Windows | [Chocolatey](https://chocolatey.org/install) | See [install guide](https://chocolatey.org/install) (requires admin PowerShell) |
| Windows | [Scoop](https://scoop.sh/) | `irm get.scoop.sh \| iex` (user-level, no admin required) |
| Linux | apt / dnf / pacman | Bundled with your distribution |

### Required Tools

| Tool | macOS | Linux (Debian/Ubuntu) | Windows |
|------|-------|----------------------|---------|
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) | `npm i -g @google/gemini-cli` | same | same |
| [Claude Code](https://claude.com/claude-code) | `npm i -g @anthropic-ai/claude-code` | same | same |
| [Task](https://taskfile.dev/) | `brew install go-task` | `sh -c "$(curl -ssL https://taskfile.dev/install.sh)"` | `choco install go-task` or `scoop install task` |
| [fzf](https://github.com/junegunn/fzf) | `brew install fzf` | `sudo apt install fzf` | `choco install fzf` or `scoop install fzf` |
| [uv](https://github.com/astral-sh/uv) | `brew install uv` | `curl -LsSf https://astral.sh/uv/install.sh \| sh` | `powershell -c "irm https://astral.sh/uv/install.ps1 \| iex"` |

> **Windows note:** the interactive setup script requires a Bash-compatible
> shell ([Git Bash](https://gitforwindows.org/), [WSL](https://learn.microsoft.com/en-us/windows/wsl/install), or [MSYS2](https://www.msys2.org/)).

## Quick Start

### Gemini CLI

```bash
# Clone the repository
git clone git@github.com:hcross/gemini-configuration.git
cd gemini-configuration

# Generate your personal profile (interactive guided conversation)
gemini "/init-personal-profile"
# Once done, type /exit to leave the Gemini session

# Customize the agent identity
gemini "/init-soul"
# Once done, type /exit to leave the Gemini session

# Run the interactive setup (links everything to ~/.gemini/)
task setup-gemini-interactive
```

### Claude Code

```bash
# Clone the repository
git clone git@github.com:hcross/gemini-configuration.git
cd gemini-configuration

# Generate your personal profile (interactive guided conversation)
claude /init-personal-profile
# The conversation guides you through creating config/PROFILE.md

# Customize the agent identity
claude /init-soul
# Refine config/SOUL.md section by section

# Run the interactive setup (links everything to ~/.claude/)
task setup-claude-interactive
```

### Both platforms at once

```bash
task setup-all
```

### What happens step by step

1. **`/init-personal-profile`** walks you through an interview to
   generate `config/PROFILE.md` with your identity, tooling preferences,
   projects, and working philosophy.
2. **`/init-soul`** lets you customize the agent's personality by
   refining the `config/SOUL.md` template section by section.
3. **`task setup-gemini-interactive`** (or `setup-claude-interactive`)
   links all shared configuration files to the target directory, then
   prompts you to select your **team**, **expertise**, and **experience
   level** via an interactive menu with live preview. It also handles your
   `PROFILE.md` (link, copy, or preserve an existing local version).

### Community Config (optional)

The `community-config/` directory is a collaborative sandbox for lightweight,
prompt-based components that do not require executable code. Install them
after the core setup:

**Gemini CLI:**

```bash
task install-workspace                                         # all components
task install-component TYPE=skills NAME=ci-workflow-engineering # single component
task unlink-component TYPE=skills NAME=ci-workflow-engineering  # remove
```

Available Gemini types: `commands`, `skills`, `hooks`, `agents`,
`policies`, `mcp-servers`, `themes`.

**Claude Code:**

```bash
task install-claude-workspace                                              # all components
task install-claude-component TYPE=claude-skills NAME=ci-workflow-engineering # single
```

Available Claude Code types: `claude-skills`, `policies`, `mcp-servers`.

### Extensions (optional)

Extensions are heavyweight, code-based capabilities (TypeScript MCP servers)
packaged as independent npm modules:

**Gemini CLI:**

```bash
task install-deps          # npm dependencies
task install-extensions    # copy to ~/.gemini/extensions/
task link-extensions       # symlink for development
task install-extension EXT=hello-world
```

**Claude Code:**

```bash
task install-deps                       # npm dependencies
task install-claude-extensions          # merge MCP + skills into ~/.claude/
task install-claude-extension EXT=hello-world
```

See `extensions/hello-world/` for a complete working example and
`extension-skeleton/` as a starting template.

## Repository Structure

```text
extensions/
└── hello-world/           # Example extension (MCP server + command + skill)

extension-skeleton/        # Template for creating new extensions

config/
├── settings.json          # Gemini CLI settings and MCP servers
├── claude/                # Claude Code configuration templates
│   ├── CLAUDE.md.template # User profile template for ~/.claude/CLAUDE.md
│   ├── mcp.json.template  # MCP server configuration for ~/.claude/mcp.json
│   └── settings.json.template # Settings template for ~/.claude/settings.json
├── ORGANIZATION.md        # Company-wide policies (placeholder)
├── TOOLS.md               # Tool and MCP server usage guidelines
├── SOUL.md.template       # Agent identity template
├── PROFILE.md.template    # Personal profile template
├── level/                 # INTERN, JUNIOR, CONFIRMED, EXPERT
├── expertise/             # BACKEND-JAVA, FRONTEND-REACT, FULLSTACK-PYTHON,
│                          # DEVOPS-CLOUD, QA-AUTOMATION, PRODUCT-OWNER
└── teams/                 # ATLAS, NOVA, FORGE, SENTINEL, HORIZON

community-config/
├── skills/                # Reusable Gemini CLI skills
│   └── ci-workflow-engineering/
├── claude-skills/         # Reusable Claude Code skills
│   └── ci-workflow-engineering/
├── commands/              # Shared slash commands (Gemini CLI)
├── hooks/                 # Lifecycle hooks
├── agents/                # Sub-agent definitions
├── policies/              # Security policies
├── mcp-servers/           # MCP server configurations
└── themes/                # UI themes (Gemini CLI)

.gemini/commands/                         # Gemini CLI commands
├── init-soul.toml                        # /init-soul command
└── init-personal-profile.toml            # /init-personal-profile command

.claude/                                  # Claude Code project config
├── settings.json                         # Project permissions
├── mcp.json                              # Project MCP servers
└── skills/                               # Claude Code skills
    ├── init-soul/SKILL.md                # /init-soul skill
    └── init-personal-profile/SKILL.md    # /init-personal-profile skill

scripts/
├── setup-gemini-interactive.sh           # Gemini CLI interactive setup
├── setup-claude-interactive.sh           # Claude Code interactive setup
├── manage-workspace-component.sh         # Install/link Gemini components
├── manage-claude-component.sh            # Install/link Claude components
├── install-workspace.sh                  # Bulk install Gemini components
├── install-extension.sh                  # Install Gemini extensions
├── install-claude-extension.sh           # Install Claude Code extensions
├── link-extensions.sh                    # Link all Gemini extensions
├── unlink-extensions.sh                  # Remove all Gemini extensions
├── unlink-component.sh                   # Remove a Gemini component
├── package-extension.sh                  # Package a single extension
├── package-extensions.sh                 # Package all extensions
└── create-extension.sh                   # Interactive extension scaffolding

Taskfile.yml                              # Task runner configuration
AGENTS.md                                 # Agent working rules for this project
CLAUDE.md                                 # Claude Code entry point (@AGENTS.md)
CONTRIBUTING.md                           # Contribution guide
DEVELOPMENT.md                            # Extension development guide
```

## Talks

| Date | Event | Title | Links |
|------|-------|-------|-------|
| 2026-03-17 | GDG Cloud Paris | L'IA ne fera rien sans nous | [README](communication/talks/gdg-cloud-paris-2026-03-17/README.md) · [Slides](https://hcross.github.io/gemini-configuration/talks/gdg-cloud-paris-2026-03-17/) |

## MCP Servers

The `settings.json` configures two MCP servers:

- **GitHub** — Official GitHub MCP server via OAuth for repository, issue,
  and PR management.
- **basic-memory** — Persistent memory across sessions for storing skill
  trees, architectural decisions, and session notes.

## Contributing

All contributions go through feature branches merged into `main` via Pull
Request. See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the full guide,
[`DEVELOPMENT.md`](DEVELOPMENT.md) for the extension development lifecycle,
and [`AGENTS.md`](AGENTS.md) for commit conventions (Gitmoji), PR format,
and logbook issue requirements.
