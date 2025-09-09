#!/usr/bin/env bash
set -euo pipefail

# Export/import OpenSearch Dashboards saved objects (dashboards, visualizations, etc.).

DASH_URL=${DASH_URL:-http://localhost:5601}
OS_USER=${OS_USER:-admin}
OS_PASS=${OS_PASS:-ChangeMe_Adm1n!}
EXPORT_FILE=${EXPORT_FILE:-dashboards/export.ndjson}

mkdir -p "$(dirname "$EXPORT_FILE")"

curl_dash() {
  curl -sS -u "$OS_USER:$OS_PASS" -H 'kbn-xsrf: true' "$@"
}

wait_ready() {
  echo -n "Waiting for Dashboards at $DASH_URL ..."
  for i in {1..120}; do
    if curl -fsS "$DASH_URL/api/status" >/dev/null 2>&1; then
      echo " ready"; return 0
    fi
    echo -n "."; sleep 2
  done
  echo "\nTimeout waiting for $DASH_URL" >&2
  return 1
}

export_all() {
  wait_ready
  echo "Exporting saved objects to $EXPORT_FILE"
  curl_dash -H 'Content-Type: application/json' \
    -X POST "$DASH_URL/api/saved_objects/_export" \
    -d '{
      "type": [
        "dashboard","visualization","search","index-pattern",
        "lens","map","canvas-workpad","query","tag"
      ],
      "includeReferencesDeep": true
    }' \
    > "$EXPORT_FILE"
  echo "Done."
}

import_all() {
  wait_ready
  if [[ ! -f "$EXPORT_FILE" ]]; then
    echo "Export file not found: $EXPORT_FILE" >&2
    exit 1
  fi
  echo "Importing saved objects from $EXPORT_FILE (overwrite=true)"
  curl_dash -H 'kbn-xsrf: true' \
    -F "file=@$EXPORT_FILE" \
    "$DASH_URL/api/saved_objects/_import?overwrite=true"
  echo
}

usage() {
  cat <<EOF
Usage: $0 <export|import>

Env vars:
  DASH_URL (default http://localhost:5601)
  OS_USER  (default admin)
  OS_PASS  (default ChangeMe_Adm1n!)
  EXPORT_FILE (default dashboards/export.ndjson)
EOF
}

case "${1:-}" in
  export) export_all ;;
  import) import_all ;;
  *) usage; exit 1 ;;
esac

