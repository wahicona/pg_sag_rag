## Summary

What changed?

## Verification

- [ ] `docker compose up --build -d`
- [ ] `docker compose exec -T postgres psql -U postgres -d rag -f /workspace/tests/smoke.sql`
- [ ] `docker compose exec -T postgres psql -U postgres -d rag -f /workspace/tests/benchmark.sql`
- [ ] `docker compose exec -T postgres psql -U postgres -d rag -f /workspace/tests/profile.sql`
- [ ] `docker compose exec -T postgres psql -U postgres -d rag -f /workspace/tests/router.sql`
- [ ] `scripts/test_pg_matrix.sh` when compatibility or install behavior changes

## Benchmark Impact

Paste relevant output if retrieval scoring, routing, fanout, or evaluation changed.
