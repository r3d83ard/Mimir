#!/usr/bin/env bash
set -euo pipefail

# Simple OpenSearch snapshot/restore helper.
# Requires the OpenSearch container to have path.repo=/snapshots and the compose
# to mount ./snapshots -> /snapshots (already in your docker-compose.yml).

OS_URL=${OS_URL:-https://localhost:9200}
OS_USER=${OS_USER:-admin}
OS_PASS=${OS_PASS:-ChangeMe_Adm1n!}
REPO=${REPO:-local_fs}
SNAPSHOT_DIR_HOST=${SNAPSHOT_DIR_HOST:-./snapshots}

curl_os() {
  curl -sS -k -u "$OS_USER:$OS_PASS" -H 'Content-Type: application/json' "$@"
}

ensure_repo() {
  # Ensure snapshots folder exists on host
  mkdir -p "$SNAPSHOT_DIR_HOST"
  # Register repository if it doesn't exist
  local status
  status=$(curl_os -o /dev/null -w '%{http_code}' -X GET "$OS_URL/_snapshot/$REPO") || true
  if [[ "$status" != "200" ]];
  then
    echo "Registering snapshot repository '$REPO' at /snapshots"
    curl_os -X PUT "$OS_URL/_snapshot/$REPO" -d '{
      "type": "fs",
      "settings": {"location": "/snapshots", "compress": true}
    }' | jq -r '.acknowledged // .' 2>/dev/null || true
  fi
}

list_snaps() {
  ensure_repo
  echo "Available snapshots in repo '$REPO':"
  curl_os -X GET "$OS_URL/_snapshot/$REPO/_all" | \
    grep -o '"snapshot":"[^"]*"' | cut -d: -f2 | tr -d '"' | sort || true
}

latest_snap_name() {
  ensure_repo
  curl_os -X GET "$OS_URL/_snapshot/$REPO/_all" | \
    grep -o '"snapshot":"[^"]*"' | cut -d: -f2 | tr -d '"' | sort | tail -1
}

backup_all() {
  ensure_repo
  local snap_name=${1:-snap-$(date +%Y%m%d-%H%M%S)}
  echo "Creating snapshot '$snap_name' (all indices, include_global_state)"
  curl_os -X PUT "$OS_URL/_snapshot/$REPO/$snap_name?wait_for_completion=true" -d '{
    "indices": "*",
    "include_global_state": true,
    "ignore_unavailable": true
  }'
  echo
  echo "Done. Files saved under $SNAPSHOT_DIR_HOST."
}

restore_all() {
  ensure_repo
  local snap_name=${1:-latest}
  local force=${2:-}

  if [[ "$snap_name" == "latest" ]]; then
    snap_name=$(latest_snap_name)
    if [[ -z "$snap_name" ]]; then
      echo "No snapshots found in repo '$REPO'." >&2
      exit 1
    fi
  fi

  if [[ "$force" == "--force" ]]; then
    echo "Deleting all existing indices before restore (force)."
    curl_os -X DELETE "$OS_URL/*" || true
    echo
  fi

  echo "Restoring snapshot '$snap_name' (all indices, include_global_state)"
  curl_os -X POST "$OS_URL/_snapshot/$REPO/$snap_name/_restore?wait_for_completion=true" -d '{
    "indices": "*",
    "include_global_state": true,
    "ignore_unavailable": true,
    "include_aliases": true
  }'
  echo
}

usage() {
  cat <<EOF
Usage: $0 <command> [args]

Commands:
  list                      List snapshots in repository
  backup [name]             Create snapshot (default: snap-YYYYMMDD-HHMMSS)
  restore [name|latest]     Restore snapshot to cluster
    add --force to delete all indices prior to restore

Env vars:
  OS_URL (default https://localhost:9200)
  OS_USER (default admin)
  OS_PASS (default ChangeMe_Adm1n!)
  REPO   (default local_fs)
  SNAPSHOT_DIR_HOST (default ./snapshots)
EOF
}

cmd=${1:-}
case "$cmd" in
  list)
    list_snaps ;;
  backup)
    backup_all "${2:-}" ;;
  restore)
    restore_all "${2:-latest}" "${3:-}" ;;
  *)
    usage ; exit 1 ;;
esac

