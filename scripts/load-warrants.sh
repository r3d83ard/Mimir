#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

INDEX=${INDEX:-warrants}
FILE=${FILE:-$PROJECT_ROOT/data/warrants.ndjson}
OS_URL=${OS_URL:-https://localhost:9200}
OS_USER=${OS_USER:-admin}
OS_PASS=${OS_PASS:-ChangeMe_Adm1n!}
RECREATE=${RECREATE:-1}

mkdir -p "$(dirname "$FILE")"

curl_es() {
  curl -sS -k -u "$OS_USER:$OS_PASS" "$@"
}

ensure_ready() {
  echo -n "Waiting for OpenSearch at $OS_URL ..."
  for i in {1..120}; do
    if curl -fsSk -u "$OS_USER:$OS_PASS" "$OS_URL" >/dev/null 2>&1; then echo " ready"; return 0; fi
    echo -n "."; sleep 1
  done
  echo "\nTimeout waiting for $OS_URL" >&2
  exit 1
}

create_index() {
  local mapping='{
    "settings": {"number_of_replicas": 0},
    "mappings": {
      "properties": {
        "warrant_id": {"type": "keyword"},
        "title": {"type": "text", "fields": {"keyword": {"type": "keyword", "ignore_above": 256}}},
        "description": {"type": "text"},
        "status": {"type": "keyword"},
        "issue_date": {"type": "date"},
        "expiry_date": {"type": "date"},
        "jurisdiction": {"type": "keyword"},
        "city": {"type": "keyword"},
        "state": {"type": "keyword"},
        "officer": {"type": "keyword"},
        "subject_name": {"type": "keyword"},
        "subject_address": {"type": "text", "fields": {"keyword": {"type": "keyword", "ignore_above": 256}}},
        "subject_location": {"type": "geo_point"},
        "issuing_state": {"type": "keyword"},
        "issuing_agency": {"type": "keyword"},
        "crime": {"type": "keyword"},
        "crime_category": {"type": "keyword"},
        "severity": {"type": "keyword"},
        "tags": {"type": "keyword"},
        "priority": {"type": "integer"},
        "amount": {"type": "double"}
      }
    }
  }'

  if [[ "$RECREATE" == "1" ]]; then
    echo "Dropping index '$INDEX' (if exists)"
    curl_es -X DELETE "$OS_URL/$INDEX" >/dev/null || true
  fi

  local code
  code=$(curl_es -o /dev/null -w '%{http_code}' "$OS_URL/$INDEX") || true
  if [[ "$code" != "200" ]]; then
    echo "Creating index '$INDEX' with mapping"
    curl_es -H 'Content-Type: application/json' -X PUT "$OS_URL/$INDEX" -d "$mapping" >/dev/null
  else
    echo "Index '$INDEX' already exists (RECREATE=$RECREATE)"
  fi
}

bulk_load() {
  echo "Bulk loading from $FILE into '$INDEX'"
  curl_es -H 'Content-Type: application/x-ndjson' \
    -X POST "$OS_URL/_bulk?refresh=wait_for" --data-binary "@$FILE"
  echo
}

usage() {
  cat <<EOF
Usage: $0 [--generate [COUNT]]

Env vars:
  INDEX   (default warrants)
  FILE    (default data/warrants.ndjson)
  OS_URL  (default https://localhost:9200)
  OS_USER (default admin)
  OS_PASS (default ChangeMe_Adm1n!)
  RECREATE (default 1)  # drop and recreate index

Examples:
  $0 --generate 30    # generate 30 docs and load
  INDEX=mywarrants $0 # load from FILE into custom index
EOF
}

GENERATE=0
GEN_COUNT=20

while [[ $# -gt 0 ]]; do
  case "$1" in
    --generate)
      GENERATE=1
      if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then GEN_COUNT=$2; shift; fi
      shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ "$GENERATE" == "1" ]]; then
  echo "Generating $GEN_COUNT sample documents into $FILE (index=$INDEX)"
  scripts/gen-warrants.py "$INDEX" "$GEN_COUNT" > "$FILE"
fi

ensure_ready
create_index
bulk_load

echo "Done. Explore via: $OS_URL/$INDEX/_search?q=*" 
