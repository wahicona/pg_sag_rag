#!/usr/bin/env python3
import argparse
import hashlib
import json
import math
import re
import subprocess
import sys
import urllib.request
from pathlib import Path


DATA_URLS = [
    "http://curtis.ml.cmu.edu/datasets/hotpot/hotpot_dev_distractor_v1.json",
    "https://huggingface.co/datasets/namlh2004/hotpotqa/resolve/main/hotpot_dev_distractor_v1.json",
]
DEFAULT_DATA = Path("data/hotpot_dev_distractor_v1.json")
DEFAULT_SQL = Path("demo/hotpotqa_sample.sql")


WORD_RE = re.compile(r"[A-Za-z0-9]+")


def sql_quote(value):
    if value is None:
        return "NULL"
    return "'" + str(value).replace("'", "''") + "'"


def sql_json(value):
    return sql_quote(json.dumps(value, ensure_ascii=True, sort_keys=True)) + "::jsonb"


def tokenize(text):
    return [m.group(0).lower() for m in WORD_RE.finditer(text or "")]


def vectorize(text, dims):
    values = [0.0] * dims
    for token in tokenize(text):
        digest = hashlib.blake2b(token.encode("utf-8"), digest_size=8).digest()
        bucket = int.from_bytes(digest[:4], "little") % dims
        sign = 1.0 if digest[4] % 2 == 0 else -1.0
        values[bucket] += sign

    norm = math.sqrt(sum(v * v for v in values))
    if norm == 0:
        return "[" + ",".join("0" for _ in values) + "]"
    return "[" + ",".join(f"{v / norm:.6f}" for v in values) + "]"


def download_dataset(path):
    if path.exists():
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = path.with_suffix(path.suffix + ".tmp")
    last_error = None
    for url in DATA_URLS:
        try:
            print(f"Downloading HotpotQA dev distractor data from {url} to {path}...", file=sys.stderr)
            urllib.request.urlretrieve(url, tmp_path)
            tmp_path.replace(path)
            return
        except Exception as exc:
            last_error = exc
            if tmp_path.exists():
                tmp_path.unlink()
            print(f"Download failed from {url}: {exc}", file=sys.stderr)
    raise RuntimeError(f"failed to download HotpotQA data from all sources: {last_error}")


