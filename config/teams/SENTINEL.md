# Team Sentinel — Quality Assurance & Test Engineering

## Mission

Sentinel owns the quality strategy across the organization: test automation
frameworks, performance benchmarking, security scanning, and release
qualification. The team acts as a quality enabler for all product squads.

## Technology Stack

- **E2E & UI:** Playwright (TypeScript), Selenium (Java) for legacy suites
- **API Testing:** REST Assured, Postman collections for exploratory work
- **Performance:** k6 for load testing, Grafana for result dashboards
- **Security:** OWASP ZAP integrated in CI, dependency scanning via Trivy
- **CI Integration:** GitHub Actions with parallel test sharding

## Development Practices

- Every automated test has a clear owner and a documented purpose. Orphan
  tests are retired during quarterly cleanup sprints.
- Test data is generated programmatically — no reliance on shared staging
  databases. Factories and fixtures are version-controlled.
- Flaky tests are quarantined immediately and tracked in a dedicated board.
  A flaky test that is not fixed within one sprint is deleted.
- Performance baselines are recorded per release. Regressions beyond
  defined thresholds block promotion to production.

## Rituals

Kanban with continuous flow. Daily standup (async via Slack on quiet days).
Monthly quality review with all squad leads to share metrics and align on
coverage priorities. Quarterly test strategy retrospective.

## Collaboration Norms

- Branch naming: `test/`, `fix/`, `perf/` prefixes.
- Gitmoji commits. PRs require one approval from a Sentinel member plus
  confirmation that the changed suite passes green on CI.
- Test plans for major features are reviewed collaboratively with the
  owning product squad before automation begins.
- Bug reports follow a structured template: steps, expected, actual,
  severity, screenshots or logs attached.

## Documentation

- **Confluence:** Space "Sentinel QA Hub" for test strategy documents,
  coverage dashboards, and incident post-mortems from a QA perspective.
- **Doc-as-code:** Test framework README and contributor guide maintained
  in the `sentinel-framework` repository.

## Issue Tracking

- Jira project prefix: **`STN-`**
- Bugs raised by Sentinel are tagged with `found-by:sentinel`. Test
  automation stories tracked separately from product stories.

## Key Contacts

- **QA Lead:** sentinel-lead@example.com
- **Slack:** #team-sentinel
