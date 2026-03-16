# Team Nova — Consumer Web Application

## Mission

Nova builds and maintains the customer-facing web application. The team owns
the entire frontend experience from landing pages to authenticated user
dashboards, with a strong focus on performance, accessibility, and
conversion.

## Technology Stack

- **Frontend:** React 19, TypeScript 5.7, Vite, Tailwind CSS
- **State & Data:** TanStack Query, Zustand
- **Testing:** Vitest, React Testing Library, Playwright for E2E
- **BFF:** Node.js (Express) as a Backend-for-Frontend layer
- **Monitoring:** Sentry for error tracking, Web Vitals via Grafana

## Development Practices

- Component-driven development: each feature is a self-contained module
  with co-located tests and styles.
- Strict TypeScript — `any` is banned. Discriminated unions for complex
  state modeling.
- Accessibility is a first-class requirement: semantic HTML, ARIA
  attributes, keyboard navigation tested in every PR.
- Performance budgets enforced in CI: Lighthouse score thresholds for LCP,
  CLS, and INP.

## Rituals

Scrum with two-week sprints. Sprint planning Monday, daily standup (15 min),
demo and retrospective every other Friday. Backlog refinement mid-sprint.

## Collaboration Norms

- Branch naming: `feat/`, `fix/`, `ui/` prefixes.
- Gitmoji commits. PRs require one approval plus a passing Lighthouse check.
- Design reviews with UX before implementation of any user-facing change.
- Shared component library maintained in a dedicated package.

## Documentation

- **Confluence:** Space "Nova Frontend" for design system guidelines,
  architecture diagrams, and sprint reports.
- **Doc-as-code:** Storybook deployed from the main branch for living
  component documentation.

## Issue Tracking

- Jira project prefix: **`NOV-`**
- User stories tied to UX mockups. Bugs triaged within 24 hours.

## Key Contacts

- **Tech Lead:** nova-lead@example.com
- **Slack:** #team-nova