def load_dataset(path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def normalize_title(title):
    return " ".join(tokenize(title))


def sentence_mentions_title(sentence, title):
    normalized_sentence = " ".join(tokenize(sentence))
    normalized_title = normalize_title(title)
    return bool(normalized_title) and normalized_title in normalized_sentence


def select_examples(rows, limit):
    selected = []
    for row in rows:
        supporting = row.get("supporting_facts") or []
        support_titles = []
        for title, sent_idx in supporting:
            if title not in support_titles:
                support_titles.append(title)
        if len(support_titles) < 2:
            continue

        contexts = {title: sentences for title, sentences in row.get("context", [])}
        if not all(title in contexts for title in support_titles):
            continue

        has_bridge = False
        for source_title in support_titles:
            for sentence in contexts.get(source_title, []):
                if any(
                    other_title != source_title and sentence_mentions_title(sentence, other_title)
                    for other_title in support_titles
                ):
                    has_bridge = True
                    break
            if has_bridge:
                break

        if not has_bridge:
            continue

        selected.append(row)
        if len(selected) >= limit:
            return selected
    return selected


def build_sql(examples, dims, seed_k, top_k, text_weight, vector_weight, relation_weight, max_events_per_entity):
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
        "    'hotpotqa-dev-distractor-sample',",
        "    'default',",
        f"    'HotpotQA dev distractor sample: {len(examples)} bridge examples, hashing vectors dim {dims}.',",
        f"    {sql_json({'sources': DATA_URLS, 'examples': len(examples), 'dims': dims})}",
        ") AS eval_set_id;",
        "",
    ]

    for example_index, row in enumerate(examples, start=1):
        qid = row["_id"]
        question = row["question"]
        support_pairs = {(title, sent_idx) for title, sent_idx in row.get("supporting_facts", [])}
        support_titles = sorted({title for title, _ in support_pairs})
        all_titles = [title for title, _ in row.get("context", [])]

        lines.extend(
            [
                f"-- Example {example_index}: {qid}",
                "DO $$",
                "DECLARE",
                "    eval_set_id bigint;",
                "    question_id bigint;",
                "    document_id bigint;",
                "    chunk_id bigint;",
                "    event_id bigint;",
                "    paragraph_entity_id bigint;",
                "    mentioned_entity_id bigint;",
                "BEGIN",
                "    SELECT es.eval_set_id INTO eval_set_id",
                "    FROM sag_rag.evaluation_set es",
                "    WHERE es.name = 'hotpotqa-dev-distractor-sample';",
                "",
                "    question_id := sag_rag.add_evaluation_question(",
                "        eval_set_id,",
                f"        {sql_quote(question)},",
                f"        {sql_quote(vectorize(question, dims))}::vector,",
                f"        {sql_json({'hotpot_id': qid, 'answer': row.get('answer'), 'support_titles': support_titles})}",
                "    );",
                "",
            ]
        )

        for title, sentences in row.get("context", []):
            external_id = f"{qid}:{title}"
            chunk_text = " ".join(sentences)
            lines.extend(
                [
                    "    document_id := sag_rag.add_document(",
                    f"        {sql_quote(title)},",
                    "        'default',",
                    f"        {sql_quote(external_id)},",
                    "        NULL,",
                    f"        {sql_json({'hotpot_id': qid, 'title': title, 'is_support_title': title in support_titles})}",
                    "    );",
                    "",
                    "    chunk_id := sag_rag.add_chunk(",
                    "        document_id,",
                    "        1,",
                    f"        {sql_quote(chunk_text)},",
                    f"        {sql_quote(vectorize(chunk_text, dims))}::vector,",
                    f"        {sql_json({'hotpot_id': qid, 'title': title})}",
                    "    );",
                    "",
                    "    paragraph_entity_id := sag_rag.upsert_entity(",
                    f"        {sql_quote(title)},",
                    "        'wikipedia_title',",
                    "        'default',",
                    f"        {sql_json({'hotpot_id': qid})}",
                    "    );",
                    "",
                ]
            )

            for sent_idx, sentence in enumerate(sentences):
                if not tokenize(sentence):
                    continue

                is_gold = (title, sent_idx) in support_pairs
                metadata = {
                    "hotpot_id": qid,
                    "title": title,
                    "sentence_index": sent_idx,
                    "is_supporting_fact": is_gold,
                }
                lines.extend(
                    [
                        "    event_id := sag_rag.add_event(",
                        "        document_id,",
                        f"        {sql_quote(sentence)},",
                        "        chunk_id,",
                        f"        {sql_quote(vectorize(sentence, dims))}::vector,",
                        "        1.0,",
                        f"        {sql_json(metadata)}",
                        "    );",
                        "",
                        "    PERFORM sag_rag.link_event_entity(event_id, paragraph_entity_id, 'paragraph_title');",
                    ]
                )

                for other_title in all_titles:
                    if other_title == title:
                        continue
                    if sentence_mentions_title(sentence, other_title):
                        lines.extend(
                            [
                                "    mentioned_entity_id := sag_rag.upsert_entity(",
                                f"        {sql_quote(other_title)},",
                                "        'wikipedia_title',",
                                "        'default',",
                                f"        {sql_json({'hotpot_id': qid, 'mentioned_in': title})}",
                                "    );",
                                "    PERFORM sag_rag.link_event_entity(event_id, mentioned_entity_id, 'mentioned_title');",
                            ]
                        )

                if is_gold:
                    lines.append("    PERFORM sag_rag.link_evaluation_answer_event(question_id, event_id, 1);")
                lines.append("")

        lines.extend(["END $$;", ""])

    lines.extend(
        [
            "WITH eval AS (",
            "    SELECT eval_set_id",
            "    FROM sag_rag.evaluation_set",
            "    WHERE name = 'hotpotqa-dev-distractor-sample'",
            ")",
            f"SELECT sag_rag.run_evaluation_hybrid(eval_set_id, 1) AS hybrid_at_1_run FROM eval;",
            "",
            "WITH eval AS (",
            "    SELECT eval_set_id",
            "    FROM sag_rag.evaluation_set",
            "    WHERE name = 'hotpotqa-dev-distractor-sample'",
            ")",
            f"SELECT sag_rag.run_evaluation_hybrid(eval_set_id, {top_k}) AS hybrid_at_{top_k}_run FROM eval;",
            "",
            "WITH eval AS (",
            "    SELECT eval_set_id",
            "    FROM sag_rag.evaluation_set",
            "    WHERE name = 'hotpotqa-dev-distractor-sample'",
            ")",
            "SELECT sag_rag.run_evaluation_multihop(",
            "    eval_set_id,",
            f"    {seed_k},",
            f"    {top_k},",
            f"    {max_events_per_entity},",
            f"    {text_weight},",
            f"    {vector_weight},",
            f"    {relation_weight}",
            f") AS multihop_at_{top_k}_run FROM eval;",
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
            "    (SELECT eval_set_id FROM sag_rag.evaluation_set WHERE name = 'hotpotqa-dev-distractor-sample')",
            ");",
            "",
            "SELECT",
            "    er.strategy,",
            "    q.question_id,",
            "    left(q.query_text, 100) AS query_text,",
            "    r.rank,",
            "    left(e.event_text, 120) AS event_text,",
            "    r.hop,",
            "    r.source,",
            "    round(r.score::numeric, 6) AS score,",
            "    answer.event_id IS NOT NULL AS is_gold",
            "FROM sag_rag.evaluation_run er",
            "JOIN sag_rag.evaluation_result r ON r.run_id = er.run_id",
            "JOIN sag_rag.evaluation_question q ON q.question_id = r.question_id",
            "JOIN sag_rag.event e ON e.event_id = r.event_id",
            "LEFT JOIN sag_rag.evaluation_answer_event answer",
            "  ON answer.question_id = r.question_id",
            " AND answer.event_id = r.event_id",
            " AND answer.relevance > 0",
            "WHERE r.rank <= 3",
            "   OR answer.event_id IS NOT NULL",
            "ORDER BY er.run_id, q.question_id, r.rank;",
        ]
    )

    return "\n".join(lines) + "\n"


