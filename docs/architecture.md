# pg_sag_rag Architecture

`pg_sag_rag` keeps RAG retrieval inside PostgreSQL and leaves model calls outside the database.

The core model is:

```text
document -> chunk -> event -> entity
                     \-> event_entity <-/
```

The retrieval path is:

1. Find seed events with vector and text search.
2. Read entities attached to the seed events.
3. Expand to other events attached to those entities with SQL JOINs.
4. Fuse text, vector, and relation scores.
5. Return auditable events and source chunks to the application.

Applications can call the low-level search functions directly, run named profiles with `sag_rag.search_events_profile`, or use `sag_rag.search_events_auto` to choose a profile through `sag_rag.query_route_rule`.

This is intentionally lighter than a full knowledge graph. The extension does not extract entities or call LLMs. Applications ingest documents, embeddings, events, and entities, then call SQL retrieval functions.

## Why SQL First

The first version is SQL-only because the hard product question is not whether PostgreSQL can load a C library. The hard question is whether event/entity modeling plus SQL JOIN expansion improves multi-hop recall enough to justify the workflow.

C or Rust can be added later for hotspots such as custom scoring, batching, or planner integration.
