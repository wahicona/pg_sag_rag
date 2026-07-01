\set ON_ERROR_STOP on

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
DROP EXTENSION IF EXISTS pg_sag_rag CASCADE;
CREATE EXTENSION pg_sag_rag;

\i /workspace/demo/demo.sql

SELECT count(*) > 0 AS has_documents FROM sag_rag.document;
SELECT count(*) > 0 AS has_events FROM sag_rag.event;
SELECT count(*) > 0 AS has_entities FROM sag_rag.entity;

SELECT event_text, hop, source
FROM sag_rag.search_events_multihop(
    'AGI Bar foam price',
    '[0.86,0.11,0.10]'::vector,
    'default',
    1,
    10
)
ORDER BY score DESC, event_id;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM sag_rag.search_events_multihop(
            'AGI Bar foam price',
            '[0.86,0.11,0.10]'::vector,
            'default',
            1,
            10
        )
        WHERE event_text = 'The standard foam cup costs 9.9.'
          AND hop = 1
    ) THEN
        RAISE EXCEPTION 'expected SQL JOIN expansion to retrieve the standard cup price';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM sag_rag.search_events_multihop(
            'AGI Bar foam price',
            '[0.86,0.11,0.10]'::vector,
            'default',
            1,
            10
        )
        WHERE event_text = 'The large foam cup costs 9.11.'
          AND hop = 1
    ) THEN
        RAISE EXCEPTION 'expected SQL JOIN expansion to retrieve the large cup price';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM sag_rag.recall_at_k(
            (SELECT max(run_id) FROM sag_rag.evaluation_run),
            10
        )
        WHERE recall = 1.0
    ) THEN
        RAISE EXCEPTION 'expected demo evaluation recall@10 to be 1.0';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM sag_rag.mrr_at_k(
            (SELECT max(run_id) FROM sag_rag.evaluation_run),
            10
        )
        WHERE mrr = 1.0
          AND avg_first_gold_rank = 1.0
    ) THEN
        RAISE EXCEPTION 'expected demo evaluation MRR@10 to be 1.0';
    END IF;
END;
$$;
