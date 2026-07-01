\set ON_ERROR_STOP on

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
DROP EXTENSION IF EXISTS pg_sag_rag CASCADE;
CREATE EXTENSION pg_sag_rag;

\i /workspace/demo/demo.sql

SELECT *
FROM sag_rag.route_query('What is AGI Bar foam price?');

SELECT *
FROM sag_rag.route_query('PX-001 fault code E37 procedure');

SELECT *
FROM sag_rag.route_query('Which policy is related to AGI Bar foam?');

DO $$
DECLARE
    eval_set_id bigint;
    auto_run_id bigint;
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM sag_rag.route_query('What is AGI Bar foam price?')
        WHERE profile_name = 'hybrid'
          AND rule_name = 'default'
    ) THEN
        RAISE EXCEPTION 'expected unmatched query to use default hybrid route';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM sag_rag.route_query('PX-001 fault code E37 procedure')
        WHERE profile_name = 'multihop_relation'
          AND rule_name = 'fault_code'
    ) THEN
        RAISE EXCEPTION 'expected fault-code query to use relation-focused route';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM sag_rag.route_query('Which policy is related to AGI Bar foam?')
        WHERE profile_name = 'multihop_conservative'
          AND rule_name = 'uncertain_relation'
    ) THEN
        RAISE EXCEPTION 'expected relation wording to use conservative route';
    END IF;

    INSERT INTO sag_rag.query_route_rule (
        rule_name,
        profile_name,
        pattern,
        priority,
        description
    ) VALUES (
        'test_foam_relation',
        'multihop_relation',
        '(^|[^a-z0-9])foam([^a-z0-9]|$)',
        1,
        'Test-only rule to force demo foam questions through relation expansion.'
    );

    IF NOT EXISTS (
        SELECT 1
        FROM sag_rag.search_events_auto(
            'How much is AGI Bar foam?',
            '[0.86,0.11,0.10]'::vector,
            'default'
        )
        WHERE profile_name = 'multihop_relation'
          AND route_rule = 'test_foam_relation'
          AND event_text = 'The standard foam cup costs 9.9.'
    ) THEN
        RAISE EXCEPTION 'expected auto retrieval to route foam query through multihop_relation';
    END IF;

    SELECT es.eval_set_id INTO eval_set_id
    FROM sag_rag.evaluation_set es
    WHERE es.name = 'agi-bar-demo';

    auto_run_id := sag_rag.run_evaluation_auto(eval_set_id);

    IF NOT EXISTS (
        SELECT 1
        FROM sag_rag.evaluation_summary(eval_set_id)
        WHERE run_id = auto_run_id
          AND strategy = 'auto'
          AND recall = 1.0
          AND mrr > 0.0
    ) THEN
        RAISE EXCEPTION 'expected auto evaluation to retrieve a gold answer';
    END IF;
END;
$$;
