# Release Checklist

## Before Tagging

- Run `docker compose up --build -d`.
- Run `docker compose exec postgres psql -U postgres -d rag -f /workspace/tests/smoke.sql`.
- Run `docker compose exec postgres psql -U postgres -d rag -f /workspace/tests/benchmark.sql`.
- Run `docker compose exec postgres psql -U postgres -d rag -f /workspace/tests/profile.sql`.
- Run `docker compose exec postgres psql -U postgres -d rag -f /workspace/tests/router.sql`.
- Confirm the demo returns both `hybrid` and `multihop` evaluation rows.
- Confirm `sag_rag.route_query('PX-001 fault code E37 procedure')` returns `multihop_relation`.
- Confirm `SELECT sag_rag.create_hnsw_indexes(3, 'cosine');` succeeds.
- Review `README.md` quick start on a clean clone.
- Review `CHANGELOG.md`, `CONTRIBUTING.md`, `SECURITY.md`, and GitHub templates.

## Benchmark Snapshot

- Run `python3 scripts/enterprise_benchmark.py --cases-per-category 20 --out demo/enterprise_benchmark.sql`.
- Run `docker compose exec -T postgres psql -U postgres -d rag -f /workspace/demo/enterprise_benchmark.sql`.
- Confirm the enterprise benchmark summary includes:

```text
hybrid                MRR 0.5222
multihop_relation     MRR 0.5500
auto                  MRR 0.8000
```

## GitHub Setup

- Create a public repository named `pg_sag_rag`.
- Add the `postgresql`, `pgvector`, `rag`, `graphrag`, `agent-memory`, and `hybrid-search` topics.
- Enable GitHub Actions.
- Confirm generated files are not accidentally committed:
  - `data/hotpot_dev_distractor_v1.json`
  - `demo/hotpotqa_sample.sql`
  - `demo/enterprise_benchmark.sql`
- Add a short repository description:

```text
SQL-only PostgreSQL extension for SAG-style event/entity retrieval, query routing, and in-database evaluation.
```

## First Tag

```bash
git status
git tag v0.1.0
git push origin main --tags
```

## Release Notes Draft

```text
pg_sag_rag v0.1.0 is the first MVP release.

It provides a SQL-only PostgreSQL extension that packages SAG-style event/entity retrieval as database-native functions, with query routing and in-database evaluation.
```
