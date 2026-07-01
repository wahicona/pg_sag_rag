CREATE SCHEMA sag_rag;

CREATE TABLE sag_rag.document (
    document_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tenant_id text NOT NULL DEFAULT 'default',
    external_id text,
    title text NOT NULL,
    uri text,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, external_id)
);

CREATE TABLE sag_rag.chunk (
    chunk_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    document_id bigint NOT NULL REFERENCES sag_rag.document(document_id) ON DELETE CASCADE,
    chunk_index integer NOT NULL,
    content text NOT NULL,
    embedding vector,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (document_id, chunk_index)
);

CREATE TABLE sag_rag.event (
    event_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    document_id bigint NOT NULL REFERENCES sag_rag.document(document_id) ON DELETE CASCADE,
    chunk_id bigint REFERENCES sag_rag.chunk(chunk_id) ON DELETE SET NULL,
    event_text text NOT NULL,
    embedding vector,
    weight double precision NOT NULL DEFAULT 1.0,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE sag_rag.entity (
    entity_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tenant_id text NOT NULL DEFAULT 'default',
    name text NOT NULL,
    normalized_name text NOT NULL,
    kind text NOT NULL DEFAULT 'unknown',
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, kind, normalized_name)
);

CREATE TABLE sag_rag.entity_alias (
    alias_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entity_id bigint NOT NULL REFERENCES sag_rag.entity(entity_id) ON DELETE CASCADE,
    alias text NOT NULL,
    normalized_alias text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (entity_id, normalized_alias)
);

CREATE TABLE sag_rag.event_entity (
    event_id bigint NOT NULL REFERENCES sag_rag.event(event_id) ON DELETE CASCADE,
    entity_id bigint NOT NULL REFERENCES sag_rag.entity(entity_id) ON DELETE CASCADE,
    role text NOT NULL DEFAULT 'mention',
    confidence double precision NOT NULL DEFAULT 1.0,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (event_id, entity_id, role)
);

