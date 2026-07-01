CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pg_sag_rag;

TRUNCATE
    sag_rag.evaluation_result,
    sag_rag.evaluation_run,
    sag_rag.evaluation_answer_event,
    sag_rag.evaluation_question,
    sag_rag.evaluation_set,
    sag_rag.retrieval_log,
    sag_rag.event_entity,
    sag_rag.entity_alias,
    sag_rag.entity,
    sag_rag.event,
    sag_rag.chunk,
    sag_rag.document
RESTART IDENTITY CASCADE;

WITH doc AS (
    SELECT sag_rag.add_document(
        p_title => 'AGI Bar menu',
        p_external_id => 'agi-bar-menu',
        p_uri => 'https://example.local/agi-bar/menu'
    ) AS document_id
),
chunk AS (
    SELECT sag_rag.add_chunk(
        p_document_id => document_id,
        p_chunk_index => 1,
        p_content => 'AGI Bar serves foam drinks. The standard foam cup costs 9.9. The large foam cup costs 9.11.',
        p_embedding => '[0.86,0.11,0.10]'::vector
    ) AS chunk_id, document_id
    FROM doc
),
events AS (
    SELECT
        document_id,
        chunk_id,
        sag_rag.add_event(document_id, 'AGI Bar serves foam drinks.', chunk_id, '[0.86,0.11,0.10]'::vector) AS e1,
        sag_rag.add_event(document_id, 'The standard foam cup costs 9.9.', chunk_id, '[0.91,0.10,0.11]'::vector) AS e2,
        sag_rag.add_event(document_id, 'The large foam cup costs 9.11.', chunk_id, '[0.89,0.12,0.10]'::vector) AS e3
    FROM chunk
),
entities AS (
    SELECT
        sag_rag.upsert_entity('AGI Bar', 'store') AS agi_bar,
        sag_rag.upsert_entity('foam cup', 'product') AS foam_cup,
        sag_rag.upsert_entity('standard cup', 'size') AS standard_cup,
        sag_rag.upsert_entity('large cup', 'size') AS large_cup
)
SELECT
    sag_rag.link_event_entity(e1, agi_bar, 'store'),
    sag_rag.link_event_entity(e1, foam_cup, 'product'),
    sag_rag.link_event_entity(e2, foam_cup, 'product'),
    sag_rag.link_event_entity(e2, standard_cup, 'size'),
    sag_rag.link_event_entity(e3, foam_cup, 'product'),
    sag_rag.link_event_entity(e3, large_cup, 'size')
FROM events, entities;

SELECT *
FROM sag_rag.search_events_multihop(
    p_query_text => 'How much is AGI Bar foam?',
    p_query_embedding => '[0.86,0.11,0.10]'::vector,
    p_seed_k => 1,
    p_top_k => 10
);

WITH eval AS (
    SELECT sag_rag.add_evaluation_set(
        p_name => 'agi-bar-demo',
        p_description => 'Demo question that requires expanding from AGI Bar to foam cup price events.'
    ) AS eval_set_id
),
question AS (
    SELECT sag_rag.add_evaluation_question(
        p_eval_set_id => eval_set_id,
        p_query_text => 'How much is AGI Bar foam?',
        p_query_embedding => '[0.86,0.11,0.10]'::vector
    ) AS question_id
    FROM eval
),
answers AS (
    SELECT e.event_id, q.question_id
    FROM question q
    CROSS JOIN sag_rag.event e
    WHERE e.event_text IN (
        'The standard foam cup costs 9.9.',
        'The large foam cup costs 9.11.'
    )
)
SELECT sag_rag.link_evaluation_answer_event(question_id, event_id, 1)
FROM answers;

WITH eval AS (
    SELECT eval_set_id
    FROM sag_rag.evaluation_set
    WHERE name = 'agi-bar-demo'
)
SELECT sag_rag.run_evaluation_hybrid(eval_set_id, 1) AS hybrid_run_id
FROM eval;

WITH eval AS (
    SELECT eval_set_id
    FROM sag_rag.evaluation_set
    WHERE name = 'agi-bar-demo'
)
SELECT sag_rag.run_evaluation_multihop(eval_set_id, 1, 10, 25) AS multihop_run_id
FROM eval;

SELECT er.strategy, metrics.*
FROM sag_rag.evaluation_run er
CROSS JOIN LATERAL sag_rag.recall_at_k(
    er.run_id,
    CASE WHEN er.strategy = 'hybrid' THEN 1 ELSE 10 END
) AS metrics;
