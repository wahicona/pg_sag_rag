# Changelog

## 0.1.0

Initial MVP.

- Added PostgreSQL extension metadata and SQL install script.
- Added `sag_rag` schema for documents, chunks, events, entities, event links, retrieval logs, and evaluations.
- Added hybrid event retrieval over full-text, trigram, and vector similarity.
- Added SQL JOIN based one-hop event expansion through shared entities.
- Added trace helper for explaining event/entity/document evidence.
- Added lightweight evaluation runner for hybrid and multihop retrieval.
- Added `recall_at_k`, `mrr_at_k`, and `evaluation_summary` metrics.
- Added Docker demo, smoke test, synthetic benchmark test, GitHub Actions CI, architecture notes, and roadmap.
- Added HotpotQA small-sample benchmark generator with reproducible hashing vectors.
- Added tunable multihop evaluation weights for text, vector, and relation scoring.
- Added enterprise-style benchmark generator covering direct, cross-document, and noisy relation workloads.
- Added retrieval profiles with `search_events_profile` and `run_evaluation_profile`.
- Added query routing with `query_route_rule`, `route_query`, `search_events_auto`, and `run_evaluation_auto`.
- Added router regression test, API reference, contribution guide, security notes, and GitHub issue/PR templates.
