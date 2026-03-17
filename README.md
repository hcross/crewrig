# Gemini Configuration

Centralized configuration framework for [Gemini CLI](https://github.com/google-gemini/gemini-cli).
It provides a shared, layered context system that shapes how the AI assistant
behaves depending on the user's organization, team, role, seniority, and
personal preferences.

## How It Works

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
| [Task](https://taskfile.dev/) | `brew install go-task` | `sh -c "$(curl -ssL https://taskfile.dev/install.sh)"` | `choco install go-task` or `scoop install task` |
| [fzf](https://github.com/junegunn/fzf) | `brew install fzf` | `sudo apt install fzf` | `choco install fzf` or `scoop install fzf` |
| [uv](https://github.com/astral-sh/uv) | `brew install uv` | `curl -LsSf https://astral.sh/uv/install.sh \| sh` | `powershell -c "irm https://astral.sh/uv/install.ps1 \| iex"` |

> **Windows note:** the interactive setup script requires a Bash-compatible
> shell ([Git Bash](https://gitforwindows.org/), [WSL](https://learn.microsoft.com/en-us/windows/wsl/install), or [MSYS2](https://www.msys2.org/)).

## Quick Start

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

### What happens step by step

1. **`gemini "/init-personal-profile"`** walks you through an interview to
   generate `config/PROFILE.md` with your identity, tooling preferences,
   projects, and working philosophy. Type `/exit` when the conversation is
   complete.
2. **`gemini "/init-soul"`** lets you customize the agent's personality by
   refining the `config/SOUL.md` template section by section. Type `/exit`
   when done.
3. **`task setup-gemini-interactive`** links all shared configuration files
   (`settings.json`, `ORGANIZATION.md`, `TOOLS.md`) to `~/.gemini/`, then
   prompts you to select your **team**, **expertise**, and **experience
   level** via an interactive menu with live preview. It also handles your
   `PROFILE.md` (link, copy, or preserve an existing local version).

### Community Config (optional)

The `community-config/` directory is a collaborative sandbox for lightweight,
prompt-based components that do not require executable code. Install them
after the core setup:

```bash
# Install all community components (copy to ~/.gemini/)
task install-workspace

# Or link them for development (symlink mode)
task link-workspace

# Install a single component
task install-component TYPE=skills NAME=ci-workflow-engineering

# Remove a component
task unlink-component TYPE=skills NAME=ci-workflow-engineering
```

Available component types: `commands`, `skills`, `hooks`, `agents`,
`policies`, `mcp-servers`, `themes`.

## Repository Structure

```
config/
├── settings.json          # Gemini CLI settings and MCP servers
├── ORGANIZATION.md        # Company-wide policies (placeholder)
├── TOOLS.md               # Tool and MCP server usage guidelines
├── SOUL.md.template       # Agent identity template
├── PROFILE.md.template    # Personal profile template
├── level/                 # INTERN, JUNIOR, CONFIRMED, EXPERT
├── expertise/             # BACKEND-JAVA, FRONTEND-REACT, FULLSTACK-PYTHON,
│                          # DEVOPS-CLOUD, QA-AUTOMATION, PRODUCT-OWNER
└── teams/                 # ATLAS, NOVA, FORGE, SENTINEL, HORIZON

community-config/
├── skills/                # Reusable agent skills
│   └── ci-workflow-engineering/
├── commands/              # Shared slash commands
├── hooks/                 # Lifecycle hooks
├── agents/                # Sub-agent definitions
├── policies/              # Security policies
├── mcp-servers/           # MCP server configurations
└── themes/                # UI themes

.gemini/commands/
├── init-soul.toml                # /init-soul command
└── init-personal-profile.toml    # /init-personal-profile command

scripts/
├── setup-gemini-interactive.sh   # Interactive setup wizard
├── manage-workspace-component.sh # Install/link individual components
├── install-workspace.sh          # Bulk install all components
└── unlink-component.sh           # Remove a component

Taskfile.yml                      # Task runner configuration
AGENTS.md                         # Agent working rules for this project
CLAUDE.md -> AGENTS.md            # Symlink for Claude Code compatibility
CONTRIBUTING.md                   # Contribution guide
```

## MCP Servers

The `settings.json` configures two MCP servers:

- **GitHub** — Official GitHub MCP server via OAuth for repository, issue,
  and PR management.
- **basic-memory** — Persistent memory across sessions for storing skill
  trees, architectural decisions, and session notes.

## Contributing

All contributions go through feature branches merged into `main` via Pull
Request. See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the full guide and
[`AGENTS.md`](AGENTS.md) for commit conventions (Gitmoji), PR format, and
logbook issue requirements.
