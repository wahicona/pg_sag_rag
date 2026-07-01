EXTENSION = pg_sag_rag
DATA = pg_sag_rag--0.1.0.sql

PG_CONFIG ?= pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
