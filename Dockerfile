ARG PG_MAJOR=16
FROM postgres:${PG_MAJOR}

ARG PG_MAJOR

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        "postgresql-${PG_MAJOR}-pgvector" \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY pg_sag_rag.control /tmp/pg_sag_rag.control
COPY pg_sag_rag--0.1.0.sql /tmp/pg_sag_rag--0.1.0.sql
RUN install -m 644 /tmp/pg_sag_rag.control "$(pg_config --sharedir)/extension/pg_sag_rag.control" \
    && install -m 644 /tmp/pg_sag_rag--0.1.0.sql "$(pg_config --sharedir)/extension/pg_sag_rag--0.1.0.sql"
