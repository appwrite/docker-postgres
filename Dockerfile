ARG PG_MAJOR=18

FROM postgres:${PG_MAJOR}

ARG PG_MAJOR

# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        postgresql-${PG_MAJOR}-pgvector \
        postgresql-${PG_MAJOR}-postgis-3 \
        postgresql-${PG_MAJOR}-postgis-3-scripts \
        postgresql-${PG_MAJOR}-cron && \
    rm -rf /var/lib/apt/lists/*

RUN printf '\n%s\n' "shared_preload_libraries = 'pg_stat_statements,pg_cron'" \
    >> "/usr/share/postgresql/${PG_MAJOR}/postgresql.conf.sample"
