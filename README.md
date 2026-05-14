> **This repository is the genesis archive.** Active development has moved to [github.com/crewrig/crewrig](https://github.com/crewrig/crewrig).

# CrewRig

CrewRig is a centralized configuration framework for
[Gemini CLI](https://github.com/google-gemini/gemini-cli) and
[Claude Code](https://claude.ai/code). It serves three complementary
purposes:

- **Personal context layer** — layered configuration files shape how AI
  assistants behave for a specific user's role, team, and seniority.
- **Shared innovation zone** — `community-config/` is a collaborative
  sandbox where a team builds and shares skills, agents, and commands
  that any member can install from a single source.
- **Harness engineering** — a built-in feedback loop lets agents tag
  frictions encountered during real work; the harness curator clusters
  those frictions into actionable GitHub issues, closing the loop
  between AI behavior and continuous improvement.

CrewRig develops itself using its own mechanics. The internal agent crew
— architect, developer, tester, pr-logbook, and pr-reviewer — runs on
the same skills and agents that ship with the framework. The development
workflow is the product in action.

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

### Community Config Zone

`community-config/` is a single-source sandbox where skills, agents, and
commands are written **once** and compiled into outputs for both CLIs.
Contributors edit a single Markdown file with YAML frontmatter; the
build step produces Gemini and Claude Code targets.

| Type | Description |
|---|---|
| Skill | Reusable agent behaviour activated via `/skill-name` |
| Command | Slash command with a prompt body |
| Agent | Sub-agent with a dedicated persona |
| Hook | Lifecycle hook (BeforeTool/AfterTool/etc.) |
| Policy | Security or behavioural constraint |
| MCP Server | External tool integration |
| Theme | UI theme fragment |

Install a component on a project:

```bash
# Gemini CLI
task install-component TYPE=skills NAME=ci-workflow-engineering

# Claude Code
task install-claude-component TYPE=claude-skills NAME=ci-workflow-engineering
```

See [`community-config/FORMAT.md`](community-config/FORMAT.md) for the
full unified-source specification.

### Harness Engineering Loop

The harness turns real-world frictions into shipped improvements through
a four-stage loop:

1. **Tag** — during real work, agents invoke the `harness-report` skill
   the moment a friction signal fires (user pushback, tool surprise,
   process gap). Each tag lands in the MemPalace `harness-friction`
   wing.
2. **Cluster** — `task harness-curate -- --apply` clusters the tagged
   frictions by subcategory and opens one descriptive GitHub issue per
   cluster.
3. **Fix** — issues are addressed via the normal branch/PR workflow;
   the internal agent crew handles the implementation cycle.
4. **Re-install** — after a fix ships, run `task build-components` and
   reinstall. The `metadata.provenance.version` bump in every modified
   `SKILL.md` signals that a new version is available.

For automated periodic sweeps,
`community-config/skills/harness-curator/scripts/schedule-curator.sh`
installs a macOS launchd job or a Linux crontab entry that runs the
curator on a fixed cadence.

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

## Lifecycle Scenario

A complete journey, from installing the framework to closing the
harness loop:

1. **Install** — fork crewrig, then run
   `task setup-claude-interactive` (or `task setup-gemini-interactive`).
   Generate your profile with `/init-personal-profile` and your soul
   with `/init-soul`.
2. **Create** — add a `SKILL.md` to
   `community-config/skills/my-skill/`, or run
   `task create-extension NAME=my-skill`. Run `task build-components`
   to generate outputs for both CLIs.
3. **Use on another project** — install the component:
   `task install-claude-component TYPE=claude-skills NAME=my-skill`.
   The skill is now available in Claude Code on that project.
4. **Record frictions** — as agents use the skill, they invoke the
   `harness-report` skill the moment a recognition signal fires. Each
   friction tag lands in the MemPalace `harness-friction` wing.
5. **Transform frictions into tickets** — run
   `task harness-curate -- --apply`. The curator clusters the
   frictions and opens one GitHub issue per cluster against the
   target repo.
6. **Implement** — address the issues via feature branches. The
   internal agent crew (architect → developer → tester → pr-logbook →
   pr-reviewer) handles the cycle.
7. **Install the new version** — run `task build-components` and
   reinstall; `metadata.provenance.version` bumps confirm which
   components changed.
8. **Back to step 3** — use the improved skill on your projects; the
   harness loop continues.

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
git clone git@github.com:hcross/crewrig.git
cd crewrig

# Generate your personal profile
gemini "/init-personal-profile"

# Customize the agent identity
gemini "/init-soul"

# Run the interactive setup (deploys to ~/.gemini/)
task setup-gemini-interactive
```

### Claude Code

```bash
git clone git@github.com:hcross/crewrig.git
cd crewrig

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
│   ├── ci-workflow-engineering/
│   ├── harness-report/                   # Skill: tag frictions during real work
│   │   └── SKILL.md
│   ├── harness-curator/                  # Skill: cluster frictions and open GitHub issues
│   │   ├── SKILL.md
│   │   └── scripts/                      # schedule-curator.sh (launchd/crontab installer), ...
│   └── pr-reviewer/                      # Skill: independent PR reviewer persona + linters
│       ├── SKILL.md
│       └── scripts/                      # lint-shell.sh, lint-markdown.sh, lint-skill.sh,
│                                         # lint-python.sh, lint-json.sh
├── commands/              # Shared slash commands
├── hooks/                 # Lifecycle hooks
├── agents/                # Sub-agent definitions
│   └── pr-reviewer/                      # Agent: cold-start independent PR reviewer
│       └── AGENT.md
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
├── lib/common.sh                         # Shared Bash helpers (sourced by other scripts)
├── check-skill-versions.sh               # CI gate: enforces version bump on modified SKILL.md/AGENT.md
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
| 2026-03-17 | GDG Cloud Paris | L'IA ne fera rien sans nous | [README](communication/talks/gdg-cloud-paris-2026-03-17/README.md) · [Slides](https://hcross.github.io/crewrig/talks/gdg-cloud-paris-2026-03-17/) |

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
  setup script auto-detects the right Python interpreter and verifies the
  installed version is within the supported range `>=3.3.3,<3.4`). Install
  or upgrade with `task install-mempalace` (or
  `pipx install --force 'mempalace>=3.3.3,<3.4'`).
- **GitHub** — Available via Claude Code's built-in connectors.

## Contributing

All contributions go through feature branches merged into `main` via Pull
Request. See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the full guide,
[`DEVELOPMENT.md`](DEVELOPMENT.md) for the extension development lifecycle,
and [`AGENTS.md`](AGENTS.md) for commit conventions (Gitmoji), PR format,
and logbook issue requirements.
