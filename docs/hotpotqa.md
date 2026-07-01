# HotpotQA Small-Sample Benchmark

This project includes a generator for a real HotpotQA dev-distractor small sample.

The adapter downloads HotpotQA, selects bridge-style examples where one supporting paragraph mentions another supporting paragraph title, ingests real sentences as `event` rows, and links events through Wikipedia-title entities.

It intentionally uses deterministic hashing vectors instead of an external embedding API. This keeps the benchmark reproducible, but the numbers should be treated as a retrieval-shape smoke test rather than a model-quality claim.

## Run

```bash
python3 scripts/hotpotqa_benchmark.py --limit 20 --run
```

Equivalent split form:

```bash
python3 scripts/hotpotqa_benchmark.py --limit 20 --out demo/hotpotqa_sample.sql
docker compose exec -T postgres psql -U postgres -d rag -f /workspace/demo/hotpotqa_sample.sql
```

## Current Result

On a 20-question bridge sample from HotpotQA dev distractor:

| Strategy | K | Recall | MRR | Avg first gold rank |
|---|---:|---:|---:|---:|
| hybrid | 1 | 30% | 0.3000 | 1.00 |
| hybrid | 10 | 75% | 0.4396 | 2.73 |
| multihop | 10 | 80% | 0.4517 | 2.75 |

The best tested multihop settings were:

```text
seed_k = 10
top_k = 10
max_events_per_entity = 10
text_weight = 0.35
vector_weight = 0.60
relation_weight = 0.05
```

## Interpretation

The first naive setting over-weighted relation expansion and performed worse than hybrid retrieval. After lowering relation weight and keeping the full hybrid seed set, multihop produced a small improvement:

- Recall@10 improved from 75% to 80%.
- MRR@10 improved from 0.4396 to 0.4517.

This is a useful but modest signal. It suggests SQL JOIN expansion can help on real multi-hop data, but only when relation expansion is treated as a conservative candidate supplement rather than a dominant rank boost.
