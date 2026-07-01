\set ON_ERROR_STOP on

DROP EXTENSION IF EXISTS pg_sag_rag CASCADE;
CREATE EXTENSION pg_sag_rag;

\i /workspace/demo/benchmark.sql

DO $$
DECLARE
    hybrid_at_1 record;
    hybrid_at_10 record;
    multihop_at_10 record;
BEGIN
    SELECT * INTO hybrid_at_1
    FROM sag_rag.evaluation_summary((
        SELECT eval_set_id
        FROM sag_rag.evaluation_set
        WHERE name = 'synthetic-multihop-v1'
    ))
    WHERE strategy = 'hybrid'
      AND parameters ->> 'top_k' = '1';

    SELECT * INTO hybrid_at_10
    FROM sag_rag.evaluation_summary((
        SELECT eval_set_id
        FROM sag_rag.evaluation_set
        WHERE name = 'synthetic-multihop-v1'
    ))
    WHERE strategy = 'hybrid'
      AND parameters ->> 'top_k' = '10';

    SELECT * INTO multihop_at_10
    FROM sag_rag.evaluation_summary((
        SELECT eval_set_id
        FROM sag_rag.evaluation_set
        WHERE name = 'synthetic-multihop-v1'
    ))
    WHERE strategy = 'multihop'
      AND parameters ->> 'top_k' = '10';

    IF hybrid_at_1.recall <> 0.0 THEN
        RAISE EXCEPTION 'expected hybrid@1 recall to be 0.0, got %', hybrid_at_1.recall;
    END IF;

    IF hybrid_at_10.recall <> 1.0 THEN
        RAISE EXCEPTION 'expected hybrid@10 recall to be 1.0, got %', hybrid_at_10.recall;
    END IF;

    IF multihop_at_10.recall <> 1.0 THEN
        RAISE EXCEPTION 'expected multihop@10 recall to be 1.0, got %', multihop_at_10.recall;
    END IF;

    IF multihop_at_10.mrr <= hybrid_at_10.mrr THEN
        RAISE EXCEPTION 'expected multihop@10 MRR (%) to beat hybrid@10 MRR (%)',
            multihop_at_10.mrr,
            hybrid_at_10.mrr;
    END IF;

    IF multihop_at_10.avg_first_gold_rank <> 1.0 THEN
        RAISE EXCEPTION 'expected multihop avg first gold rank to be 1.0, got %',
            multihop_at_10.avg_first_gold_rank;
    END IF;
END;
$$;
