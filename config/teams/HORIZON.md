# Team Horizon — Data & Analytics

## Mission

Horizon builds and maintains the data platform: ingestion pipelines,
transformation layers, analytical warehouses, and self-service dashboards.
The team turns raw operational data into actionable insights for product
and business stakeholders.

## Technology Stack

- **Orchestration:** Apache Airflow, dbt for transformations
- **Storage:** BigQuery (primary warehouse), Cloud Storage for raw landing
- **Streaming:** Kafka Connect for CDC, Dataflow for real-time aggregations
- **Visualization:** Looker, Metabase for ad-hoc exploration
- **Languages:** Python 3.13, SQL, Spark (PySpark) for heavy batch jobs

## Development Practices

- ELT over ETL: load raw data first, transform inside the warehouse with
  dbt models that are tested and documented.
- Data contracts between producers and consumers are explicit. Schema
  changes require a migration PR reviewed by both parties.
- Data quality checks (freshness, volume, schema drift) run after every
  pipeline execution. Failures page the on-call analyst.
- PII is classified at ingestion and masked or tokenized before reaching
  analytical layers.

## Rituals

SAFe-inspired cadence: PI planning every 10 weeks aligned with the broader
organization. Two-week iteration cycles within each PI. Weekly data quality
review. Monthly analytics showcase for stakeholders.

## Collaboration Norms

- Branch naming: `data/`, `fix/`, `model/` prefixes.
- Gitmoji commits. PRs on dbt models require one analytics engineer
  approval plus a passing `dbt test` in CI.
- Dashboards go through a peer review before being shared organization-wide.
- Major schema evolutions are announced one sprint in advance to downstream
  consumers.

## Documentation

- **Confluence:** Space "Horizon Data Platform" for data dictionaries,
  pipeline architecture, and SLA definitions.
- **Doc-as-code:** dbt docs site auto-generated and deployed from the
  `horizon-warehouse` repository.

## Issue Tracking

- Jira project prefix: **`HRZ-`**
- Data incidents tracked as bugs with `data-quality` label. Pipeline
  feature requests managed as stories.

## Key Contacts

- **Data Lead:** horizon-lead@example.com
- **Slack:** #team-horizon
