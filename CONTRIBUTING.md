# Contributing

Thanks for helping improve `pg_sag_rag`.

## Development Setup

Use Docker for the default development path:

```bash
docker compose up --build -d
docker compose exec -T postgres psql -U postgres -d rag -f /workspace/tests/smoke.sql
docker compose exec -T postgres psql -U postgres -d rag -f /workspace/tests/benchmark.sql
docker compose exec -T postgres psql -U postgres -d rag -f /workspace/tests/profile.sql
docker compose exec -T postgres psql -U postgres -d rag -f /workspace/tests/router.sql
```

The extension is SQL-only in `v0.1.0`; most changes should be made in `pg_sag_rag--0.1.0.sql`, tests, docs, or benchmark scripts.

## Pull Request Checklist

- Keep changes scoped to one behavior or documentation topic.
- Add or update SQL tests for retrieval behavior changes.
- Update README/docs when user-facing APIs change.
- Run the Docker test commands above before opening a PR.
- Include benchmark output when changing ranking, routing, scoring, or fanout behavior.

## Benchmark Changes

For synthetic enterprise benchmarks:

```bash
python3 scripts/enterprise_benchmark.py --cases-per-category 20 --out demo/enterprise_benchmark.sql
docker compose exec -T postgres psql -U postgres -d rag -f /workspace/demo/enterprise_benchmark.sql
```

Generated benchmark SQL files are ignored by git. Commit script changes and documented results, not large generated fixtures.

## SQL Style

- Prefer explicit schemas such as `sag_rag.event`.
- Keep functions stable and composable where possible.
- Avoid hidden calls to external services from PostgreSQL.
- Keep scoring parameters visible in function arguments or `sag_rag.retrieval_profile`.
