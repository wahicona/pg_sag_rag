# Roadmap

## 0.1

- SQL extension with standard RAG/SAG schema.
- Hybrid event search over text and vectors.
- One-hop SQL JOIN expansion through shared entities.
- Retrieval trace helpers.
- Built-in evaluation tables and `recall_at_k`.
- Built-in `mrr_at_k` and `evaluation_summary`.
- Retrieval profiles and SQL query routing.
- Docker demo and CI smoke test.
- Synthetic benchmark for bridge-event to answer-event retrieval.
- Enterprise-shaped benchmark for direct, cross-document, and noisy relation workloads.

## 0.2

- More scoring strategies, including RRF and MMR.
- ACL tables and examples for tenant/user/group filtering.
- Import helpers for external chunk/event/entity extraction pipelines.
- pgTAP or SQL assertion test suite.
- Expand the HotpotQA adapter beyond 20 samples and add 2WikiMultiHop.

## 0.3

- Batch retrieval APIs for Agent workloads.
- Better candidate control to limit join expansion fanout.
- Optional Rust/C scoring functions if SQL hotspots are proven by benchmarks.
- Planner and index documentation for large datasets.

## Later

- Partitioning recipes for large event tables.
- CloudNativePG and Kubernetes examples.
- Compatibility tests across PostgreSQL versions.
- Optional background workers only if asynchronous maintenance becomes necessary.
