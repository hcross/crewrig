# Extension Development Guide

This document covers the full lifecycle of creating, developing, testing,
and releasing extensions in this monorepo. Extensions work with both
**Gemini CLI** and **Claude Code**.

## Creating a New Extension

Always use the interactive scaffolding task:

```bash
task create-extension NAME=my-extension
```

An fzf menu lets you select which components to include (use TAB to
toggle, ENTER to confirm):

- **mcp-server** — TypeScript MCP server with stdio transport
- **command** — Sample `.toml` slash command
- **skill** — Sample `SKILL.md` agent skill
- **agent** — Sub-agent prompt definition
- **hook** — Lifecycle hook (BeforeTool/AfterTool)
- **theme** — UI theme JSON fragment

The script will:

1. Copy the base skeleton into `extensions/my-extension/`.
2. Inject selected component directories.
3. Replace every `SKELETON_NAME` placeholder with your extension name.
4. Merge JSON fragments (MCP server, theme) into the manifest.

### Skeleton Structure

The `extension-skeleton/` directory contains the template source:

```text
extension-skeleton/
├── .geminiignore                          # Prevents Gemini from loading templates
├── base/                                  # Always copied
│   ├── gemini-extension.json              # Gemini CLI manifest
│   ├── claude-extension.json              # Claude Code metadata (for install script)
│   ├── package.json                       # npm package with MCP SDK dependency
│   ├── tsconfig.json                      # TypeScript ES2022 / Node16
│   ├── GEMINI.md                          # Agent context placeholder
│   ├── README.md                          # Documentation placeholder
│   └── .gitignore                         # node_modules, dist, .env
├── mcp-server/                            # MCP server component
│   ├── src/index.ts                       # Stdio MCP server with sample tool
│   └── mcp-server.json.fragment           # Merged into manifest on creation
├── command/commands/sample.toml           # Sample slash command
├── skill/skills/sample-skill/SKILL.md     # Sample agent skill
├── agent/agents/sample-agent/PROMPT.md    # Sample sub-agent prompt
├── hook/hooks/                            # Lifecycle hook
│   ├── hooks.json                         # Hook event configuration
│   └── logger.sh                          # Sample BeforeTool hook script
└── theme/theme.json.fragment              # Merged into manifest on creation
```

Every occurrence of `SKELETON_NAME` in these files is replaced with your
extension name during scaffolding.

### After Scaffolding

```bash
cd extensions/my-extension
npm install
```

## Development Workflow

### Link Mode

During development, use symlinks so changes take effect immediately
without reinstalling:

**Gemini CLI:**

```bash
task link-extensions
```

Start a Gemini session and your extension is loaded. Edit source files,
rebuild with `npm run build`, and restart Gemini to pick up changes.

**Claude Code:**

```bash
task link-claude-extensions
```

This merges the extension's MCP server config into `~/.claude/mcp.json`
and symlinks skills into `~/.claude/skills/`. Restart Claude Code to
pick up changes.

### Testing Locally

```bash
# Build the extension
cd extensions/my-extension
npm run build

# Verify the MCP server starts
node dist/index.js
# (Ctrl+C to stop — it runs on stdio)
```

## Branching Strategy

- Create a feature branch from `main`: `feat/my-extension`
- Open a Pull Request targeting `main`.
- Merging into `main` triggers the automated release pipeline.

## Versioning with Gitmoji

Semantic Release analyzes commit messages using Gitmoji to determine
version bumps automatically:

| Gitmoji | Meaning | Release |
|---------|---------|---------|
| `:boom:` | Breaking change | **MAJOR** |
| `:sparkles:` | New feature | **MINOR** |
| `:bug:` | Bug fix | **PATCH** |
| `:ambulance:` | Critical hotfix | **PATCH** |
| `:lock:` | Security fix | **PATCH** |
| `:zap:` | Performance improvement | **PATCH** |

Commits that do not match any rule (e.g., `:memo:`, `:wrench:`) do not
trigger a release.

### How It Works

1. A commit lands on `main` touching files in `extensions/my-extension/`.
2. The `release-monorepo` workflow detects the change.
3. `semantic-release-monorepo` scopes the analysis to that extension only.
4. `semantic-release-gitmoji` determines the version bump from the emoji.
5. A tag `my-extension-vX.Y.Z` is created.
6. A GitHub Release is published with the packaged `.tgz` as an asset.
7. A CHANGELOG.md is committed back into the extension directory.

Other extensions in the monorepo are not affected.

## Packaging

To manually package an extension without releasing:

```bash
# Single extension
task package-extension EXT=my-extension

# All extensions
task package
```

The `.tgz` files are written to `dist/`.

## Extension Anatomy

```text
extensions/my-extension/
├── gemini-extension.json   # Manifest (name, version, MCP server config)
├── package.json            # npm package (dependencies, build script)
├── tsconfig.json           # TypeScript configuration
├── GEMINI.md               # Agent context when extension is loaded
├── README.md               # Documentation
├── src/                    # MCP server source (TypeScript)
│   └── index.ts
├── commands/               # Slash command .toml files
├── skills/                 # Agent skill directories (SKILL.md)
├── agents/                 # Sub-agent prompts (PROMPT.md)
└── hooks/                  # Lifecycle hooks (hooks.json + scripts)
```

Not all directories are required — include only what your extension needs.
