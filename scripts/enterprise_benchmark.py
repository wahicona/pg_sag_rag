#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


DEFAULT_OUT = Path("demo/enterprise_benchmark.sql")


def sql_quote(value):
    return "'" + str(value).replace("'", "''") + "'"


def sql_json(value):
    return sql_quote(json.dumps(value, ensure_ascii=True, sort_keys=True)) + "::jsonb"


def vec(values):
    return "[" + ",".join(f"{v:.4f}" for v in values) + "]"


def base_vec(index, dims=8):
    values = [0.0] * dims
    values[index % dims] = 1.0
    return values


def blend(a, b, weight=0.85):
    return [(weight * x) + ((1.0 - weight) * y) for x, y in zip(a, b)]


def add_case(lines, case_id, category, tenant, product, topic, question, bridge_event, answer_event, answer_entity, distractors):
    qv = base_vec(case_id)
    if category == "direct":
        bridge_v = blend(qv, base_vec(case_id + 3), 0.62)
        answer_v = blend(qv, base_vec(case_id + 5), 0.97)
    else:
        bridge_v = blend(qv, base_vec(case_id + 3), 0.97)
        answer_v = blend(qv, base_vec(case_id + 5), 0.70)

    lines.extend(
        [
            f"-- {category}: {case_id}",
            "DO $$",
            "DECLARE",
            "    eval_set_id bigint;",
            "    question_id bigint;",
            "    document_id bigint;",
            "    chunk_id bigint;",
            "    bridge_event_id bigint;",
            "    answer_event_id bigint;",
            "    product_entity_id bigint;",
            "    topic_entity_id bigint;",
            "    answer_entity_id bigint;",
            "BEGIN",
            "    SELECT es.eval_set_id INTO eval_set_id",
            "    FROM sag_rag.evaluation_set es",
            "    WHERE es.name = 'enterprise-synthetic-v1';",
            "",
            "    question_id := sag_rag.add_evaluation_question(",
            "        eval_set_id,",
            f"        {sql_quote(question)},",
            f"        {sql_quote(vec(qv))}::vector,",
            f"        {sql_json({'case_id': case_id, 'category': category, 'product': product, 'topic': topic})}",
            "    );",
            "",
            "    document_id := sag_rag.add_document(",
            f"        {sql_quote(product + ' overview')},",
            f"        {sql_quote(tenant)},",
            f"        {sql_quote('overview-' + str(case_id))},",
            "        NULL,",
            f"        {sql_json({'category': category, 'doc_type': 'overview'})}",
            "    );",
            "    chunk_id := sag_rag.add_chunk(",
            "        document_id, 1,",
            f"        {sql_quote(bridge_event)},",
            f"        {sql_quote(vec(bridge_v))}::vector,",
            f"        {sql_json({'category': category})}",
            "    );",
            "    bridge_event_id := sag_rag.add_event(",
            "        document_id,",
            f"        {sql_quote(bridge_event)},",
            "        chunk_id,",
            f"        {sql_quote(vec(bridge_v))}::vector,",
            "        1.0,",
            f"        {sql_json({'category': category, 'role': 'bridge'})}",
            "    );",
            "",
            "    document_id := sag_rag.add_document(",
            f"        {sql_quote(topic + ' procedure')},",
            f"        {sql_quote(tenant)},",
            f"        {sql_quote('procedure-' + str(case_id))},",
            "        NULL,",
            f"        {sql_json({'category': category, 'doc_type': 'procedure'})}",
            "    );",
            "    chunk_id := sag_rag.add_chunk(",
            "        document_id, 1,",
            f"        {sql_quote(answer_event)},",
            f"        {sql_quote(vec(answer_v))}::vector,",
            f"        {sql_json({'category': category})}",
            "    );",
            "    answer_event_id := sag_rag.add_event(",
            "        document_id,",
            f"        {sql_quote(answer_event)},",
            "        chunk_id,",
            f"        {sql_quote(vec(answer_v))}::vector,",
            "        1.0,",
            f"        {sql_json({'category': category, 'role': 'answer'})}",
            "    );",
            "",
            f"    product_entity_id := sag_rag.upsert_entity({sql_quote(product)}, 'product', {sql_quote(tenant)});",
            f"    topic_entity_id := sag_rag.upsert_entity({sql_quote(topic)}, 'topic', {sql_quote(tenant)});",
            f"    answer_entity_id := sag_rag.upsert_entity({sql_quote(answer_entity)}, 'answer_key', {sql_quote(tenant)});",
            "    PERFORM sag_rag.link_event_entity(bridge_event_id, product_entity_id, 'product');",
            "    PERFORM sag_rag.link_event_entity(bridge_event_id, topic_entity_id, 'topic');",
            "    PERFORM sag_rag.link_event_entity(answer_event_id, topic_entity_id, 'topic');",
            "    PERFORM sag_rag.link_event_entity(answer_event_id, answer_entity_id, 'answer_key');",
            "    PERFORM sag_rag.link_evaluation_answer_event(question_id, answer_event_id, 1);",
        ]
    )

    for d_index, distractor in enumerate(distractors, start=1):
        dv = blend(qv, base_vec(case_id + d_index + 1), 0.72)
        lines.extend(
            [
                "",
                "    document_id := sag_rag.add_document(",
                f"        {sql_quote(product + ' related note ' + str(d_index))},",
                f"        {sql_quote(tenant)},",
                f"        {sql_quote('distractor-' + str(case_id) + '-' + str(d_index))},",
                "        NULL,",
                f"        {sql_json({'category': category, 'doc_type': 'distractor'})}",
                "    );",
                "    chunk_id := sag_rag.add_chunk(",
                "        document_id, 1,",
                f"        {sql_quote(distractor)},",
                f"        {sql_quote(vec(dv))}::vector,",
                f"        {sql_json({'category': category})}",
                "    );",
                "    PERFORM sag_rag.add_event(",
                "        document_id,",
                f"        {sql_quote(distractor)},",
                "        chunk_id,",
                f"        {sql_quote(vec(dv))}::vector,",
                "        1.0,",
                f"        {sql_json({'category': category, 'role': 'distractor'})}",
                "    );",
            ]
        )

    lines.extend(["END $$;", ""])


