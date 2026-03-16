# Team Atlas — Platform & Infrastructure

## Mission

Atlas owns the shared platform layer: CI/CD pipelines, cloud infrastructure,
developer tooling, and observability. The team ensures every other squad can
ship reliably and operate their services with confidence.

## Technology Stack

- **Infrastructure:** Terraform, Kubernetes (GKE), Helm, ArgoCD
- **CI/CD:** GitHub Actions, self-hosted runners, Docker
- **Observability:** Prometheus, Grafana, Loki, PagerDuty
- **Languages:** Go for internal tooling, Bash for automation, Python for
  scripting and glue

## Development Practices

- Every infrastructure change goes through code review — no ad-hoc console
  modifications. Terraform plans are attached to PRs for visibility.
- Pipelines follow a strict stage progression: lint → test → build →
  security scan → deploy to staging → promote to production.
- On-call rotation covers the full platform. Incidents are post-mortemed
  within 48 hours with blameless write-ups stored in the team wiki.
- SLOs are defined for every shared service. Alerting targets symptoms
  (latency, error rate) rather than causes (CPU, memory).

## Rituals

Kanban-based flow with weekly planning and WIP limits. Daily standup (15 min).
Bi-weekly retrospective. Quarterly OKR review aligned with the engineering
leadership.

## Collaboration Norms

- Branch naming: `infra/`, `fix/`, `tool/` prefixes.
- Commits follow Gitmoji convention. PRs require one approval minimum.
- Major infrastructure changes are proposed via short RFCs reviewed by the
  team before implementation.
- Weekly sync with product squads to gather platform pain points and
  prioritize tooling improvements.

## Documentation

- **Confluence:** Space "Atlas Platform Hub" for runbooks, architecture
  decision records, and onboarding guides.
- **Doc-as-code:** Repository `atlas-docs` containing versioned technical
  documentation (Markdown), reviewed alongside infrastructure changes.

## Issue Tracking

- Jira project prefix: **`ATS-`**
- Epics for quarterly platform objectives, stories for individual
  deliverables, bugs for incidents and regressions.

## Key Contacts

- **Tech Lead:** platform-lead@example.com
- **Slack:** #team-atlas
