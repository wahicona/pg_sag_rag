# Comparison And Positioning

`pg_sag_rag` is not the only PostgreSQL-oriented RAG or GraphRAG project. The project is deliberately scoped as a SQL-only PostgreSQL extension for event-level retrieval, relation expansion, query routing, and database-native evaluation.

## Short Positioning

Use `pg_sag_rag` when you want:

- PostgreSQL extension packaging with `CREATE EXTENSION pg_sag_rag`.
- A lightweight schema for documents, chunks, events, entities, and event-entity links.
- Multi-hop candidate expansion through ordinary SQL JOINs.
- A router that chooses direct hybrid retrieval or relation-expanded retrieval per query.
- Evaluation tables and SQL metrics inside the same database.

Do not use `pg_sag_rag` as a complete ingestion, extraction, API, or Agent framework. It expects the application layer to extract events/entities and generate embeddings.

## Adjacent Projects

| Project | What It Does | Similarity | Difference |
| --- | --- | --- | --- |
| [`yonk-labs/pg-raggraph`](https://github.com/yonk-labs/pg-raggraph) | PostgreSQL-native GraphRAG toolkit combining vector search, full-text search, graph-style traversal, CLI/API/MCP pieces. | Very close in overall motivation: GraphRAG-style retrieval without a separate graph database. | `pg-raggraph` is a broader Python/toolkit stack. `pg_sag_rag` is a small SQL extension with event-level schema, query router, and database-native evaluation. |
| [`h4gen/postgres-graph-rag`](https://github.com/h4gen/postgres-graph-rag) | Python package for GraphRAG on Postgres, including recursive SQL traversal. | Similar goal of doing graph-style retrieval in PostgreSQL. | Focuses on recursive graph traversal from a Python package. `pg_sag_rag` focuses on extension-installable SQL primitives and controlled event-entity expansion profiles. |
| [`neondatabase/pgrag`](https://github.com/neondatabase/pgrag) | Postgres extensions for RAG pipelines, including chunking, embeddings, and reranking. | Shares the idea of pushing RAG functionality into PostgreSQL. | `pgrag` is more about RAG pipeline operations. `pg_sag_rag` does not generate embeddings or call models; it models event/entity retrieval and evaluation. |
| [`ChuckHend/pg_vectorize`](https://github.com/ChuckHend/pg_vectorize) | PostgreSQL extension for vectorization and semantic/hybrid search workflows. | Adjacent to PostgreSQL-native RAG and hybrid retrieval. | `pg_vectorize` focuses on vectorization and search automation. `pg_sag_rag` assumes embeddings exist and adds relation-expanded event retrieval. |
| [`timescale/pgai`](https://github.com/timescale/pgai) | PostgreSQL tools for AI workflows, vectorizers, and retrieval pipelines. | Adjacent PostgreSQL AI/RAG infrastructure. | `pgai` is broader AI infrastructure. `pg_sag_rag` is narrower: event/entity schema, SQL JOIN expansion, routing, and evaluation. |
| [`jimysancho/graphrag-psql`](https://github.com/jimysancho/graphrag-psql) | LightRAG-style GraphRAG storage backed by PostgreSQL. | Stores graph/RAG artifacts in PostgreSQL. | The graph retrieval logic is tied to an external GraphRAG framework. `pg_sag_rag` keeps the retrieval primitive inside SQL functions. |

## Differentiation

### 1. Extension Shape

`pg_sag_rag` is distributed as a PostgreSQL extension. The public surface is SQL:

```sql
CREATE EXTENSION pg_sag_rag;
SELECT * FROM sag_rag.search_events_auto(...);
```

This makes it easier to embed in database product work, test with SQL fixtures, and ship as a small database layer.

### 2. Event-Level Retrieval

Many RAG systems treat chunks as the main retrieval unit. `pg_sag_rag` separates:

```text
document -> chunk -> event -> entity
                     \-> event_entity <-/
```

The event is intended to be a smaller answerable fact. This makes relation expansion less noisy than expanding whole chunks.

### 3. SQL JOIN Relation Expansion

The multi-hop move is intentionally simple:

```text
seed event -> linked entity -> other linked events
```

That expansion happens through `sag_rag.event_entity` using ordinary relational joins. The project does not require a graph database or graph query language.

### 4. Query Routing

The project does not assume every query should use relation expansion. It has named retrieval profiles and regex-based route rules:

- direct lookup -> `hybrid`
- uncertain relation wording -> `multihop_conservative`
- fault/contract/workflow relation queries -> `multihop_relation`

This was added because fixed relation expansion can help cross-document questions while hurting direct lookup.

### 5. Database-Native Evaluation

`pg_sag_rag` includes SQL tables and functions for:

- evaluation sets
- questions
- gold answer events
- retrieval runs
- result ranks
- Recall@K
- MRR@K

The goal is to make retrieval changes measurable inside PostgreSQL, not only in application-side scripts.

## Recommended Public Claim

Use this wording:

```text
pg_sag_rag is a SQL-only PostgreSQL extension for event/entity based multi-hop RAG. It uses pgvector, full-text search, and ordinary SQL JOINs to expand from seed events to related events, then routes each query to the retrieval profile that fits the question type.
```

Avoid these claims:

- "the first PostgreSQL GraphRAG project"
- "the first GraphRAG without a graph database"
- "no similar project exists"
- "a complete GraphRAG framework"

Those claims are too broad and easy to dispute.
