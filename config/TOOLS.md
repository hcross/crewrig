# Tools and MCP Server Guidelines

Prefer integrated MCP tools over ad-hoc alternatives unless the user
explicitly directs otherwise.

---

## Memory Architecture — Three-Tier Model

The agent operates with three memory tiers, each with a distinct role,
access model, and persistence strategy.

### Tier 1: Working Memory — Sequential Thinking

**Role**: Real-time reasoning engine for complex, multi-step tasks.

- **Scope**: Current session only (ephemeral).
- **When to use**: Complex reasoning, multi-step planning, design decisions,
  task decomposition, evaluation of alternatives.
- **Persistence obligation**: Any plan or reasoning that spans multiple
  sessions MUST be persisted to Tier 2 (MemPalace) before the session ends.

### Tier 2: Agent Memory — MemPalace

**Role**: Persistent memory that survives across sessions and across CLI
tools. The agent's long-term knowledge store.

- **Scope**: All sessions, all tools (Gemini CLI, Claude Code, etc.).
- **Read**: Free — always search MemPalace before starting work.
- **Write**: Free — persist everything learned, decided, and encountered.

### Tier 3: Second Brain — Obsidian (Optional)

**Role**: The user's personal knowledge base. A curated library of notes,
references, ideas, and domain knowledge.

- **Scope**: User-controlled. Available only if an Obsidian MCP server is
  present.
- **Read**: Free — browse and search the vault for context.
- **Write**: User-controlled only — MUST ask the user before writing.
  Never write without explicit consent.

---

## GitHub MCP Server

The GitHub MCP server MUST be used as a priority for all GitHub interactions,
except for native `git` commands.

---

## MemPalace — Agent Memory Protocol

MemPalace is the unified persistent memory system, replacing the former
Knowledge Graph Memory and Deep Memory servers. It provides palace-based
storage, a temporal knowledge graph, semantic search, and an agent diary.

> **MCP-only access.** Every MemPalace operation in this document
> (`mempalace_status`, `mempalace_search`, `mempalace_add_drawer`,
> `mempalace_update_drawer`, `mempalace_diary_*`, `mempalace_kg_*`, etc.)
> is an **MCP tool call** routed through the registered `mempalace` MCP
> server. **Never** invoke a `mempalace …` shell command via the Bash
> tool. The `mempalace` CLI binary on `$PATH` exists for human admin
> tasks (`init`, `migrate`, debug); calling it from an agent bypasses
> the MCP server's session context, file locking, audit trail, and
> protocol negotiation, and produces drawers the rest of the agent
> network cannot see. If a procedure cannot be expressed via the MCP
> tools listed in *MCP Tools Reference*, ask the user — do not reach
> for the CLI as a workaround.

### Palace Structure Conventions

Organize knowledge using the palace metaphor:

```text
MemPalace
├── wing: <project-name>                 # One wing per project
│   ├── room: task-handoff               # [TASK:*] cross-tool handoff lane
│   ├── room: architecture-decisions     # ADRs, design choices
│   ├── room: obstacles-and-solutions    # Problems + resolutions
│   └── room: <topic-as-needed>          # Created organically
│
├── wing: wing_<agent-name>              # Per-agent diary (MCP-forced)
│   └── room: diary                      # Reasoning provenance, self-recovery
│
├── wing: <user-name>                    # Personal wing (optional)
│   ├── room: preferences                # Working style, tool preferences
│   └── room: expertise                  # Domains of knowledge
│
└── wing: transcripts                    # Session recordings (if enabled)
    └── room: <project>-<date>-<sid>     # EXCLUDED from default sweep
```

- **Wings**: Top-level grouping. One per project, one per agent (auto-created
  by diary writes), one per user (optional), plus the `transcripts` wing.
- **Rooms**: Topic-based within a wing. Created as needed.
- **Drawers**: Individual content entries within a room.
- **Halls**: Connection types (facts, events, discoveries, preferences).
- **Tunnels**: Cross-wing connections discovered automatically.

#### Project name derivation

`<project-name>` is computed once at session start:

1. `git rev-parse --show-toplevel` → basename, if inside a git repo.
2. Otherwise: `basename "$(pwd)"`.

Stable across agents and across machines that clone the same repo at
different paths. Do not use the auto-derived path-based wings produced
by some hooks (e.g., `_users_..._gemini_configuration`); they are
machine-specific and not cross-tool stable.

