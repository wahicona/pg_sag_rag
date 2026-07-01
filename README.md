# pg_sag_rag

SQL-native multi-hop RAG for PostgreSQL. `pg_sag_rag` is a PostgreSQL extension that models enterprise knowledge as documents, chunks, events, entities, and event-entity links, then uses ordinary SQL JOINs, `pgvector`, and PostgreSQL full-text search for retrieval.

The project targets enterprise RAG and Agent data layers where documents, chunks, events, entities, permissions, metadata, and retrieval traces should live in one auditable database.

This project is not claiming to be the first PostgreSQL RAG or GraphRAG project. It is intentionally narrower: a SQL-only extension that focuses on event-level retrieval, relation expansion through `event_entity`, query routing, and database-native evaluation.

## Status

`v0.1.0` is an MVP intended for evaluation, demos, and design feedback. The extension is SQL-only: no C/Rust build step, no background workers, and no model API calls inside PostgreSQL.

Current benchmark signal:

| Benchmark | Best Fixed Baseline | Auto Router |
| --- | ---: | ---: |
| Enterprise synthetic MRR@10 | `0.5500` fixed `multihop_relation` | `0.8000` |
| HotpotQA 20-question sample Recall@10 | `75%` hybrid | `80%` tuned multihop |

## What It Provides

- Standard tables for documents, chunks, events, entities, aliases, event-entity links, and retrieval logs.
- Hybrid event search with vector similarity, full-text rank, and trigram similarity.
- SQL JOIN based one-hop expansion from seed events to related events through shared entities.
- Query routing that chooses `hybrid`, `multihop_conservative`, or `multihop_relation` per question.
- Trace helpers to explain why an event was retrieved.
- Optional HNSW index helper for your embedding dimension.

## What It Does Not Do

- It does not call LLM APIs from inside PostgreSQL.
- It does not extract entities or events by itself.
- It does not replace `pgvector`; it builds a RAG data model and retrieval flow on top of it.
- It does not try to be a full graph database.
- It is not a full GraphRAG application framework, API server, or ingestion pipeline.

## Quick Start

```bash
docker compose up --build -d
docker compose exec postgres psql -U postgres -d rag -f /workspace/demo/demo.sql
```

Expected demo signal:

```text
hybrid   recall@1  = 0
multihop recall@10 = 1
```

Run the smoke test:

```bash
docker compose exec postgres psql -U postgres -d rag -f /workspace/tests/smoke.sql
```

Run the synthetic benchmark:

```bash
docker compose exec postgres psql -U postgres -d rag -f /workspace/tests/benchmark.sql
docker compose exec postgres psql -U postgres -d rag -f /workspace/tests/router.sql
```

The compose setup mounts the repository into the container, so you can also open `psql` and run files manually:

```bash
docker compose exec postgres psql -U postgres -d rag
```

Then inside `psql`:

```sql
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pg_sag_rag;
```

## Core Query

```sql
SELECT *
FROM sag_rag.search_events_auto(
    'How much is AGI Bar foam?',
    '[0.86,0.11,0.10]'::vector,
    'default'
);
```

The router picks a retrieval profile first. Direct questions stay on `hybrid`; relation-heavy questions can use `multihop_conservative` or `multihop_relation`. Multi-hop profiles first retrieve seed events, then expand through `sag_rag.event_entity`:

```text
seed event -> linked entity -> other linked events
```

That expansion is the SAG-style move: relationship expansion is handled by SQL JOINs, while semantic ranking stays in vector/text scoring and optional application-side rerankers.

See [docs/retrieval-profiles.md](docs/retrieval-profiles.md) for the default strategy profiles:

- `hybrid`
- `multihop_conservative`
- `multihop_relation`

See [docs/query-router.md](docs/query-router.md) for automatic profile selection.

## Positioning

There are already good PostgreSQL-oriented RAG and GraphRAG projects. `pg_sag_rag` is positioned as a small database extension, not a replacement for those frameworks.

