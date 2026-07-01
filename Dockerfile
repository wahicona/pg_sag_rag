FROM postgres:16-alpine

RUN apk update
RUN apk add --no-cache git build-base postgresql16-dev clang llvm
RUN git clone --depth 1 --branch v0.8.0 https://github.com/pgvector/pgvector.git /tmp/pgvector
RUN make -C /tmp/pgvector with_llvm=no
RUN make -C /tmp/pgvector install with_llvm=no

COPY pg_sag_rag.control /usr/local/share/postgresql/extension/pg_sag_rag.control
COPY pg_sag_rag--0.1.0.sql /usr/local/share/postgresql/extension/pg_sag_rag--0.1.0.sql
