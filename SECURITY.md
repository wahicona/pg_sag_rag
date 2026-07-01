# Security Policy

## Supported Versions

`pg_sag_rag` is pre-1.0. Security fixes target the latest released `0.x` version.

## Reporting a Vulnerability

Please do not open a public issue for a vulnerability.

Report privately by contacting the maintainer through the repository owner's preferred security contact. Include:

- affected version or commit
- PostgreSQL version
- reproduction steps
- expected and actual behavior
- whether tenant isolation, permissions, or data exposure is involved

## Current Security Scope

The extension stores and retrieves application-provided RAG data. It does not call model APIs, execute user-provided code, or manage application authentication.

Production users should still review:

- tenant filtering on every application query
- row-level security and grants around the `sag_rag` schema
- whether embeddings or event text contain sensitive data
- extension installation privileges
- benchmark/demo data before deploying to shared databases