def run_sql(sql_path):
    cmd = [
        "docker",
        "compose",
        "exec",
        "-T",
        "postgres",
        "psql",
        "-U",
        "postgres",
        "-d",
        "rag",
        "-f",
        f"/workspace/{sql_path.as_posix()}",
    ]
    subprocess.run(cmd, check=True)


def main():
    parser = argparse.ArgumentParser(description="Generate and optionally run a HotpotQA benchmark SQL file.")
    parser.add_argument("--data", type=Path, default=DEFAULT_DATA)
    parser.add_argument("--out", type=Path, default=DEFAULT_SQL)
    parser.add_argument("--limit", type=int, default=20)
    parser.add_argument("--dims", type=int, default=64)
    parser.add_argument("--seed-k", type=int, default=10)
    parser.add_argument("--top-k", type=int, default=10)
    parser.add_argument("--max-events-per-entity", type=int, default=10)
    parser.add_argument("--text-weight", type=float, default=0.35)
    parser.add_argument("--vector-weight", type=float, default=0.60)
    parser.add_argument("--relation-weight", type=float, default=0.05)
    parser.add_argument("--run", action="store_true", help="Run generated SQL through docker compose.")
    args = parser.parse_args()

    download_dataset(args.data)
    rows = load_dataset(args.data)
    examples = select_examples(rows, args.limit)
    if not examples:
        raise SystemExit("No bridge examples selected from HotpotQA data")

    if len(examples) < args.limit:
        print(f"Only selected {len(examples)} bridge examples out of requested {args.limit}", file=sys.stderr)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(
        build_sql(
            examples,
            args.dims,
            args.seed_k,
            args.top_k,
            args.text_weight,
            args.vector_weight,
            args.relation_weight,
            args.max_events_per_entity,
        ),
        encoding="utf-8",
    )
    print(f"Wrote {len(examples)} examples to {args.out}", file=sys.stderr)

    if args.run:
        run_sql(args.out)


if __name__ == "__main__":
    main()