#### Lane mapping — what writes where

| Lane | Write tool | Storage | Visible cross-tool? |
|---|---|---|---|
| **Cross-tool task handoff** | `mempalace_add_drawer` | `wing="<project-name>"`, `room="task-handoff"` | Yes — primary handoff surface |
| **Curated knowledge** | `mempalace_add_drawer` | `wing="<project-name>"`, `room="<topic>"` | Yes |
| **Per-agent diary** | `mempalace_diary_write` | `wing_<agent-name>` (MCP-forced) | No — siloed by design |
| **Raw archive** | hook-driven | `wing="transcripts"` | No — excluded from sweep |

The MCP surface forces this split: only `mempalace_add_drawer` and
`mempalace_update_drawer` accept arbitrary `wing` and `room` parameters.
The diary tools (`mempalace_diary_write` / `mempalace_diary_read`) only
expose `agent_name`, so diary entries always land in `wing_<agent-name>`
and cannot serve as the cross-tool handoff surface.

### Memory Activation Protocol

Follow this protocol at every session:

#### 1. Session Start — Deterministic status-first sweep

Before starting any work, perform an ordered sweep designed to be
deterministic — independent of BM25 weights, cosine thresholds, or
semantic similarity heuristics:

1. **Compute `<project-name>`** (see *Project name derivation* above).

2. **`mempalace_status`** — enumerate the wings present. Note the
   exclusion list: any wing whose name starts with `transcripts` is
   high-volume raw archive and is EXCLUDED from semantic searches.

3. **Cross-tool handoff lookup** — the primary resume mechanism:

   ```text
   mempalace_search(
     query="[TASK:ongoing]",
     wing="<project-name>",
     room="task-handoff"
   )
   ```

   Wing+room scoped, immune to transcripts noise, signal-dense by
   design. This is the canonical cross-tool task discovery path.

   Apply the `visible_to` filter client-side: ignore any returned entry
   whose `visible_to` field contains neither `*` nor your agent name.

4. **Per-agent provenance** — your own reasoning trace, not
   cross-tool discovery: `mempalace_diary_read(agent_name="<your-name>",
   last_n=N)`. Used only to recover your own recent thought process.

5. **Knowledge Graph** — `mempalace_kg_query` for facts about the
   current project.