CREATE TABLE sag_rag.retrieval_log (
    retrieval_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tenant_id text NOT NULL DEFAULT 'default',
    query_text text NOT NULL,
    strategy text NOT NULL,
    request jsonb NOT NULL DEFAULT '{}'::jsonb,
    result jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE sag_rag.retrieval_profile (
    profile_name text PRIMARY KEY,
    mode text NOT NULL CHECK (mode IN ('hybrid', 'multihop')),
    seed_k integer NOT NULL DEFAULT 20,
    top_k integer NOT NULL DEFAULT 10,
    max_events_per_entity integer NOT NULL DEFAULT 25,
    text_weight double precision NOT NULL DEFAULT 0.35,
    vector_weight double precision NOT NULL DEFAULT 0.60,
    relation_weight double precision NOT NULL DEFAULT 0.05,
    description text,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO sag_rag.retrieval_profile (
    profile_name,
    mode,
    seed_k,
    top_k,
    max_events_per_entity,
    text_weight,
    vector_weight,
    relation_weight,
    description
) VALUES
    (
        'hybrid',
        'hybrid',
        10,
        10,
        25,
        0.35,
        0.65,
        0.0,
        'Direct semantic/text retrieval. Use for FAQ and single-document lookup.'
    ),
    (
        'multihop_conservative',
        'multihop',
        10,
        10,
        10,
        0.35,
        0.60,
        0.05,
        'Preserves hybrid ranking while adding light SQL JOIN relation expansion.'
    ),
    (
        'multihop_relation',
        'multihop',
        3,
        10,
        10,
        0.25,
        0.45,
        0.30,
        'Relation-focused profile for product/fault/contract/workflow questions.'
    );

CREATE TABLE sag_rag.query_route_rule (
    rule_name text PRIMARY KEY,
    profile_name text NOT NULL REFERENCES sag_rag.retrieval_profile(profile_name),
    pattern text NOT NULL,
    priority integer NOT NULL DEFAULT 100,
    description text,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO sag_rag.query_route_rule (
    rule_name,
    profile_name,
    pattern,
    priority,
    description
) VALUES
    (
        'fault_code',
        'multihop_relation',
        '(^|[^a-z0-9])(fault|error|code|alarm|e[0-9]{2,}|fc-[0-9]+)([^a-z0-9]|$)',
        10,
        'Fault/error/alarm/code questions usually need product-to-procedure expansion.'
    ),
    (
        'contract_exception',
        'multihop_relation',
        '(^|[^a-z0-9])(contract|exception|approval|renewal|discount|entitlement)([^a-z0-9]|$)',
        20,
        'Contract and exception questions often cross customer, policy, and approval documents.'
    ),
    (
        'workflow_process',
        'multihop_relation',
        '(^|[^a-z0-9])(workflow|process|procedure|handoff|escalation|route)([^a-z0-9]|$)',
        30,
        'Workflow and procedure questions benefit from relation expansion.'
    ),
    (
        'uncertain_relation',
        'multihop_conservative',
        '(^|[^a-z0-9])(related|linked|associated|depends|impact|affected)([^a-z0-9]|$)',
        80,
        'Uncertain relation wording gets conservative expansion.'
    );

CREATE TABLE sag_rag.evaluation_set (
    eval_set_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tenant_id text NOT NULL DEFAULT 'default',
    name text NOT NULL,
    description text,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, name)
);

CREATE TABLE sag_rag.evaluation_question (
    question_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    eval_set_id bigint NOT NULL REFERENCES sag_rag.evaluation_set(eval_set_id) ON DELETE CASCADE,
    query_text text NOT NULL,
    query_embedding vector,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE sag_rag.evaluation_answer_event (
    question_id bigint NOT NULL REFERENCES sag_rag.evaluation_question(question_id) ON DELETE CASCADE,
    event_id bigint NOT NULL REFERENCES sag_rag.event(event_id) ON DELETE CASCADE,
    relevance integer NOT NULL DEFAULT 1,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (question_id, event_id)
);

CREATE TABLE sag_rag.evaluation_run (
    run_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    eval_set_id bigint NOT NULL REFERENCES sag_rag.evaluation_set(eval_set_id) ON DELETE CASCADE,
    strategy text NOT NULL,
    parameters jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE sag_rag.evaluation_result (
    run_id bigint NOT NULL REFERENCES sag_rag.evaluation_run(run_id) ON DELETE CASCADE,
    question_id bigint NOT NULL REFERENCES sag_rag.evaluation_question(question_id) ON DELETE CASCADE,
    event_id bigint NOT NULL REFERENCES sag_rag.event(event_id) ON DELETE CASCADE,
    rank integer NOT NULL,
    score double precision NOT NULL,
    source text NOT NULL,
    hop integer NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (run_id, question_id, event_id),
    UNIQUE (run_id, question_id, rank)
);

CREATE INDEX document_tenant_idx ON sag_rag.document (tenant_id);
CREATE INDEX chunk_document_idx ON sag_rag.chunk (document_id, chunk_index);
CREATE INDEX chunk_text_gin_idx ON sag_rag.chunk USING gin (to_tsvector('simple'::regconfig, content));
CREATE INDEX chunk_content_trgm_idx ON sag_rag.chunk USING gin (content gin_trgm_ops);
CREATE INDEX event_document_idx ON sag_rag.event (document_id);
CREATE INDEX event_chunk_idx ON sag_rag.event (chunk_id);
CREATE INDEX event_text_gin_idx ON sag_rag.event USING gin (to_tsvector('simple'::regconfig, event_text));
CREATE INDEX event_text_trgm_idx ON sag_rag.event USING gin (event_text gin_trgm_ops);
CREATE INDEX entity_lookup_idx ON sag_rag.entity (tenant_id, kind, normalized_name);
CREATE INDEX entity_alias_lookup_idx ON sag_rag.entity_alias (normalized_alias);
CREATE INDEX event_entity_entity_idx ON sag_rag.event_entity (entity_id, event_id);
CREATE INDEX event_entity_event_idx ON sag_rag.event_entity (event_id, entity_id);
CREATE INDEX evaluation_question_set_idx ON sag_rag.evaluation_question (eval_set_id);
CREATE INDEX evaluation_answer_question_idx ON sag_rag.evaluation_answer_event (question_id);
CREATE INDEX evaluation_result_run_question_rank_idx ON sag_rag.evaluation_result (run_id, question_id, rank);
CREATE INDEX query_route_rule_priority_idx ON sag_rag.query_route_rule (priority, rule_name);

CREATE FUNCTION sag_rag.normalize_entity_name(p_name text)
RETURNS text
LANGUAGE sql
IMMUTABLE
STRICT
AS $$
    SELECT lower(regexp_replace(btrim(p_name), '\s+', ' ', 'g'));
$$;

CREATE FUNCTION sag_rag.add_document(
    p_title text,
    p_tenant_id text DEFAULT 'default',
    p_external_id text DEFAULT NULL,
    p_uri text DEFAULT NULL,
    p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS bigint
LANGUAGE sql
AS $$
    INSERT INTO sag_rag.document (tenant_id, external_id, title, uri, metadata)
    VALUES (p_tenant_id, p_external_id, p_title, p_uri, p_metadata)
    ON CONFLICT (tenant_id, external_id)
    DO UPDATE SET
        title = EXCLUDED.title,
        uri = EXCLUDED.uri,
        metadata = EXCLUDED.metadata
    RETURNING document_id;
$$;

CREATE FUNCTION sag_rag.add_chunk(
    p_document_id bigint,
    p_chunk_index integer,
    p_content text,
    p_embedding vector DEFAULT NULL,
    p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS bigint
LANGUAGE sql
AS $$
    INSERT INTO sag_rag.chunk (document_id, chunk_index, content, embedding, metadata)
    VALUES (p_document_id, p_chunk_index, p_content, p_embedding, p_metadata)
    ON CONFLICT (document_id, chunk_index)
    DO UPDATE SET
        content = EXCLUDED.content,
        embedding = EXCLUDED.embedding,
        metadata = EXCLUDED.metadata
    RETURNING chunk_id;
$$;

CREATE FUNCTION sag_rag.add_event(
    p_document_id bigint,
    p_event_text text,
    p_chunk_id bigint DEFAULT NULL,
    p_embedding vector DEFAULT NULL,
    p_weight double precision DEFAULT 1.0,
    p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS bigint
LANGUAGE sql
AS $$
    INSERT INTO sag_rag.event (document_id, chunk_id, event_text, embedding, weight, metadata)
    VALUES (p_document_id, p_chunk_id, p_event_text, p_embedding, p_weight, p_metadata)
    RETURNING event_id;
$$;

CREATE FUNCTION sag_rag.upsert_entity(
    p_name text,
    p_kind text DEFAULT 'unknown',
    p_tenant_id text DEFAULT 'default',
    p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS bigint
LANGUAGE sql
AS $$
    INSERT INTO sag_rag.entity (tenant_id, name, normalized_name, kind, metadata)
    VALUES (p_tenant_id, p_name, sag_rag.normalize_entity_name(p_name), p_kind, p_metadata)
    ON CONFLICT (tenant_id, kind, normalized_name)
    DO UPDATE SET
        name = EXCLUDED.name,
        metadata = sag_rag.entity.metadata || EXCLUDED.metadata
    RETURNING entity_id;
$$;

CREATE FUNCTION sag_rag.add_entity_alias(
    p_entity_id bigint,
    p_alias text
)
RETURNS bigint
LANGUAGE sql
AS $$
    INSERT INTO sag_rag.entity_alias (entity_id, alias, normalized_alias)
    VALUES (p_entity_id, p_alias, sag_rag.normalize_entity_name(p_alias))
    ON CONFLICT (entity_id, normalized_alias)
    DO UPDATE SET alias = EXCLUDED.alias
    RETURNING alias_id;
$$;

CREATE FUNCTION sag_rag.link_event_entity(
    p_event_id bigint,
    p_entity_id bigint,
    p_role text DEFAULT 'mention',
    p_confidence double precision DEFAULT 1.0,
    p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE sql
AS $$
    INSERT INTO sag_rag.event_entity (event_id, entity_id, role, confidence, metadata)
    VALUES (p_event_id, p_entity_id, p_role, p_confidence, p_metadata)
    ON CONFLICT (event_id, entity_id, role)
    DO UPDATE SET
        confidence = EXCLUDED.confidence,
        metadata = sag_rag.event_entity.metadata || EXCLUDED.metadata;
$$;

CREATE FUNCTION sag_rag.search_events_hybrid(
    p_query_text text,
    p_query_embedding vector DEFAULT NULL,
    p_tenant_id text DEFAULT 'default',
    p_top_k integer DEFAULT 20,
    p_text_weight double precision DEFAULT 0.35,
    p_vector_weight double precision DEFAULT 0.65
)
RETURNS TABLE (
    event_id bigint,
    document_id bigint,
    chunk_id bigint,
    event_text text,
    score double precision,
    text_score double precision,
    vector_score double precision,
    hop integer,
    source text
)
LANGUAGE sql
STABLE
AS $$
    WITH query AS (
        SELECT
            plainto_tsquery('simple'::regconfig, coalesce(p_query_text, '')) AS tsq,
            NULLIF(btrim(coalesce(p_query_text, '')), '') AS raw_text
    ),
    scoped_events AS (
        SELECT e.*
        FROM sag_rag.event e
        JOIN sag_rag.document d ON d.document_id = e.document_id
        WHERE d.tenant_id = p_tenant_id
    ),
    scored AS (
        SELECT
            e.event_id,
            e.document_id,
            e.chunk_id,
            e.event_text,
            CASE
                WHEN q.raw_text IS NULL THEN 0.0
                ELSE greatest(
                    ts_rank_cd(to_tsvector('simple'::regconfig, e.event_text), q.tsq)::double precision,
                    similarity(e.event_text, p_query_text)::double precision
                )
            END AS text_score,
            CASE
                WHEN p_query_embedding IS NULL OR e.embedding IS NULL THEN 0.0
                ELSE 1.0 / (1.0 + (e.embedding <=> p_query_embedding))
            END AS vector_score
        FROM scoped_events e
        CROSS JOIN query q
        WHERE
            p_query_embedding IS NOT NULL
            OR q.raw_text IS NULL
            OR to_tsvector('simple'::regconfig, e.event_text) @@ q.tsq
            OR e.event_text % p_query_text
    )
    SELECT
        s.event_id,
        s.document_id,
        s.chunk_id,
        s.event_text,
        ((p_text_weight * s.text_score) + (p_vector_weight * s.vector_score)) AS score,
        s.text_score,
        s.vector_score,
        0 AS hop,
        'hybrid'::text AS source
    FROM scored s
    ORDER BY score DESC, s.event_id
    LIMIT greatest(p_top_k, 0);
$$;

CREATE FUNCTION sag_rag.search_events_multihop(
    p_query_text text,
    p_query_embedding vector DEFAULT NULL,
    p_tenant_id text DEFAULT 'default',
    p_seed_k integer DEFAULT 20,
    p_top_k integer DEFAULT 50,
    p_max_events_per_entity integer DEFAULT 25,
    p_text_weight double precision DEFAULT 0.25,
    p_vector_weight double precision DEFAULT 0.45,
    p_relation_weight double precision DEFAULT 0.30
)
RETURNS TABLE (
    event_id bigint,
    document_id bigint,
    chunk_id bigint,
    event_text text,
    score double precision,
    text_score double precision,
    vector_score double precision,
    relation_score double precision,
    hop integer,
    source text
)
LANGUAGE sql
STABLE
AS $$
    WITH seed AS (
        SELECT *
        FROM sag_rag.search_events_hybrid(
            p_query_text,
            p_query_embedding,
            p_tenant_id,
            greatest(p_seed_k, 1),
            p_text_weight,
            p_vector_weight
        )
    ),
    seed_entity AS (
        SELECT
            ee.entity_id,
            max(seed.score * ee.confidence) AS seed_entity_score
        FROM seed
        JOIN sag_rag.event_entity ee ON ee.event_id = seed.event_id
        GROUP BY ee.entity_id
    ),
    expanded_ranked AS (
        SELECT
            e.event_id,
            e.document_id,
            e.chunk_id,
            e.event_text,
            ee.entity_id,
            (se.seed_entity_score * ee.confidence * e.weight) AS relation_score,
            row_number() OVER (
                PARTITION BY ee.entity_id
                ORDER BY se.seed_entity_score * ee.confidence * e.weight DESC, e.event_id
            ) AS entity_rank
        FROM seed_entity se
        JOIN sag_rag.event_entity ee ON ee.entity_id = se.entity_id
        JOIN sag_rag.event e ON e.event_id = ee.event_id
        JOIN sag_rag.document d ON d.document_id = e.document_id
        WHERE d.tenant_id = p_tenant_id
          AND NOT EXISTS (SELECT 1 FROM seed s WHERE s.event_id = e.event_id)
    ),
    expanded AS (
        SELECT
            er.event_id,
            er.document_id,
            er.chunk_id,
            er.event_text,
            max(er.relation_score) AS relation_score
        FROM expanded_ranked er
        WHERE er.entity_rank <= greatest(p_max_events_per_entity, 1)
        GROUP BY er.event_id, er.document_id, er.chunk_id, er.event_text
    ),
    expanded_scored AS (
        SELECT
            ex.event_id,
            ex.document_id,
            ex.chunk_id,
            ex.event_text,
            CASE
                WHEN NULLIF(btrim(coalesce(p_query_text, '')), '') IS NULL THEN 0.0
                ELSE greatest(
                    ts_rank_cd(
                        to_tsvector('simple'::regconfig, ex.event_text),
                        plainto_tsquery('simple'::regconfig, coalesce(p_query_text, ''))
                    )::double precision,
                    similarity(ex.event_text, p_query_text)::double precision
                )
            END AS text_score,
            CASE
                WHEN p_query_embedding IS NULL OR e.embedding IS NULL THEN 0.0
                ELSE 1.0 / (1.0 + (e.embedding <=> p_query_embedding))
            END AS vector_score,
            ex.relation_score
        FROM expanded ex
        JOIN sag_rag.event e ON e.event_id = ex.event_id
    ),
    combined AS (
        SELECT
            s.event_id,
            s.document_id,
            s.chunk_id,
            s.event_text,
            s.text_score,
            s.vector_score,
            1.0::double precision AS relation_score,
            s.score AS score,
            0 AS hop,
            'seed'::text AS source
        FROM seed s
        UNION ALL
        SELECT
            es.event_id,
            es.document_id,
            es.chunk_id,
            es.event_text,
            es.text_score,
            es.vector_score,
            es.relation_score,
            ((p_text_weight * es.text_score) +
             (p_vector_weight * es.vector_score) +
             (p_relation_weight * es.relation_score)) AS score,
            1 AS hop,
            'sql_join_expand'::text AS source
        FROM expanded_scored es
    )
    SELECT
        c.event_id,
        c.document_id,
        c.chunk_id,
        c.event_text,
        c.score,
        c.text_score,
        c.vector_score,
        c.relation_score,
        c.hop,
        c.source
    FROM combined c
    ORDER BY c.score DESC, c.hop, c.event_id
    LIMIT greatest(p_top_k, 0);
$$;

CREATE FUNCTION sag_rag.search_events_profile(
    p_profile_name text,
    p_query_text text,
    p_query_embedding vector DEFAULT NULL,
    p_tenant_id text DEFAULT 'default'
)
RETURNS TABLE (
    event_id bigint,
    document_id bigint,
    chunk_id bigint,
    event_text text,
    score double precision,
    text_score double precision,
    vector_score double precision,
    relation_score double precision,
    hop integer,
    source text
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    profile sag_rag.retrieval_profile%ROWTYPE;
BEGIN
    SELECT *
    INTO profile
    FROM sag_rag.retrieval_profile
    WHERE profile_name = p_profile_name;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'retrieval profile % does not exist', p_profile_name;
    END IF;

    IF profile.mode = 'hybrid' THEN
        RETURN QUERY
        SELECT
            h.event_id,
            h.document_id,
            h.chunk_id,
            h.event_text,
            h.score,
            h.text_score,
            h.vector_score,
            0.0::double precision AS relation_score,
            h.hop,
            (profile.profile_name || ':' || h.source)::text AS source
        FROM sag_rag.search_events_hybrid(
            p_query_text,
            p_query_embedding,
            p_tenant_id,
            profile.top_k,
            profile.text_weight,
            profile.vector_weight
        ) h;
    ELSE
        RETURN QUERY
        SELECT
            m.event_id,
            m.document_id,
            m.chunk_id,
            m.event_text,
            m.score,
            m.text_score,
            m.vector_score,
            m.relation_score,
            m.hop,
            (profile.profile_name || ':' || m.source)::text AS source
        FROM sag_rag.search_events_multihop(
            p_query_text,
            p_query_embedding,
            p_tenant_id,
            profile.seed_k,
            profile.top_k,
            profile.max_events_per_entity,
            profile.text_weight,
            profile.vector_weight,
            profile.relation_weight
        ) m;
    END IF;
END;
$$;

CREATE FUNCTION sag_rag.route_query(
    p_query_text text,
    p_default_profile text DEFAULT 'hybrid'
)
RETURNS TABLE (
    profile_name text,
    rule_name text,
    priority integer,
    reason text
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM sag_rag.retrieval_profile rp
        WHERE rp.profile_name = p_default_profile
    ) THEN
        RAISE EXCEPTION 'default retrieval profile % does not exist', p_default_profile;
    END IF;

    RETURN QUERY
    SELECT
        qrr.profile_name,
        qrr.rule_name,
        qrr.priority,
        ('matched route rule: ' || qrr.rule_name)::text AS reason
    FROM sag_rag.query_route_rule qrr
    WHERE coalesce(p_query_text, '') ~* qrr.pattern
    ORDER BY qrr.priority, qrr.rule_name
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN QUERY
        SELECT
            p_default_profile,
            'default'::text,
            2147483647,
            'no route rule matched'::text;
    END IF;
END;
$$;

CREATE FUNCTION sag_rag.search_events_auto(
    p_query_text text,
    p_query_embedding vector DEFAULT NULL,
    p_tenant_id text DEFAULT 'default',
    p_default_profile text DEFAULT 'hybrid'
)
RETURNS TABLE (
    profile_name text,
    route_rule text,
    event_id bigint,
    document_id bigint,
    chunk_id bigint,
    event_text text,
    score double precision,
    text_score double precision,
    vector_score double precision,
    relation_score double precision,
    hop integer,
    source text
)
LANGUAGE sql
STABLE
AS $$
    WITH route AS (
        SELECT *
        FROM sag_rag.route_query(p_query_text, p_default_profile)
        LIMIT 1
    )
    SELECT
        route.profile_name,
        route.rule_name AS route_rule,
        result.event_id,
        result.document_id,
        result.chunk_id,
        result.event_text,
        result.score,
        result.text_score,
        result.vector_score,
        result.relation_score,
        result.hop,
        ('auto:' || route.rule_name || ':' || result.source)::text AS source
    FROM route
    CROSS JOIN LATERAL sag_rag.search_events_profile(
        route.profile_name,
        p_query_text,
        p_query_embedding,
        p_tenant_id
    ) AS result;
$$;

CREATE FUNCTION sag_rag.explain_event_trace(p_event_id bigint)
RETURNS TABLE (
    event_id bigint,
    event_text text,
    entity_id bigint,
    entity_name text,
    entity_kind text,
    role text,
    confidence double precision,
    document_title text,
    chunk_content text
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        e.event_id,
        e.event_text,
        ent.entity_id,
        ent.name,
        ent.kind,
        ee.role,
        ee.confidence,
        d.title,
        c.content
    FROM sag_rag.event e
    JOIN sag_rag.document d ON d.document_id = e.document_id
    LEFT JOIN sag_rag.chunk c ON c.chunk_id = e.chunk_id
    LEFT JOIN sag_rag.event_entity ee ON ee.event_id = e.event_id
    LEFT JOIN sag_rag.entity ent ON ent.entity_id = ee.entity_id
    WHERE e.event_id = p_event_id
    ORDER BY ent.kind, ent.name;
$$;

CREATE FUNCTION sag_rag.log_retrieval(
    p_query_text text,
    p_strategy text,
    p_tenant_id text DEFAULT 'default',
    p_request jsonb DEFAULT '{}'::jsonb,
    p_result jsonb DEFAULT '{}'::jsonb
)
RETURNS bigint
LANGUAGE sql
AS $$
    INSERT INTO sag_rag.retrieval_log (tenant_id, query_text, strategy, request, result)
    VALUES (p_tenant_id, p_query_text, p_strategy, p_request, p_result)
    RETURNING retrieval_id;
$$;

CREATE FUNCTION sag_rag.add_evaluation_set(
    p_name text,
    p_tenant_id text DEFAULT 'default',
    p_description text DEFAULT NULL,
    p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS bigint
LANGUAGE sql
AS $$
    INSERT INTO sag_rag.evaluation_set (tenant_id, name, description, metadata)
    VALUES (p_tenant_id, p_name, p_description, p_metadata)
    ON CONFLICT (tenant_id, name)
    DO UPDATE SET
        description = EXCLUDED.description,
        metadata = sag_rag.evaluation_set.metadata || EXCLUDED.metadata
    RETURNING eval_set_id;
$$;

CREATE FUNCTION sag_rag.add_evaluation_question(
    p_eval_set_id bigint,
    p_query_text text,
    p_query_embedding vector DEFAULT NULL,
    p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS bigint
LANGUAGE sql
AS $$
    INSERT INTO sag_rag.evaluation_question (eval_set_id, query_text, query_embedding, metadata)
    VALUES (p_eval_set_id, p_query_text, p_query_embedding, p_metadata)
    RETURNING question_id;
$$;

CREATE FUNCTION sag_rag.link_evaluation_answer_event(
    p_question_id bigint,
    p_event_id bigint,
    p_relevance integer DEFAULT 1,
    p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE sql
AS $$
    INSERT INTO sag_rag.evaluation_answer_event (question_id, event_id, relevance, metadata)
    VALUES (p_question_id, p_event_id, p_relevance, p_metadata)
    ON CONFLICT (question_id, event_id)
    DO UPDATE SET
        relevance = EXCLUDED.relevance,
        metadata = sag_rag.evaluation_answer_event.metadata || EXCLUDED.metadata;
$$;

CREATE FUNCTION sag_rag.run_evaluation_multihop(
    p_eval_set_id bigint,
    p_seed_k integer DEFAULT 20,
    p_top_k integer DEFAULT 10,
    p_max_events_per_entity integer DEFAULT 25,
    p_text_weight double precision DEFAULT 0.25,
    p_vector_weight double precision DEFAULT 0.45,
    p_relation_weight double precision DEFAULT 0.30
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_run_id bigint;
    v_tenant_id text;
    q record;
BEGIN
    SELECT tenant_id INTO v_tenant_id
    FROM sag_rag.evaluation_set
    WHERE eval_set_id = p_eval_set_id;

    IF v_tenant_id IS NULL THEN
        RAISE EXCEPTION 'evaluation set % does not exist', p_eval_set_id;
    END IF;

    INSERT INTO sag_rag.evaluation_run (eval_set_id, strategy, parameters)
    VALUES (
        p_eval_set_id,
        'multihop',
        jsonb_build_object(
            'seed_k', p_seed_k,
            'top_k', p_top_k,
            'max_events_per_entity', p_max_events_per_entity,
            'text_weight', p_text_weight,
            'vector_weight', p_vector_weight,
            'relation_weight', p_relation_weight
        )
    )
    RETURNING run_id INTO v_run_id;

    FOR q IN
        SELECT question_id, query_text, query_embedding
        FROM sag_rag.evaluation_question
        WHERE eval_set_id = p_eval_set_id
        ORDER BY question_id
    LOOP
        INSERT INTO sag_rag.evaluation_result (
            run_id,
            question_id,
            event_id,
            rank,
            score,
            source,
            hop
        )
        SELECT
            v_run_id,
            q.question_id,
            result.event_id,
            row_number() OVER (ORDER BY result.score DESC, result.hop, result.event_id)::integer AS rank,
            result.score,
            result.source,
            result.hop
        FROM sag_rag.search_events_multihop(
            q.query_text,
            q.query_embedding,
            v_tenant_id,
            p_seed_k,
            p_top_k,
            p_max_events_per_entity,
            p_text_weight,
            p_vector_weight,
            p_relation_weight
        ) AS result;
    END LOOP;

    RETURN v_run_id;
END;
$$;

CREATE FUNCTION sag_rag.run_evaluation_hybrid(
    p_eval_set_id bigint,
    p_top_k integer DEFAULT 10
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_run_id bigint;
    v_tenant_id text;
    q record;
BEGIN
    SELECT tenant_id INTO v_tenant_id
    FROM sag_rag.evaluation_set
    WHERE eval_set_id = p_eval_set_id;

    IF v_tenant_id IS NULL THEN
        RAISE EXCEPTION 'evaluation set % does not exist', p_eval_set_id;
    END IF;

    INSERT INTO sag_rag.evaluation_run (eval_set_id, strategy, parameters)
    VALUES (
        p_eval_set_id,
        'hybrid',
        jsonb_build_object('top_k', p_top_k)
    )
    RETURNING run_id INTO v_run_id;

    FOR q IN
        SELECT question_id, query_text, query_embedding
        FROM sag_rag.evaluation_question
        WHERE eval_set_id = p_eval_set_id
        ORDER BY question_id
    LOOP
        INSERT INTO sag_rag.evaluation_result (
            run_id,
            question_id,
            event_id,
            rank,
            score,
            source,
            hop
        )
        SELECT
            v_run_id,
            q.question_id,
            result.event_id,
            row_number() OVER (ORDER BY result.score DESC, result.event_id)::integer AS rank,
            result.score,
            result.source,
            result.hop
        FROM sag_rag.search_events_hybrid(
            q.query_text,
            q.query_embedding,
            v_tenant_id,
            p_top_k
        ) AS result;
    END LOOP;

    RETURN v_run_id;
END;
$$;

CREATE FUNCTION sag_rag.run_evaluation_profile(
    p_eval_set_id bigint,
    p_profile_name text
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_run_id bigint;
    v_tenant_id text;
    profile sag_rag.retrieval_profile%ROWTYPE;
    q record;
BEGIN
    SELECT tenant_id INTO v_tenant_id
    FROM sag_rag.evaluation_set
    WHERE eval_set_id = p_eval_set_id;

    IF v_tenant_id IS NULL THEN
        RAISE EXCEPTION 'evaluation set % does not exist', p_eval_set_id;
    END IF;

    SELECT *
    INTO profile
    FROM sag_rag.retrieval_profile
    WHERE profile_name = p_profile_name;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'retrieval profile % does not exist', p_profile_name;
    END IF;

    INSERT INTO sag_rag.evaluation_run (eval_set_id, strategy, parameters)
    VALUES (
        p_eval_set_id,
        profile.profile_name,
        jsonb_build_object(
            'profile_name', profile.profile_name,
            'mode', profile.mode,
            'seed_k', profile.seed_k,
            'top_k', profile.top_k,
            'max_events_per_entity', profile.max_events_per_entity,
            'text_weight', profile.text_weight,
            'vector_weight', profile.vector_weight,
            'relation_weight', profile.relation_weight
        )
    )
    RETURNING run_id INTO v_run_id;

    FOR q IN
        SELECT question_id, query_text, query_embedding
        FROM sag_rag.evaluation_question
        WHERE eval_set_id = p_eval_set_id
        ORDER BY question_id
    LOOP
        INSERT INTO sag_rag.evaluation_result (
            run_id,
            question_id,
            event_id,
            rank,
            score,
            source,
            hop
        )
        SELECT
            v_run_id,
            q.question_id,
            result.event_id,
            row_number() OVER (ORDER BY result.score DESC, result.hop, result.event_id)::integer AS rank,
            result.score,
            result.source,
            result.hop
        FROM sag_rag.search_events_profile(
            profile.profile_name,
            q.query_text,
            q.query_embedding,
            v_tenant_id
        ) AS result;
    END LOOP;

    RETURN v_run_id;
END;
$$;

CREATE FUNCTION sag_rag.run_evaluation_auto(
    p_eval_set_id bigint,
    p_default_profile text DEFAULT 'hybrid'
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_run_id bigint;
    v_tenant_id text;
    q record;
BEGIN
    SELECT tenant_id INTO v_tenant_id
    FROM sag_rag.evaluation_set
    WHERE eval_set_id = p_eval_set_id;

    IF v_tenant_id IS NULL THEN
        RAISE EXCEPTION 'evaluation set % does not exist', p_eval_set_id;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM sag_rag.retrieval_profile rp
        WHERE rp.profile_name = p_default_profile
    ) THEN
        RAISE EXCEPTION 'default retrieval profile % does not exist', p_default_profile;
    END IF;

    INSERT INTO sag_rag.evaluation_run (eval_set_id, strategy, parameters)
    VALUES (
        p_eval_set_id,
        'auto',
        jsonb_build_object('default_profile', p_default_profile)
    )
    RETURNING run_id INTO v_run_id;

    FOR q IN
        SELECT question_id, query_text, query_embedding
        FROM sag_rag.evaluation_question
        WHERE eval_set_id = p_eval_set_id
        ORDER BY question_id
    LOOP
        INSERT INTO sag_rag.evaluation_result (
            run_id,
            question_id,
            event_id,
            rank,
            score,
            source,
            hop
        )
        SELECT
            v_run_id,
            q.question_id,
            result.event_id,
            row_number() OVER (ORDER BY result.score DESC, result.hop, result.event_id)::integer AS rank,
            result.score,
            result.source,
            result.hop
        FROM sag_rag.search_events_auto(
            q.query_text,
            q.query_embedding,
            v_tenant_id,
            p_default_profile
        ) AS result;
    END LOOP;

    RETURN v_run_id;
END;
$$;

CREATE FUNCTION sag_rag.recall_at_k(
    p_run_id bigint,
    p_k integer DEFAULT 10
)
RETURNS TABLE (
    run_id bigint,
    k integer,
    questions integer,
    hits integer,
    recall double precision
)
LANGUAGE sql
STABLE
AS $$
    WITH labeled_questions AS (
        SELECT DISTINCT question_id
        FROM sag_rag.evaluation_answer_event
        WHERE relevance > 0
    ),
    run_questions AS (
        SELECT DISTINCT er.question_id
        FROM sag_rag.evaluation_result er
        JOIN labeled_questions lq ON lq.question_id = er.question_id
        WHERE er.run_id = p_run_id
    ),
    hit_questions AS (
        SELECT DISTINCT er.question_id
        FROM sag_rag.evaluation_result er
        JOIN sag_rag.evaluation_answer_event answer
          ON answer.question_id = er.question_id
         AND answer.event_id = er.event_id
         AND answer.relevance > 0
        WHERE er.run_id = p_run_id
          AND er.rank <= greatest(p_k, 1)
    )
    SELECT
        p_run_id,
        greatest(p_k, 1),
        count(rq.question_id)::integer AS questions,
        count(hq.question_id)::integer AS hits,
        CASE
            WHEN count(rq.question_id) = 0 THEN 0.0
            ELSE count(hq.question_id)::double precision / count(rq.question_id)::double precision
        END AS recall
    FROM run_questions rq
    LEFT JOIN hit_questions hq ON hq.question_id = rq.question_id;
$$;

CREATE FUNCTION sag_rag.mrr_at_k(
    p_run_id bigint,
    p_k integer DEFAULT 10
)
RETURNS TABLE (
    run_id bigint,
    k integer,
    questions integer,
    answered integer,
    mrr double precision,
    avg_first_gold_rank double precision
)
LANGUAGE sql
STABLE
AS $$
    WITH run_questions AS (
        SELECT DISTINCT er.question_id
        FROM sag_rag.evaluation_result er
        JOIN sag_rag.evaluation_answer_event answer
          ON answer.question_id = er.question_id
         AND answer.relevance > 0
        WHERE er.run_id = p_run_id
    ),
    first_gold AS (
        SELECT
            er.question_id,
            min(er.rank) AS first_gold_rank
        FROM sag_rag.evaluation_result er
        JOIN sag_rag.evaluation_answer_event answer
          ON answer.question_id = er.question_id
         AND answer.event_id = er.event_id
         AND answer.relevance > 0
        WHERE er.run_id = p_run_id
          AND er.rank <= greatest(p_k, 1)
        GROUP BY er.question_id
    )
    SELECT
        p_run_id,
        greatest(p_k, 1),
        count(rq.question_id)::integer AS questions,
        count(fg.first_gold_rank)::integer AS answered,
        CASE
            WHEN count(rq.question_id) = 0 THEN 0.0
            ELSE sum(coalesce(1.0 / fg.first_gold_rank, 0.0))::double precision /
                 count(rq.question_id)::double precision
        END AS mrr,
        avg(fg.first_gold_rank)::double precision AS avg_first_gold_rank
    FROM run_questions rq
    LEFT JOIN first_gold fg ON fg.question_id = rq.question_id;
$$;

CREATE FUNCTION sag_rag.evaluation_summary(
    p_eval_set_id bigint,
    p_k integer DEFAULT NULL
)
RETURNS TABLE (
    run_id bigint,
    strategy text,
    parameters jsonb,
    k integer,
    questions integer,
    hits integer,
    recall double precision,
    answered integer,
    mrr double precision,
    avg_first_gold_rank double precision
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        er.run_id,
        er.strategy,
        er.parameters,
        coalesce(p_k, (er.parameters ->> 'top_k')::integer, 10) AS k,
        recall.questions,
        recall.hits,
        recall.recall,
        mrr.answered,
        mrr.mrr,
        mrr.avg_first_gold_rank
    FROM sag_rag.evaluation_run er
    CROSS JOIN LATERAL sag_rag.recall_at_k(
        er.run_id,
        coalesce(p_k, (er.parameters ->> 'top_k')::integer, 10)
    ) AS recall
    CROSS JOIN LATERAL sag_rag.mrr_at_k(
        er.run_id,
        coalesce(p_k, (er.parameters ->> 'top_k')::integer, 10)
    ) AS mrr
    WHERE er.eval_set_id = p_eval_set_id
    ORDER BY er.run_id;
$$;

CREATE FUNCTION sag_rag.create_hnsw_indexes(
    p_dimensions integer,
    p_distance text DEFAULT 'cosine'
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    opclass text;
BEGIN
    IF p_dimensions IS NULL OR p_dimensions <= 0 THEN
        RAISE EXCEPTION 'p_dimensions must be positive';
    END IF;

    opclass := CASE p_distance
        WHEN 'cosine' THEN 'vector_cosine_ops'
        WHEN 'l2' THEN 'vector_l2_ops'
        WHEN 'ip' THEN 'vector_ip_ops'
        ELSE NULL
    END;

    IF opclass IS NULL THEN
        RAISE EXCEPTION 'unsupported distance %, expected cosine, l2, or ip', p_distance;
    END IF;

    EXECUTE format(
        'CREATE INDEX IF NOT EXISTS chunk_embedding_hnsw_%1$s_%2$s_idx ON sag_rag.chunk USING hnsw ((embedding::vector(%3$s)) %4$s) WHERE embedding IS NOT NULL',
        p_distance,
        p_dimensions,
        p_dimensions,
        opclass
    );

    EXECUTE format(
        'CREATE INDEX IF NOT EXISTS event_embedding_hnsw_%1$s_%2$s_idx ON sag_rag.event USING hnsw ((embedding::vector(%3$s)) %4$s) WHERE embedding IS NOT NULL',
        p_distance,
        p_dimensions,
        p_dimensions,
        opclass
    );
END;
$$;

COMMENT ON SCHEMA sag_rag IS 'SQL-native multi-hop RAG schema and functions.';
COMMENT ON FUNCTION sag_rag.search_events_multihop(text, vector, text, integer, integer, integer, double precision, double precision, double precision)
IS 'Runs seed hybrid retrieval, expands related events through event-entity SQL JOINs, and fuses text/vector/relation scores.';
COMMENT ON FUNCTION sag_rag.route_query(text, text)
IS 'Selects a retrieval profile by matching query_route_rule patterns, falling back to the default profile.';
COMMENT ON FUNCTION sag_rag.search_events_auto(text, vector, text, text)
IS 'Routes a query to a retrieval profile, runs search_events_profile, and returns traceable route metadata with results.';
COMMENT ON FUNCTION sag_rag.run_evaluation_auto(bigint, text)
IS 'Evaluates automatic query routing plus retrieval for an evaluation set.';
