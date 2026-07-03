# API Reference

This is the public SQL surface for `v0.1.0`.

## Core Tables

| Table | Purpose |
| --- | --- |
| `sag_rag.document` | Tenant-scoped source document metadata. |
| `sag_rag.chunk` | Document chunks with optional embeddings. |
| `sag_rag.event` | Atomic answerable statements extracted from chunks. |
| `sag_rag.entity` | Canonical entities used for SQL JOIN expansion. |
| `sag_rag.entity_alias` | Alternate names for entities. |
| `sag_rag.event_entity` | Event-to-entity links with roles and confidence. |
| `sag_rag.retrieval_profile` | Named retrieval parameter presets. |
| `sag_rag.query_route_rule` | Regex rules that select retrieval profiles per query. |
| `sag_rag.retrieval_log` | Optional application retrieval traces. |

## Ingestion Helpers

| Function | Purpose |
| --- | --- |
| `sag_rag.add_document(...)` | Insert or update a document. |
| `sag_rag.add_chunk(...)` | Insert or update a chunk. |
| `sag_rag.add_event(...)` | Insert an event. |
| `sag_rag.upsert_entity(...)` | Insert or update a tenant-scoped entity. |
| `sag_rag.add_entity_alias(...)` | Add an alias for an entity. |
| `sag_rag.link_event_entity(...)` | Link an event to an entity. |

## Retrieval

| Function | Purpose |
| --- | --- |
| `sag_rag.search_events_hybrid(...)` | Direct text/vector/trigram retrieval. |
| `sag_rag.search_events_multihop(...)` | Seed retrieval plus one-hop SQL JOIN expansion. |
| `sag_rag.search_events_profile(...)` | Run a named profile from `retrieval_profile`. |
| `sag_rag.route_query(...)` | Pick a profile by matching `query_route_rule`. |
| `sag_rag.search_events_auto(...)` | Route and search in one call. |
| `sag_rag.explain_event_trace(...)` | Show event, entity, document, and chunk evidence. |
| `sag_rag.log_retrieval(...)` | Store application retrieval metadata and result summaries. |

## Evaluation

| Function | Purpose |
| --- | --- |
| `sag_rag.add_evaluation_set(...)` | Create or update an evaluation set. |
| `sag_rag.add_evaluation_question(...)` | Add an evaluation query. |
| `sag_rag.link_evaluation_answer_event(...)` | Mark a gold event for a query. |
| `sag_rag.run_evaluation_hybrid(...)` | Evaluate direct hybrid retrieval. |
| `sag_rag.run_evaluation_multihop(...)` | Evaluate parameterized multihop retrieval. |
| `sag_rag.run_evaluation_profile(...)` | Evaluate a named profile. |
| `sag_rag.run_evaluation_auto(...)` | Evaluate query routing plus retrieval. |
| `sag_rag.recall_at_k(...)` | Compute Recall@K for a run. |
| `sag_rag.mrr_at_k(...)` | Compute MRR@K for a run. |
| `sag_rag.evaluation_summary(...)` | Return recall and MRR summary rows. |

## Index Helper

| Function | Purpose |
| --- | --- |
| `sag_rag.create_hnsw_indexes(dimensions, distance)` | Create HNSW indexes for `chunk.embedding` and `event.embedding`. |

## Compatibility Notes

- Supports PostgreSQL 14+ with `pgvector` and `pg_trgm`.
- The `v0.1.0` compatibility matrix has been tested on PostgreSQL 14.23, 15.18, 16.14, and 17.10 with `pgvector` 0.8.4 and `pg_trgm` 1.6.
- `embedding` columns are declared as unconstrained `vector` so users can choose their model dimension.
- `v0.1.0` is SQL-only and does not call LLM or embedding APIs.
- Public APIs may still change before `1.0`; changes should be documented in `CHANGELOG.md`.
