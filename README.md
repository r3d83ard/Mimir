Project Mimir — OpenSearch Dev Stack
====================================

This repo spins up OpenSearch + OpenSearch Dashboards for development, with:

- Persistent data via a named volume (`os-data`).
- Local filesystem snapshots in `./snapshots` for backup/restore.
- Scripts to export/import Dashboards saved objects.
- Makefile helpers to streamline common tasks.

Quick start
-----------

- Start stack: `make up`
- Start with auto-restore: `make up-auto` (enables `init-restore`)
- Stop stack: `make down`
- Check services: `make ps`
- Tail logs: `make logs`

Persisting data (recommended)
-----------------------------

- Data persists automatically in the named volume `os-data`.
- Do not run `docker compose down -v` unless you want to delete all data.

Backing up and restoring
------------------------

- Create a snapshot of all indices + global state: `make backup`
  - Snapshots are stored on host under `./snapshots`.
  - Dashboards saved objects are also exported to `./dashboards/export.ndjson`.

- Restore latest snapshot and re-import saved objects: `make restore`
  - Add `REPO=<name>` or `OS_URL`, `OS_USER`, `OS_PASS` to override defaults.
  - To restore a specific snapshot: `./scripts/opensearch-snapshot.sh restore <snap-name>`

Auto-restore on up (optional)
-----------------------------

- The `init-restore` service restores the latest snapshot automatically when the
  cluster has no user indices. It is disabled by default and gated behind the
  `auto-restore` profile.
- Enable it via: `make up-auto` or `docker compose --profile auto-restore up -d`
- It registers the filesystem repo (`/snapshots`) if needed and restores the
  most recent snapshot found under `./snapshots` (as seen by OpenSearch).

Manual scripts
--------------

- List snapshots: `./scripts/opensearch-snapshot.sh list`
- Create snapshot: `./scripts/opensearch-snapshot.sh backup [name]`
- Restore snapshot: `./scripts/opensearch-snapshot.sh restore [name|latest] [--force]`
  - `--force` deletes existing indices before restore.

- Export Dashboards saved objects: `./scripts/dashboards-objects.sh export`
- Import Dashboards saved objects: `./scripts/dashboards-objects.sh import`

Credentials and endpoints
-------------------------

- OpenSearch: `https://localhost:9200`
- Dashboards: `http://localhost:5601`
- Default credentials: `admin` / `ChangeMe_Adm1n!`
  - Change via env vars `OS_USER`, `OS_PASS` when running scripts.

Notes
-----

- Snapshots rely on `path.repo=/snapshots` and the compose bind-mount of `./snapshots`.
- Dashboards saved objects are stored in OpenSearch; exporting is useful for versioning.
- If you delete the `os-data` volume, use `make restore` to repopulate from the latest snapshot.

Sample data: warrants
---------------------

- Generate and load 20 sample warrants into index `warrants`:
  - `make generate-warrants` (creates `data/warrants.ndjson`, recreates index, loads)
- Load existing NDJSON again without regenerating:
  - `make load-warrants`
- Customize:
  - Count: `./scripts/load-warrants.sh --generate 50`
  - Index: `INDEX=my_warrants ./scripts/load-warrants.sh --generate 30`

Geo search and maps
-------------------

- The `warrants` index includes `subject_location` (geo_point) derived from the
  selected jurisdiction with a small jitter. You can query by distance:
  - `./scripts/search-warrants-geo.sh 37.7749 -122.4194 10km` (SF, 10km radius)
  - `INDEX=my_warrants ./scripts/search-warrants-geo.sh 34.0522 -118.2437 25km`

- In OpenSearch Dashboards (Maps):
  - Management > Stack Management > Index Patterns: create one for `warrants*`.
  - Apps > Maps: create a map, add a Documents layer using `subject_location`.
  - Style by `status` or `priority` as desired.

Saved map
---------

- Auto-create a data view for `warrants*` and a saved Map that plots
  `subject_location` points:
  - `make create-warrants-map`
  - Opens at `/app/maps/map/warrants-map` with a basic points layer.
  - Customize title via `TITLE="My Warrants Map" make create-warrants-map`.

Saved dashboard
---------------

- Create a saved search, a pie visualization (Warrants by status), and a
  composed dashboard including the map:
  - `make create-warrants-dashboard`
  - Opens at `/app/dashboards#/view/warrants-overview`
  - Panel types: map, visualization (pie), and saved search (table)
