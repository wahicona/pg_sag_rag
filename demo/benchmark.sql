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

WITH fixtures AS (
    SELECT *
    FROM (VALUES
        ('AGI Bar menu', 'AGI Bar serves foam drinks. The standard foam cup costs 9.9. The large foam cup costs 9.11.',
         'AGI Bar serves foam drinks.', 'The standard foam cup costs 9.9.', 'The large foam cup costs 9.11.',
         'AGI Bar', 'foam cup', '[0.86,0.11,0.10]'::vector, '[0.91,0.10,0.11]'::vector, '[0.89,0.12,0.10]'::vector,
         'How much is AGI Bar foam?'),
        ('Nova HR handbook', 'NovaCorp employees use Orbit leave. The annual Orbit allowance is 12 days. The carry-over limit is 3 days.',
         'NovaCorp employees use Orbit leave.', 'The annual Orbit allowance is 12 days.', 'The carry-over limit is 3 days.',
         'NovaCorp', 'Orbit leave', '[0.10,0.86,0.10]'::vector, '[0.12,0.91,0.10]'::vector, '[0.11,0.89,0.12]'::vector,
         'What is NovaCorp leave allowance?'),
        ('Helio support guide', 'Helio routers use BlueCare support. The standard BlueCare SLA is 4 hours. The premium BlueCare SLA is 1 hour.',
         'Helio routers use BlueCare support.', 'The standard BlueCare SLA is 4 hours.', 'The premium BlueCare SLA is 1 hour.',
         'Helio routers', 'BlueCare support', '[0.10,0.10,0.86]'::vector, '[0.10,0.12,0.91]'::vector, '[0.12,0.11,0.89]'::vector,
         'What is the Helio router support SLA?'),
        ('Atlas billing guide', 'Atlas Suite uses Mercury billing. The monthly Mercury fee is 29. The annual Mercury discount is 15 percent.',
         'Atlas Suite uses Mercury billing.', 'The monthly Mercury fee is 29.', 'The annual Mercury discount is 15 percent.',
         'Atlas Suite', 'Mercury billing', '[0.60,0.60,0.10]'::vector, '[0.63,0.61,0.11]'::vector, '[0.62,0.59,0.12]'::vector,
         'What does Atlas Suite billing cost?'),
        ('Pioneer training policy', 'Pioneer teams follow Lantern training. The Lantern onboarding course lasts 3 days. The Lantern refresher cadence is 6 months.',
         'Pioneer teams follow Lantern training.', 'The Lantern onboarding course lasts 3 days.', 'The Lantern refresher cadence is 6 months.',
         'Pioneer teams', 'Lantern training', '[0.60,0.10,0.60]'::vector, '[0.62,0.12,0.61]'::vector, '[0.59,0.11,0.63]'::vector,
         'How long is Pioneer onboarding training?')
    ) AS t(title, chunk_text, bridge_event, answer_event_1, answer_event_2, entry_entity, shared_entity, bridge_embedding, answer_embedding_1, answer_embedding_2, query_text)
),
inserted AS (
    SELECT
        row_number() OVER () AS n,
        f.*,
        sag_rag.add_document(f.title, 'default', f.title) AS document_id
    FROM fixtures f
),
chunks AS (
    SELECT
        i.*,
        sag_rag.add_chunk(i.document_id, 1, i.chunk_text, i.bridge_embedding) AS chunk_id
    FROM inserted i
),
events AS (
    SELECT
        c.*,
        sag_rag.add_event(c.document_id, c.bridge_event, c.chunk_id, c.bridge_embedding) AS bridge_event_id,
        sag_rag.add_event(c.document_id, c.answer_event_1, c.chunk_id, c.answer_embedding_1) AS answer_event_id_1,
        sag_rag.add_event(c.document_id, c.answer_event_2, c.chunk_id, c.answer_embedding_2) AS answer_event_id_2
    FROM chunks c
),
entities AS (
    SELECT
        e.*,
        sag_rag.upsert_entity(e.entry_entity, 'entry') AS entry_entity_id,
        sag_rag.upsert_entity(e.shared_entity, 'topic') AS shared_entity_id
    FROM events e
),
links AS (
    SELECT
        sag_rag.link_event_entity(bridge_event_id, entry_entity_id, 'entry'),
        sag_rag.link_event_entity(bridge_event_id, shared_entity_id, 'topic'),
        sag_rag.link_event_entity(answer_event_id_1, shared_entity_id, 'topic'),
        sag_rag.link_event_entity(answer_event_id_2, shared_entity_id, 'topic')
    FROM entities
),
eval_set AS (
    SELECT sag_rag.add_evaluation_set(
        'synthetic-multihop-v1',
        'default',
        'Synthetic benchmark where answers are reachable through shared entities.'
    ) AS eval_set_id
),
questions AS (
    SELECT
        es.eval_set_id,
        e.answer_event_id_1,
        e.answer_event_id_2,
        sag_rag.add_evaluation_question(es.eval_set_id, e.query_text, e.bridge_embedding) AS question_id
    FROM entities e
    CROSS JOIN eval_set es
)
SELECT
    sag_rag.link_evaluation_answer_event(question_id, answer_event_id_1, 1),
    sag_rag.link_evaluation_answer_event(question_id, answer_event_id_2, 1)
FROM questions
CROSS JOIN (SELECT count(*) FROM links) link_guard;

WITH eval AS (
    SELECT eval_set_id
    FROM sag_rag.evaluation_set
    WHERE name = 'synthetic-multihop-v1'
)
SELECT sag_rag.run_evaluation_hybrid(eval_set_id, 1) AS hybrid_at_1_run
FROM eval;

WITH eval AS (
    SELECT eval_set_id
    FROM sag_rag.evaluation_set
    WHERE name = 'synthetic-multihop-v1'
)
SELECT sag_rag.run_evaluation_hybrid(eval_set_id, 10) AS hybrid_at_10_run
FROM eval;

WITH eval AS (
    SELECT eval_set_id
    FROM sag_rag.evaluation_set
    WHERE name = 'synthetic-multihop-v1'
)
SELECT sag_rag.run_evaluation_multihop(eval_set_id, 1, 10, 25) AS multihop_at_10_run
FROM eval;

SELECT
    strategy,
    k,
    questions,
    hits,
    round((recall * 100)::numeric, 2) AS recall_percent,
    answered,
    round(mrr::numeric, 4) AS mrr,
    round(avg_first_gold_rank::numeric, 2) AS avg_first_gold_rank
FROM sag_rag.evaluation_summary(
    (SELECT eval_set_id FROM sag_rag.evaluation_set WHERE name = 'synthetic-multihop-v1')
);

SELECT
    er.strategy,
    q.question_id,
    q.query_text,
    r.rank,
    r.event_id,
    e.event_text,
    r.hop,
    r.source,
    round(r.score::numeric, 6) AS score,
    answer.event_id IS NOT NULL AS is_gold
FROM sag_rag.evaluation_run er
JOIN sag_rag.evaluation_result r ON r.run_id = er.run_id
JOIN sag_rag.evaluation_question q ON q.question_id = r.question_id
JOIN sag_rag.event e ON e.event_id = r.event_id
LEFT JOIN sag_rag.evaluation_answer_event answer
  ON answer.question_id = r.question_id
 AND answer.event_id = r.event_id
 AND answer.relevance > 0
ORDER BY er.run_id, q.question_id, r.rank;
