# Benchmark

`demo/benchmark.sql` is a deterministic synthetic benchmark for the first retrieval pattern this extension targets:

```text
query -> bridge event -> shared entity -> answer event
```

The benchmark creates five small domains. Each question is intentionally closest to a bridge event such as `AGI Bar serves foam drinks`, while the gold answer is stored in another event linked by the shared entity.

## Run

```bash
docker compose up --build -d
docker compose exec -T postgres psql -U postgres -d rag -f /workspace/tests/benchmark.sql
```

## Expected Result

The benchmark compares:

- `hybrid@1`: ordinary hybrid retrieval with one result.
- `hybrid@10`: ordinary hybrid retrieval with ten results.
- `multihop@10`: seed retrieval plus SQL JOIN expansion through entities.

Expected metrics:

| Strategy | K | Recall | MRR | Avg first gold rank |
|---|---:|---:|---:|---:|
| hybrid | 1 | 0% | 0.0 | null |
| hybrid | 10 | 100% | 0.5 | 2.0 |
| multihop | 10 | 100% | 1.0 | 1.0 |

Interpretation:

- `hybrid@10` can recover the answer if enough context is allowed.
- `multihop@10` moves the first gold answer from rank 2 to rank 1.
- The measured gain in this fixture is MRR `0.5 -> 1.0`, a 100% relative improvement in first-answer ranking quality.

This is not a claim about production datasets. It is a controlled regression test for the core mechanism: SQL JOIN expansion should improve multi-hop answer ranking when the seed event and answer event share an entity.
