# Enterprise Benchmark

`scripts/enterprise_benchmark.py` generates a deterministic enterprise-style benchmark with three categories:

- `direct`: the answer is directly semantically close to the question.
- `cross_document`: the question first matches a product/status event, while the answer is in a separate procedure event linked by a shared topic entity.
- `noisy_relation`: the answer requires entity expansion, but there are adjacent policy notes and distractors.

## Run

```bash
python3 scripts/enterprise_benchmark.py --cases-per-category 20 --out demo/enterprise_benchmark.sql
docker compose exec -T postgres psql -U postgres -d rag -f /workspace/demo/enterprise_benchmark.sql
```

## Current Result

Overall:

| Strategy | K | Recall | MRR | Avg first gold rank |
|---|---:|---:|---:|---:|
| hybrid | 1 | 33.33% | 0.3333 | 1.00 |
| hybrid | 10 | 100% | 0.5222 | 2.73 |
| multihop conservative | 10 | 100% | 0.5222 | 2.73 |
| multihop relation-focused | 10 | 100% | 0.5500 | 2.80 |
| auto router | 10 | 100% | 0.8000 | 1.80 |

By category:

| Category | Best hybrid MRR | Best multihop MRR | Interpretation |
|---|---:|---:|---|
| direct | 1.0000 | 1.0000 conservative, 0.2500 relation-focused | Direct semantic answers do not need relation boost; `auto` keeps them on `hybrid` and scores 1.0000 MRR. |
| cross_document | 0.2833 | 0.7000 relation-focused | Entity expansion moves answer evidence much earlier; `auto` routes fault-code questions to `multihop_relation` and scores 0.7000 MRR. |
| noisy_relation | 0.2833 | 0.7000 relation-focused | Relation expansion helps when entities are stable; `auto` routes contract-exception questions to `multihop_relation` and scores 0.7000 MRR. |

## Interpretation

The benchmark supports a narrower product claim:

```text
Multihop SQL JOIN expansion helps when the workload is relation-required.
It should be conservative or disabled for direct semantic lookup.
```

This is important for enterprise use. A production deployment should classify or route queries:

- direct FAQ/policy question -> hybrid retrieval
- product + fault code / customer + contract / workflow + exception -> relation-focused multihop
- uncertain query -> conservative multihop that preserves hybrid ranking

The plugin value is therefore not a universal ranking improvement. It is a PostgreSQL-native retrieval layer that can switch strategies and evaluate them inside the database.

After adding `sag_rag.search_events_auto`, the benchmark shows the intended product shape: the router preserves the best direct-lookup behavior while applying relation expansion only to query classes where it helps.
