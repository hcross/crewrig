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

### Palace Structure Conventions

Organize knowledge using the palace metaphor:

```
MemPalace
├── wing: <project-name>                 # One wing per project
│   ├── room: architecture-decisions     # ADRs, design choices
│   ├── room: obstacles-and-solutions    # Problems + resolutions
│   └── room: <topic-as-needed>          # Created organically
│
├── wing: <user-name>                    # Personal wing (optional)
│   ├── room: preferences               # Working style, tool preferences
│   └── room: expertise                  # Domains of knowledge
│
└── wing: transcripts                    # Session recordings (if enabled)
    └── room: <tool>-<date>-<session-id> # One room per session
```

- **Wings**: Top-level grouping. One per project, plus optional personal
  and transcript wings.
- **Rooms**: Topic-based within a wing. Created as needed.
- **Drawers**: Individual content entries within a room.
- **Halls**: Connection types (facts, events, discoveries, preferences).
- **Tunnels**: Cross-wing connections discovered automatically.

### Memory Activation Protocol

Follow this protocol at every session:

**1. Session Start — Search and Recall**

Before starting any work:
- Search MemPalace for `[TASK:ongoing]` diary entries to resume
  interrupted work.
- Read recent diary entries for session continuity.
- Query the Knowledge Graph for facts about the current project.

**2. During Work — Continuous Persistence**

As you work, persist continuously:
- Every significant decision → drawer in the relevant room.
- Every obstacle + resolution → `obstacles-and-solutions` room.
- Every fact or relationship → Knowledge Graph with validity window.
- Task checkpoints → diary entry with `[TASK:ongoing]` or
  `[TASK:checkpoint]` tag.

**3. Session End — Final Flush**

Before ending:
- Write a diary entry summarizing the session.
- Update `[TASK:ongoing]` entries: mark `[TASK:done]` or leave ongoing
  with updated status.
- Flush any un-persisted Sequential Thinking state to MemPalace.

### Long-Running Task Convention

Use structured tags in Agent Diary entries to track tasks across sessions:

**Starting a task:**
```
[TASK:ongoing] <task-id> | <brief-description>
Status: <phase/step description>
Next: <what to do next>
Blocked: <if blocked, why>
Context: <key facts needed to resume>
```

**Resuming a task:**
```
[TASK:checkpoint] <task-id> | <brief-description>
Resumed from: <previous diary entry reference>
Progress: <what was accomplished since last checkpoint>
```

**Completing a task:**
```
[TASK:done] <task-id> | <brief-description>
Outcome: <result summary>
Lessons: <what was learned>
```

To resume work across sessions, search the diary for `[TASK:ongoing]`
entries.

### Knowledge Graph Conventions

- **Temporal facts**: Use validity windows (`valid_from` / `valid_to`)
  for facts that change over time.
- **Contradiction detection**: The KG detects conflicting facts. When
  flagged, investigate and invalidate the outdated fact.
- **Entity naming**: Use descriptive names. Disambiguate with parentheses
  when needed: `React (Library)` vs `React (Concept)`.

### MCP Tools Reference

MemPalace provides 19 MCP tools:

| Category | Tools |
|----------|-------|
| **Palace read** | `mempalace_status`, `mempalace_list_wings`, `mempalace_list_rooms`, `mempalace_get_taxonomy`, `mempalace_search`, `mempalace_check_duplicate`, `mempalace_get_aaak_spec` |
| **Palace write** | `mempalace_add_drawer`, `mempalace_delete_drawer` |
| **Knowledge Graph** | `mempalace_kg_query`, `mempalace_kg_add`, `mempalace_kg_invalidate`, `mempalace_kg_timeline`, `mempalace_kg_stats` |
| **Navigation** | `mempalace_traverse`, `mempalace_find_tunnels`, `mempalace_graph_stats` |
| **Agent Diary** | `mempalace_diary_write`, `mempalace_diary_read` |

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
   MemPalace (drawer in relevant room + diary entry if task is ongoing).

### Persistence Obligation

Sequential Thinking is ephemeral — it lives only within the current
session. Before ending a session:

- Persist the current plan state to MemPalace Agent Diary
  (`[TASK:ongoing]` if work continues).
- Record key decisions and reasoning as drawers in the relevant room.
- Record discovered facts in the Knowledge Graph.

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
