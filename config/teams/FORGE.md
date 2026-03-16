# Team Forge — Core API & Backend Services

## Mission

Forge designs and operates the core backend services that power the product:
REST and gRPC APIs, domain logic, data pipelines, and third-party
integrations. Reliability and data integrity are the team's north star.

## Technology Stack

- **Language:** Java 21 (Spring Boot 3.4), Kotlin for new microservices
- **Persistence:** PostgreSQL, Redis, Elasticsearch
- **Messaging:** Kafka for event-driven workflows
- **Build:** Gradle, Docker, Jib for container images
- **Testing:** JUnit 5, Testcontainers, WireMock for external stubs

## Development Practices

- API contracts (OpenAPI / Protobuf) are agreed upon before implementation
  begins. Breaking changes go through a deprecation cycle.
- Domain-driven design: bounded contexts map to service boundaries.
  Aggregates enforce consistency rules.
- Database migrations managed with Flyway. Every migration is reversible
  or accompanied by a rollback script.
- Zero-downtime deployments via rolling updates. Feature flags for
  progressive rollouts.

## Rituals

Hybrid Scrum/Kanban: two-week sprints for feature work, Kanban for
production support and bug fixes. Daily standup, weekly technical
deep-dive, retrospective every two weeks.

## Collaboration Norms

- Branch naming: `feat/`, `fix/`, `refactor/` prefixes.
- Gitmoji commits. PRs require two approvals for API-surface changes, one
  for internal refactors.
- Architectural decisions recorded as lightweight ADRs in the repository.
- Pair programming encouraged for complex domain logic.

## Documentation

- **Confluence:** Space "Forge Engineering" for service catalog, runbooks,
  and incident timelines.
- **Doc-as-code:** OpenAPI specs published automatically from CI; ADR
  folder in each service repository.

## Issue Tracking

- Jira project prefix: **`FRG-`**
- Epics aligned with product roadmap quarters. Tech-debt stories tracked
  in a dedicated backlog column.

## Key Contacts

- **Tech Lead:** forge-lead@example.com
- **Slack:** #team-forge