6. **If step 3 returned a `[TASK:ongoing]` drawer for this project**
   (i.e., a sibling agent's open work or a previous session of yours):
   **immediately persist a `[TASK:checkpoint]` payload to that drawer
   via `mempalace_update_drawer` BEFORE doing any actual task work.**
   The checkpoint:

   - Marks the resumption point with the current timestamp.
   - Updates `writer_agent` to your own agent name.
   - Records `resumed_from` (the previous drawer revision) and an
     initial `progress` field describing the state you found.
   - Preserves the `drawer_id` and `handoff_key` (use
     `mempalace_update_drawer`, not `mempalace_add_drawer`).

   **This step is mandatory, not optional.** Skipping it breaks the
   audit trail of who-resumed-when and leaves siblings unable to detect
   that the task has been picked up. Treat the checkpoint write as part
   of the recovery itself, not as a chore to do "after the work".

**Why not `mempalace_search` without a wing filter?** The `transcripts`
wing typically contains thousands of raw transcript drawers, many
mentioning `[TASK:ongoing]` literally as documentation. Without a wing
filter, transcript noise overwhelms the BM25 hybrid scoring and buries
actual handoff entries. The wing+room scoped query above is the only
deterministic discovery path through the current MCP surface.

**Why not `mempalace_diary_read` for cross-tool resume?** The MCP
surface for `mempalace_diary_read` does not expose a `wing` parameter
— it only accepts `agent_name`. Diaries are per-agent silos at the MCP
level; they cannot serve as the cross-tool handoff surface. Use them
for your own provenance recovery only.

#### 2. During Work — Continuous Persistence

As you work, persist continuously:

- **Cross-tool task progress** → `mempalace_add_drawer` to
  `wing="<project-name>"`, `room="task-handoff"` with a `[TASK:ongoing]`
  or `[TASK:checkpoint]` payload (see *Long-Running Task Convention*
  for the exact schema).
- **Significant decisions** → drawer in the relevant project room
  (e.g., `architecture-decisions`).
- **Obstacles + resolutions** → drawer in `obstacles-and-solutions`.
- **Facts and relationships** → Knowledge Graph with validity window.
- **Per-agent reasoning trace** → `mempalace_diary_write` (your own
  diary, for self-recovery — not cross-tool handoff).

#### 3. Session End — Final Flush

Before ending:

- **Update the cross-tool handoff drawer** in
  `wing="<project-name>", room="task-handoff"`:
  - If work continues: ensure a `[TASK:ongoing]` drawer reflects the
    latest state. Prefer `mempalace_update_drawer` on the existing
    drawer (preserves the `drawer_id` and KG references); fall back to
    `mempalace_add_drawer` if you do not have the prior drawer_id.
  - If work is complete: replace the payload with `[TASK:done]` via
    `mempalace_update_drawer`.
- **Write a per-agent diary entry** summarizing the session
  (`mempalace_diary_write`) — self-recovery aid, not cross-tool.
- **Flush** any un-persisted Sequential Thinking state to MemPalace.

### Long-Running Task Convention

Cross-tool tasks live as **drawers** in the handoff lane
(`wing="<project-name>"`, `room="task-handoff"`), NOT as diary entries.
The drawer `content` field carries a structured plain-text payload.

Starting a task — `mempalace_add_drawer`:

```text
[TASK:ongoing] <task-id> | <brief-description>

writer_agent: <agent-name>
handoff_key: <task-id>
visible_to: ["*"]
status: <phase/step description>
next: <what to do next>
blocked: <if blocked, why>
context: <key facts needed to resume>
```

Resuming a task — `mempalace_update_drawer` on the existing drawer
(preserves `drawer_id` and KG links). The new content replaces the old.
**The checkpoint write is mandatory the moment a `[TASK:ongoing]` drawer
is found at session start (see *Session Start* step 6) — it is not
something to defer until "real work" begins.**

```text
[TASK:checkpoint] <task-id> | <brief-description>

writer_agent: <agent-name>
handoff_key: <task-id>
visible_to: ["*"]
resumed_from: <previous drawer_id>
progress: <what was accomplished since last checkpoint>
status: <current phase/step>
next: <what to do next>
context: <updated facts>
```

Completing a task — `mempalace_update_drawer`:

```text
[TASK:done] <task-id> | <brief-description>

writer_agent: <agent-name>
handoff_key: <task-id>
visible_to: ["*"]
outcome: <result summary>
lessons: <what was learned>
```

#### Field semantics

- `writer_agent` — agent identifier (e.g., `claude-code`, `gemini-cli`).
  Closes the "guess the previous writer" failure mode by making
  provenance explicit on every entry.
- `handoff_key` — deterministic anchor. Matches the `<task-id>` in the
  title line; useful for cross-referencing across drawer revisions or
  related tasks.
- `visible_to` — visibility allowlist. `["*"]` is the global default
  (visible to every agent). `["<agent>"]` restricts to a specific agent.
  `["<a>", "<b>"]` scopes to multiple agents. Reading agents apply the
  filter **client-side**: ignore any entry whose `visible_to` does not
  contain `*` and does not contain the reading agent's name. Honor
  system; no platform-level enforcement.

To resume work across sessions, the cross-tool sweep at session start
hits `room="task-handoff"` directly — see *Memory Activation Protocol →
Session Start*.

### Knowledge Graph Conventions

- **Temporal facts**: Use validity windows (`valid_from` / `valid_to`)
  for facts that change over time.
- **Contradiction detection**: The KG detects conflicting facts. When
  flagged, investigate and invalidate the outdated fact.
- **Entity naming**: Use descriptive names. Disambiguate with parentheses
  when needed: `React (Library)` vs `React (Concept)`.

### MCP Tools Reference

MemPalace exposes the following tool categories (v3.3.x). Tools used by
the cross-tool handoff protocol are highlighted in **bold**.

| Category | Tools |
|----------|-------|
| **Palace read** | **`mempalace_status`**, `mempalace_list_wings`, `mempalace_list_rooms`, `mempalace_list_drawers`, `mempalace_get_drawer`, `mempalace_get_taxonomy`, **`mempalace_search`**, `mempalace_check_duplicate`, `mempalace_get_aaak_spec` |
| **Palace write** | **`mempalace_add_drawer`**, **`mempalace_update_drawer`**, `mempalace_delete_drawer` |
| **Knowledge Graph** | **`mempalace_kg_query`**, `mempalace_kg_add`, `mempalace_kg_invalidate`, `mempalace_kg_timeline`, `mempalace_kg_stats` |
| **Navigation** | `mempalace_traverse`, `mempalace_find_tunnels`, `mempalace_graph_stats` |
| **Agent Diary** | `mempalace_diary_write`, **`mempalace_diary_read`** |

Notable v3.3.x facts that shape the protocol above:

- `mempalace_add_drawer` and `mempalace_update_drawer` accept arbitrary
  `wing` and `room` — the only MCP write paths that do. The handoff
  lane is built on these.
- `mempalace_diary_write` and `mempalace_diary_read` only accept
  `agent_name`, not `wing` (despite the v3.3.3 changelog note about an
  internal `wing` parameter). Diaries are MCP-level per-agent silos.
- `mempalace_search` returns BM25-hybrid (60 % vector + 40 % keyword)
  results since v3.3.0. The keyword share is real but does not
  overcome volumetric imbalance from the `transcripts` wing — always
  scope by `wing` and `room` for the handoff lookup.

---

## Friction Reporting — Harness Feedback Loop

The crew you operate within is not static. When an agent hits a sharp
edge during real work — a poorly-worded prompt, a tool that does the
wrong thing, an output format that breaks downstream parsing — that
signal must reach the maintainers of the agent system itself.
Otherwise the same friction repeats forever.

This section defines the **β-light tagging protocol**: agents tag
frictions as they happen, never blocking the work in progress. A
separate Curator agent (out of scope for this section) reads the tags
on demand and proposes feedback MRs against the canonical/feedback
repos declared in each component's `provenance:` block.

### When to tag

Tag a friction whenever you notice one. Do not pause the user's task.
The cost of one tag is negligible; the cost of an un-reported friction
that bites the next agent is much higher.

Concrete triggers:

- A skill or agent prompt led you to a wrong path you had to back out.
- An output format from another agent broke a downstream tool or parse.
- A tool invocation produced surprising or inconsistent behaviour.
- A documented process step turned out to be missing, ambiguous, or
  out of date.
- A safeguard / rule blocked a legitimate action and forced a workaround.

If unsure whether something qualifies — tag it. Curation will discard
noise; silent friction is the failure mode to avoid.

### Where to write

Frictions live in a **global** wing, not in the project wing. A friction
discovered while working on project X often applies to projects Y and Z
that fork the same skill — scoping per project would hide the pattern.

```text
mempalace_add_drawer(
  wing="harness-friction",
  room="<category>",
  content="<payload>"
)
```

### Categories (5, fixed)

Use exactly one of these as `room`. Sub-categorisation is free-form
inside the payload (`subcategory:` field).

| Category | Room name | Use for |
|----------|-----------|---------|
| Tool | `tool` | An MCP tool, CLI, or script behaved unexpectedly or has a sharp edge. |
| Prompt | `prompt` | A skill/agent prompt was misleading, ambiguous, or led you astray. |
| Format | `format` | An output format broke parsing, mixed concerns, or was hard to consume. |
| Behavior | `behavior` | The agent (you, or a sibling) did something it should not have, or skipped something it should have done. |
| Process | `process` | A documented workflow step is missing, contradictory, or out of date. |

### Payload schema

Plain text, structured like the `[TASK:*]` payloads. The `FRICTION:`
prefix on the first line is what the Curator searches for.

```text
FRICTION: <one-line title>

writer_agent: <agent-name>
subcategory: <free-form, optional — e.g. "yq-yaml-merge", "build-resolver">
session_id: <session id, if available>
project: <project name where it surfaced, if applicable>
canonical: <canonical URL of the offending component, if known>
severity: low | med | high      # default: med
evidence:
  - <path or URL #1>
  - <path or URL #2>
suggestion: <free-form fix idea, optional but encouraged>
```

#### Field semantics

- `writer_agent` — same convention as the task-handoff drawer. Lets the
  Curator attribute clusters and lets the user trace who hit what.
- `subcategory` — free-form clustering key. Frictions sharing a
  `subcategory` get bundled into the same MR by default.
- `evidence` — at least one entry is required. Path to the file, URL of
  the failing CI run, link to the transcript line, or a verbatim
  snippet. Without evidence the report is unactionable.
- `severity` — `high` is reserved for blockers (e.g. agent corrupted
  data, leaked a secret, or violated a stated guarantee). `low` is for
  papercuts. Default `med`.
- `suggestion` — what *you* think would fix it. Optional, but the
  Curator weights MRs higher when one is present.

#### Minimal example

```text
FRICTION: Skill prompt suggests yq merge syntax that does not exist on yq v4

writer_agent: claude-code
subcategory: yq-merge
canonical: https://github.com/hcross/crewrig
severity: med
evidence:
  - community-config/skills/architect/SKILL.md:42
suggestion: Replace `yq m -i` with `yq eval-all '. as $i ireduce ...'`.
```

### What NOT to tag

- One-off mistakes you made that the system did not actively cause —
  those belong in your diary, not in `harness-friction`.
- Bugs in the user's code under review — those belong in the project
  logbook issue.
- Missing features you wished existed — open a GitHub issue against
  the canonical repo instead. Friction reporting is for *defects in
  the agent system itself*, not feature requests.

### Read side

Reading `harness-friction` is the Curator agent's job, not the working
agents'. If you find yourself searching this wing during normal work,
you are off-task. The wing is write-mostly for everyone except the
Curator.

---

## Sequential Thinking — Working Memory Protocol

Sequential Thinking is the working memory used for structuring complex
reasoning and problem-solving in real-time.

### When to Use

- Complex tasks requiring structured evaluation of alternatives.
- Multi-step planning before implementation.
- Design decisions where trade-offs need explicit analysis.
- Any reasoning that benefits from step-by-step decomposition.

### Modus Operandi

1. **Initialize**: Start a thinking sequence with a clear objective.
2. **Iterative Refinement**:
   - Step 1: Define the core problem and constraints.
   - Step 2: List potential solutions or paths.
   - Step 3: Evaluate each path (pros/cons).
   - Step 4: Select and execute the best path.
3. **Branching**: If a path fails, backtrack and try an alternative.
4. **Finalization**: Summarize the reasoning and persist the outcome to
   MemPalace — drawer in the relevant project room, plus a
   `[TASK:ongoing]` drawer in the handoff lane if work continues across
   sessions.

### Persistence Obligation

Sequential Thinking is ephemeral — it lives only within the current
session. Before ending a session:

- If work continues, write or update the cross-tool handoff drawer
  (`mempalace_add_drawer` / `mempalace_update_drawer` on
  `wing="<project-name>"`, `room="task-handoff"`) with a
  `[TASK:ongoing]` payload reflecting the current plan state.
- Record key decisions and reasoning as drawers in the relevant project
  room.
- Record discovered facts in the Knowledge Graph.
- Optionally write a per-agent diary entry (`mempalace_diary_write`)
  for self-recovery — distinct from the cross-tool handoff drawer.

---

## Second Brain — Obsidian Protocol

If an MCP server providing access to an Obsidian vault is available
(e.g., `obsidian-mcp-server`), the following protocol applies.

### Availability Check

Before using Obsidian tools, verify the MCP server is present. If absent,
Tier 3 is simply unavailable — Tier 1 (Sequential Thinking) and Tier 2
(MemPalace) work independently. All memory protocols function without
Obsidian.

### Access Model

- **Read**: Free. Browse and search the vault to find relevant context,
  references, and domain knowledge that help achieve objectives.
- **Write**: User-controlled only. The agent may **suggest** notes to
  create or update, but MUST NOT write without the user's explicit
  consent for each operation.

### Vault Governance

If an `AGENTS.md` file exists at the root of the Obsidian vault, the
agent MUST conform to its rules. This file governs:

- Note naming conventions.
- Folder structure expectations.
- Tag and frontmatter conventions.
- Any vault-specific rules the user has established.

### Cross-Referencing

When the agent discovers a relevant Obsidian note, it may record a
reference in MemPalace (e.g., a drawer noting the Obsidian path and a
brief summary). This creates a bridge between tiers without duplicating
content.

---

## Memory Activation Summary

| Tier | System | Scope | Read | Write | Persistence |
|------|--------|-------|------|-------|-------------|
| 1 | Sequential Thinking | Session | Session | Session | Must flush to Tier 2 |
| 2 | MemPalace | All sessions, all tools | Free | Free | Automatic |
| 3 | Obsidian | User vault | Free | User consent | User-managed |