| Project Type | Typical Focus | `pg_sag_rag` Focus |
| --- | --- | --- |
| PostgreSQL GraphRAG toolkits | End-to-end graph retrieval libraries, services, CLIs, or API layers | SQL extension primitives: schema, retrieval functions, routing, evaluation |
| Vectorization extensions | Embedding generation, vector indexes, hybrid search pipelines | Event/entity modeling and relation-expanded retrieval on top of vectors/text |
| GraphRAG frameworks | Entity/relation extraction, graph traversal, graph summaries | Event-entity-event expansion using ordinary relational tables and SQL JOINs |
| Agent retrieval systems | Multi-step tool calls and model-driven planning | Deterministic, inspectable database functions with saved evaluation runs |

See [docs/comparison.md](docs/comparison.md) for a more detailed comparison with adjacent open source projects.

## Core API

| API | Use |
| --- | --- |
| `sag_rag.search_events_auto(...)` | Recommended application entry point. Routes then retrieves. |
| `sag_rag.route_query(...)` | Inspect which profile a query will use. |
| `sag_rag.search_events_profile(...)` | Run a named profile directly. |
| `sag_rag.search_events_multihop(...)` | Low-level SQL JOIN expansion retrieval. |
| `sag_rag.run_evaluation_auto(...)` | Evaluate router plus retrieval. |

See [docs/api-reference.md](docs/api-reference.md) for the full SQL surface.

## Schema

- `sag_rag.document`
- `sag_rag.chunk`
- `sag_rag.event`
- `sag_rag.entity`
- `sag_rag.entity_alias`
- `sag_rag.event_entity`
- `sag_rag.retrieval_log`

## Optional Vector Indexes

Embedding dimensions vary by model, so the extension does not hard-code `vector(768)` or `vector(1536)`. After loading data, create HNSW indexes for your dimension:

```sql
SELECT sag_rag.create_hnsw_indexes(1536, 'cosine');
```

For the demo vectors:

```sql
SELECT sag_rag.create_hnsw_indexes(3, 'cosine');
```

## Local Install

```bash
make install
psql -d yourdb -c "CREATE EXTENSION vector; CREATE EXTENSION pg_trgm; CREATE EXTENSION pg_sag_rag;"
```

Local install assumes `pgvector`, `pg_trgm`, PostgreSQL server headers, and `pg_config` are available.

## Evaluation

The extension includes lightweight evaluation tables so you can prove whether SQL JOIN expansion improves retrieval:

```sql
SELECT sag_rag.add_evaluation_set('my-rag-eval');
SELECT sag_rag.add_evaluation_question(1, 'How much is AGI Bar foam?', '[0.86,0.11,0.10]'::vector);
SELECT sag_rag.link_evaluation_answer_event(1, 2);

SELECT sag_rag.run_evaluation_hybrid(1, p_top_k => 1);
SELECT sag_rag.run_evaluation_multihop(1, p_seed_k => 1, p_top_k => 10);
SELECT sag_rag.run_evaluation_auto(1);

SELECT run_id, strategy, parameters
FROM sag_rag.evaluation_run
ORDER BY run_id;

SELECT * FROM sag_rag.recall_at_k(1, 1);
SELECT * FROM sag_rag.recall_at_k(2, 10);
```

The demo seeds an evaluation set and should return `recall = 1.0` for the toy AGI Bar example.

See [docs/benchmark.md](docs/benchmark.md) for the current synthetic benchmark. In that fixture, `multihop@10` keeps recall at 100% and improves MRR from `0.5` to `1.0` compared with `hybrid@10`.

For a real-data small sample, see [docs/hotpotqa.md](docs/hotpotqa.md). On a 20-question HotpotQA dev-distractor bridge sample, the tuned multihop setting improved Recall@10 from 75% to 80% and MRR@10 from `0.4396` to `0.4517`.

For an enterprise-shaped synthetic benchmark, see [docs/enterprise-benchmark.md](docs/enterprise-benchmark.md). It shows a stronger split: relation-focused multihop improves MRR from `0.2833` to `0.7000` on cross-document and noisy relation categories, while direct lookup should stay on hybrid retrieval. With the default SQL router, overall MRR reaches `0.8000` by keeping direct questions on `hybrid` and routing fault/contract relation questions to `multihop_relation`.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for local development and pull request checks.

## License

Apache License 2.0.
