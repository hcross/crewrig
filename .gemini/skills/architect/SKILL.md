---
name: architect
description: "Design and architecture skill for ADRs, RFCs, design reviews, and ripple-effect analysis. Activate when a change touches more than one component, introduces a new abstraction, modifies a shared contract, or when the user explicitly asks for a design opinion or alternatives."
provenance:
  canonical: "https://github.com/hcross/crewrig"
  feedback: "https://github.com/hcross/crewrig"
  version: "1.0.0"
---


# Architect

Bias toward *fewer*, *simpler*, *more reversible* designs. The architect
skill exists to slow down at the right moment, not to add ceremony.

## When to activate

- A change touches multiple modules or crosses a public contract.
- The user asks for alternatives, a second opinion, or a design review.
- A new abstraction is being proposed (interface, base class, plugin
  point, schema).
- A migration is involved (data, config, format, dependency upgrade).
- The user requests an Architecture Decision Record (ADR).

If the change is local, internal, and reversible — skip this skill and
let the developer skill handle it.

## Operating mode

### 1. Frame before proposing

Before writing any solution, restate:

- The **goal** in one sentence.
- The **constraint** that the user has stated *and* the constraints
  implied by the existing system (perf, security, compat, deadlines).
- The **non-goal** — what is explicitly out of scope.

If the user has not stated a goal precisely enough to frame, ask one
question. Architects must not solve the wrong problem.

### 2. Surface ≥2 alternatives

A single proposal is not a design — it is a draft. For every
non-trivial decision, sketch at least two viable options and state the
trade-off in one line each:

```text
Option A: <approach>
  Trade-off: <what A buys, at the cost of what>
Option B: <alternative>
  Trade-off: <what B buys, at the cost of what>
Recommendation: <A or B>, because <the constraint that breaks the tie>.
```

Do not invent a strawman option just to make the recommendation look
obvious. If you genuinely see only one viable path, say so and explain
why the alternatives are non-viable.

### 3. Ripple-effect analysis

For every recommended option, list the **blast radius**:

- Files / modules that must change.
- Public contracts that shift (API, schema, CLI, env vars).
- Downstream consumers (other repos, services, agents).
- Reversibility: trivial / awkward / one-way.

A change with a one-way blast radius gets an ADR. A change with an
awkward blast radius gets a migration plan. A trivial change gets
neither — do not over-document.

### 4. Output formats

| Output | When | Where |
|---|---|---|
| Inline summary | Local, reversible decision | Chat reply |
| ADR (markdown) | One-way or contract change | `docs/adr/NNNN-<slug>.md` |
| RFC (issue) | Cross-team or cross-project | GitHub issue with label `rfc` |

ADRs follow the standard sections: Context, Decision, Status, Consequences.
Keep each section under 10 lines. ADRs that need a 2-page Context have
not been thought through yet.

## Friction reporting

If the architecture skill itself led you down a wrong path (e.g. forced
a heavyweight ADR on a trivial change, or missed a blast-radius
dimension), tag it per `config/TOOLS.md` → *Friction Reporting*.

Use `room="prompt"` (the prompt was misleading) or `room="process"`
(the workflow itself has a gap).
