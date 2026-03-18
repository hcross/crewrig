# Tools and MCP Server Guidelines

Prefer these integrated tools over ad-hoc alternatives unless the user
explicitly directs otherwise.

## GitHub MCP Server

Authenticated access to the GitHub API via OAuth. Use it for all GitHub
interactions: repository browsing, issue and PR management, code review,
branch operations, and release tracking.

## Knowledge Graph Memory (`@modelcontextprotocol/server-memory`)

The Knowledge Graph is the **primary liaison memory**. Every significant topic,
decision, or entity MUST result in a graph node.

### Naming & Classification

- **Nomenclature:** Use descriptive names. If two concepts share a name, use
  parentheses for classification: `Name (Classification)`.
  *Example: `React (Library)` vs `React (Concept)`.*
- **Hierarchy:** Use `/` for specialization, up to **7 levels deep**.
- **Root Categories (Proposed):**
  - `knowledge/`: General concepts, tech stack, methodologies.
  - `project/`: Specific workspace tasks, roadmap, architectural decisions (ADRs).
  - `entity/`: People, teams, organizations.
  - `process/`: Workflows, automation scripts, CI/CD.
  - `meta/`: Agent self-reflection, personal preferences, session logs.
  - `archive/`: Deprecated or historical information.

### Interaction Rules

- **Observations:** Use standard keys for entity properties (e.g., `type`, `status`, `owner`).
- **Relations:** Systematically create relations between nodes to build a semantic
  web (e.g., `Project A` -> `uses` -> `Library B`).

## Deep Memory (`@basicmachines-co/basic-memory`)

Deep Memory is for **dense, long-form content** that requires significant
context (whitepapers, detailed specs, research papers).

### Entry Structure

Every deep memory entry MUST follow this template:

```markdown
---
title: [Short Title]
summary: [Max 2 sentences, <20 words summary]
scope: [Global/Project/Team]
metadata:
  source: [URL/File path]
  tags: [tag1, tag2]
  created: [ISO Date]
  updated: [ISO Date]
  related_nodes: [Graph node names]
---
# [Level 1 Title]
[Summary goes here]

[Body Content...]
```

### Liaison with Knowledge Graph

- Every Deep Memory entry MUST have a corresponding "shadow" node in the
  Knowledge Graph.
- **Node Name:** `deep-memory://path/to/entry`.
- **Node Type:** `deep-memory-entry`.
- **Observations:** Must contain a brief recap of key points from the deep
  memory file to allow graph-based discovery without opening the full file.

## Sequential Thinking (`@modelcontextprotocol/server-sequential-thinking`)

Sequential Thinking is the **working memory** used for structuring complex
reasoning and problem-solving in real-time.

### Proposed Modus Operandi

1. **Initialization:** When facing a complex task, start a thinking sequence
   to map out hypotheses.
2. **Iterative Refinement:**
   - **Step 1:** Define the core problem and constraints.
   - **Step 2:** List potential solutions or paths.
   - **Step 3:** Evaluate each path (pros/cons).
   - **Step 4:** Select and execute the best path.
3. **Branching:** If a path fails, backtrack in the thinking sequence and
   try an alternative branch.
4. **Finalization:** Summarize the final reasoning and record the outcome
   in the Knowledge Graph.

## Memory Activation & Persistence Protocol

### Search & Discovery

- **New Task?** Always search both Knowledge Graph and Deep Memory for
  relevant context before starting.
- **Node Management:** Keep a list of "open" nodes in the current context.
  Discard nodes as the conversation drifts to unrelated topics.

### Writing & Update

- **Context Awareness:** Monitor context window usage. If nearing limits,
  summarize current work and persist it to Deep Memory before clearing context.
- **Systematic Persistence:** All completed work segments MUST be recorded
  in the appropriate memory (Liaison for relationships, Deep for details).
