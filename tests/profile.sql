\set ON_ERROR_STOP on

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
DROP EXTENSION IF EXISTS pg_sag_rag CASCADE;
CREATE EXTENSION pg_sag_rag;

\i /workspace/demo/demo.sql

SELECT profile_name, mode, seed_k, top_k, relation_weight
FROM sag_rag.retrieval_profile
ORDER BY profile_name;

DO $$
DECLARE
    eval_set_id bigint;
    profile_run_id bigint;
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM sag_rag.search_events_profile(
            'multihop_relation',
            'AGI Bar foam price',
            '[0.86,0.11,0.10]'::vector,
            'default'
        )
        WHERE event_text = 'The standard foam cup costs 9.9.'
    ) THEN
        RAISE EXCEPTION 'expected multihop_relation profile to retrieve standard cup price';
    END IF;

    SELECT es.eval_set_id INTO eval_set_id
    FROM sag_rag.evaluation_set es
    WHERE es.name = 'agi-bar-demo';

    profile_run_id := sag_rag.run_evaluation_profile(eval_set_id, 'multihop_relation');

    IF NOT EXISTS (
        SELECT 1
        FROM sag_rag.evaluation_summary(eval_set_id)
        WHERE run_id = profile_run_id
          AND strategy = 'multihop_relation'
          AND recall = 1.0
          AND mrr > 0.0
    ) THEN
        RAISE EXCEPTION 'expected multihop_relation profile evaluation to retrieve a gold answer';
    END IF;
END;
$$;
