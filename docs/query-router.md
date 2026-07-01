# Query Router

`pg_sag_rag` includes a lightweight SQL query router so direct lookup questions can stay on `hybrid`, while relation-heavy questions can use SQL JOIN expansion.

The router is intentionally simple in the first version:

- Rules live in `sag_rag.query_route_rule`.
- Each rule has a regex `pattern`, `priority`, and target `profile_name`.
- The first matching rule wins by ascending `priority`.
- If no rule matches, `route_query` returns the default profile, usually `hybrid`.

## Default Rules

The extension ships with conservative defaults:

| Rule | Profile | Intended Query Shape |
| --- | --- | --- |
| `fault_code` | `multihop_relation` | fault, alarm, error, code, procedure |
| `contract_exception` | `multihop_relation` | contract, approval, renewal, exception |
| `workflow_process` | `multihop_relation` | workflow, process, handoff, escalation |
| `uncertain_relation` | `multihop_conservative` | related, linked, affected, depends |

## Inspect Routing

```sql
SELECT *
FROM sag_rag.route_query('PX-001 fault code E37 procedure');
```

Expected route:

```text
profile_name       | rule_name
-------------------+-----------
multihop_relation  | fault_code
```

## Auto Retrieval

Use `search_events_auto` when an application wants the database to pick the retrieval profile:

```sql
SELECT profile_name, route_rule, event_text, score, source
FROM sag_rag.search_events_auto(
    'PX-001 fault code E37 procedure',
    '[0.86,0.11,0.10]'::vector,
    'default'
);
```

The result includes `profile_name` and `route_rule` so the application can trace why a strategy was selected.

## Auto Evaluation

Use `run_evaluation_auto` to compare the router against fixed profiles:

```sql
SELECT sag_rag.run_evaluation_profile(1, 'hybrid');
SELECT sag_rag.run_evaluation_profile(1, 'multihop_relation');
SELECT sag_rag.run_evaluation_auto(1);

SELECT *
FROM sag_rag.evaluation_summary(1)
ORDER BY run_id;
```

This is the next step after the enterprise benchmark: relation-focused expansion helps specific classes of enterprise questions, but should not be forced onto every query. Routing lets each question choose the cheaper and more accurate path.