def build_sql(cases_per_category):
    lines = [
        "CREATE EXTENSION IF NOT EXISTS vector;",
        "CREATE EXTENSION IF NOT EXISTS pg_trgm;",
        "CREATE EXTENSION IF NOT EXISTS pg_sag_rag;",
        "",
        "TRUNCATE",
        "    sag_rag.evaluation_result,",
        "    sag_rag.evaluation_run,",
        "    sag_rag.evaluation_answer_event,",
        "    sag_rag.evaluation_question,",
        "    sag_rag.evaluation_set,",
        "    sag_rag.retrieval_log,",
        "    sag_rag.event_entity,",
        "    sag_rag.entity_alias,",
        "    sag_rag.entity,",
        "    sag_rag.event,",
        "    sag_rag.chunk,",
        "    sag_rag.document",
        "RESTART IDENTITY CASCADE;",
        "",
        "SELECT sag_rag.add_evaluation_set(",
        "    'enterprise-synthetic-v1',",
        "    'enterprise-demo',",
        "    'Enterprise-style benchmark with direct, cross-document, and noisy relation-required questions.',",
        f"    {sql_json({'cases_per_category': cases_per_category})}",
        ") AS eval_set_id;",
        "",
    ]

    case_id = 1
    categories = [
        ("direct", "PX", "SLA", "standard response time"),
        ("cross_document", "RX", "fault code", "repair action"),
        ("noisy_relation", "CX", "contract exception", "approval route"),
    ]

    for category, product_prefix, topic_prefix, answer_prefix in categories:
        for i in range(1, cases_per_category + 1):
            product = f"{product_prefix}-{i:03d}"
            topic = f"{topic_prefix}-{i:03d}"
            answer_entity = f"{answer_prefix}-{i:03d}"
            tenant = "enterprise-demo"
            if category == "direct":
                bridge = f"{product} has {topic}; the answer is in the same policy pack."
                answer = f"{product} {topic} requires {answer_entity} according to the current service handbook."
            elif category == "cross_document":
                bridge = f"{product} reports {topic} in field diagnostics; the remediation is maintained in the procedure library."
                answer = f"When {topic} is confirmed, apply {answer_entity} and record the maintenance ticket."
            else:
                bridge = f"{product} is associated with {topic}; several departments reference the same exception code."
                answer = f"For {topic}, route the request through {answer_entity} before customer notification."

            question = f"What is the required action for {product} {topic}?"
            distractors = [
                f"{product} {topic} historical note mentions a retired process and should not be used.",
                f"{product} adjacent workflow has a similar label but uses a different approval path.",
                f"General enterprise policy references {topic} only for reporting, not for resolution.",
            ]
            add_case(lines, case_id, category, tenant, product, topic, question, bridge, answer, answer_entity, distractors)
            case_id += 1

    lines.extend(
        [
            "WITH eval AS (SELECT eval_set_id FROM sag_rag.evaluation_set WHERE name = 'enterprise-synthetic-v1')",
            "SELECT sag_rag.run_evaluation_profile(eval_set_id, 'hybrid') AS hybrid_profile_run FROM eval;",
            "",
            "WITH eval AS (SELECT eval_set_id FROM sag_rag.evaluation_set WHERE name = 'enterprise-synthetic-v1')",
            "SELECT sag_rag.run_evaluation_profile(eval_set_id, 'multihop_conservative') AS multihop_conservative_profile_run FROM eval;",
            "",
            "WITH eval AS (SELECT eval_set_id FROM sag_rag.evaluation_set WHERE name = 'enterprise-synthetic-v1')",
            "SELECT sag_rag.run_evaluation_profile(eval_set_id, 'multihop_relation') AS multihop_relation_profile_run FROM eval;",
            "",
            "WITH eval AS (SELECT eval_set_id FROM sag_rag.evaluation_set WHERE name = 'enterprise-synthetic-v1')",
            "SELECT sag_rag.run_evaluation_auto(eval_set_id) AS auto_profile_run FROM eval;",
            "",
            "SELECT",
            "    strategy,",
            "    k,",
            "    questions,",
            "    hits,",
            "    round((recall * 100)::numeric, 2) AS recall_percent,",
            "    answered,",
            "    round(mrr::numeric, 4) AS mrr,",
            "    round(avg_first_gold_rank::numeric, 2) AS avg_first_gold_rank",
            "FROM sag_rag.evaluation_summary(",
            "    (SELECT eval_set_id FROM sag_rag.evaluation_set WHERE name = 'enterprise-synthetic-v1')",
            ");",
            "",
            "WITH summary AS (",
            "    SELECT",
            "        er.run_id,",
            "        er.strategy,",
            "        er.parameters,",
            "        coalesce((er.parameters ->> 'top_k')::integer, 10) AS k,",
            "        q.metadata ->> 'category' AS category,",
            "        q.question_id,",
            "        min(r.rank) FILTER (WHERE answer.event_id IS NOT NULL) AS first_gold_rank",
            "    FROM sag_rag.evaluation_run er",
            "    JOIN sag_rag.evaluation_question q ON q.eval_set_id = er.eval_set_id",
            "    LEFT JOIN sag_rag.evaluation_result r ON r.run_id = er.run_id AND r.question_id = q.question_id",
            "    LEFT JOIN sag_rag.evaluation_answer_event answer",
            "      ON answer.question_id = r.question_id",
            "     AND answer.event_id = r.event_id",
            "     AND answer.relevance > 0",
            "    WHERE er.eval_set_id = (SELECT eval_set_id FROM sag_rag.evaluation_set WHERE name = 'enterprise-synthetic-v1')",
            "      AND r.rank <= coalesce((er.parameters ->> 'top_k')::integer, 10)",
            "    GROUP BY er.run_id, er.strategy, er.parameters, q.metadata ->> 'category', q.question_id",
            ")",
            "SELECT",
            "    run_id,",
            "    strategy,",
            "    k,",
            "    parameters,",
            "    category,",
            "    count(*) AS questions,",
            "    count(first_gold_rank) AS hits,",
            "    round((count(first_gold_rank)::double precision / count(*)::double precision * 100)::numeric, 2) AS recall_percent,",
            "    round(avg(coalesce(1.0 / first_gold_rank, 0.0))::numeric, 4) AS mrr,",
            "    round(avg(first_gold_rank)::numeric, 2) AS avg_first_gold_rank",
            "FROM summary",
            "GROUP BY run_id, strategy, k, parameters, category",
            "ORDER BY category, run_id;",
        ]
    )
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--cases-per-category", type=int, default=20)
    args = parser.parse_args()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(build_sql(args.cases_per_category), encoding="utf-8")
    print(f"Wrote enterprise benchmark SQL to {args.out}")


if __name__ == "__main__":
    main()
