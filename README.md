# appwrite/postgres

Custom PostgreSQL image for Appwrite Cloud dedicated databases (and the VectorsDB product). It is the official `postgres` image plus the ten most-used PostgreSQL extensions, bundled so they are available out of the box.

## Bundled extensions

| Extension | `CREATE EXTENSION` name | Purpose | Preloaded |
| --------- | ----------------------- | ------- | --------- |
| pgvector | `vector` | Vector similarity search / embeddings | No |
| pg_stat_statements | `pg_stat_statements` | Per-query execution statistics | **Yes** |
| uuid-ossp | `uuid-ossp` | UUID generation | No |
| pgcrypto | `pgcrypto` | Hashing / encryption functions | No |
| pg_trgm | `pg_trgm` | Trigram fuzzy / similarity text search | No |
| PostGIS | `postgis` | Geospatial types, indexing, functions | No |
| citext | `citext` | Case-insensitive text | No |
| unaccent | `unaccent` | Accent-insensitive text search | No |
| hstore | `hstore` | Key/value pairs in a single column | No |
| pg_cron | `pg_cron` | In-database job scheduling | **Yes** |

Every extension is compiled into the image, so it appears in `pg_available_extensions` and installs with `CREATE EXTENSION IF NOT EXISTS`.

## Preloaded libraries

`pg_stat_statements` and `pg_cron` require `shared_preload_libraries`, which must be set before the server starts. The image sets it in the cluster config template, so it applies to every initialized cluster with no runtime configuration:

```
shared_preload_libraries = 'pg_stat_statements,pg_cron'
```

`pg_cron` runs its scheduler in the default `postgres` database.

## Supported major versions and tags

Built for each PostgreSQL major version Appwrite Cloud advertises (`Engine::getSupportedVersions()`): **17** and **18**. Publishing a release tag (e.g. `0.2.0`) produces, for each major:

| Tag | Meaning |
| --- | ------- |
| `appwrite/postgres:18`, `appwrite/postgres:17` | Floating tag for the major version |
| `appwrite/postgres:18-0.2.0`, `appwrite/postgres:17-0.2.0` | Immutable major + release |
| `appwrite/postgres:0.2.0`, `appwrite/postgres:latest` | Default major (18), for backward compatibility |

The default-major bare-semver tags keep the existing `version` -> image mapping working until the per-version wiring lands.

## Build

```bash
docker build --build-arg PG_MAJOR=18 -t appwrite/postgres:18 .
docker build --build-arg PG_MAJOR=17 -t appwrite/postgres:17 .
```

## Verify

`tests/verify.sh` boots the image and asserts every extension is available, installs, and that both preload extensions actually load:

```bash
docker build --build-arg PG_MAJOR=18 -t appwrite/postgres:ci-18 .
./tests/verify.sh appwrite/postgres:ci-18 18
```
