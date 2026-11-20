ARG PG_MAJOR=18@sha256:eb63372c1e05c755f55fa30cbd07aecc443676fc6c0fa90b9002d01537841e1a

# The upstream image ships gosu built with Go 1.24.6; rebuild it with a patched Go.
FROM --platform=$BUILDPLATFORM golang:1.27.4-trixie@sha256:f18c3d73a184fb0582828510722e723b63a93f7188d11dd223d9be6f6880e65d AS gosu

ARG GOSU_VERSION=1.20
ARG TARGETARCH

WORKDIR /src
RUN git clone --depth 1 --branch "${GOSU_VERSION}" https://github.com/tianon/gosu.git . && \
    CGO_ENABLED=0 GOARCH="${TARGETARCH}" go build -trimpath -ldflags '-d -w' -o /gosu .

FROM postgres:${PG_MAJOR}

ARG PG_MAJOR

COPY --from=gosu /gosu /usr/local/bin/gosu

# hadolint ignore=DL3008
RUN gosu nobody true && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        postgresql-${PG_MAJOR}-pgvector \
        postgresql-${PG_MAJOR}-postgis-3 \
        postgresql-${PG_MAJOR}-postgis-3-scripts \
        postgresql-${PG_MAJOR}-cron && \
    rm -rf /var/lib/apt/lists/*

RUN printf '\n%s\n' "shared_preload_libraries = 'pg_stat_statements,pg_cron'" \
    >> "/usr/share/postgresql/${PG_MAJOR}/postgresql.conf.sample"
