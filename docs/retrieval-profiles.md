# Retrieval Profiles

`sag_rag.retrieval_profile` stores named retrieval strategies.

Default profiles:

| Profile | Mode | Use case |
|---|---|---|
| `hybrid` | `hybrid` | Direct semantic/text lookup, FAQ, policy snippets, single-document answers. |
| `multihop_conservative` | `multihop` | Safe default when query type is uncertain. Keeps hybrid-like ranking with light relation expansion. |
| `multihop_relation` | `multihop` | Product + fault code, customer + contract, workflow + exception, or other relation-required questions. |

## Search

```sql
SELECT *
FROM sag_rag.search_events_profile(
    'multihop_relation',
    'What action is required for PX-001 fault code FC-001?',
    '[...]'::vector,
    'enterprise-demo'
);
```

## Evaluation

```sql
SELECT sag_rag.run_evaluation_profile(eval_set_id, 'hybrid');
SELECT sag_rag.run_evaluation_profile(eval_set_id, 'multihop_conservative');
SELECT sag_rag.run_evaluation_profile(eval_set_id, 'multihop_relation');
SELECT * FROM sag_rag.evaluation_summary(eval_set_id);
```

## Routing Guidance

Use profiles as a routing layer:

- direct FAQ/policy lookup -> `hybrid`
- clearly relation-required query -> `multihop_relation`
- uncertain query -> `multihop_conservative`

The enterprise benchmark shows why this matters. Relation-focused expansion can improve cross-document relation workloads, but it can hurt direct semantic lookup.
