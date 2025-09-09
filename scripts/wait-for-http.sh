#!/usr/bin/env bash
set -euo pipefail

# Usage: wait-for-http.sh <url> [--insecure] [--timeout <seconds>]

URL=${1:-}
[[ -z "$URL" ]] && { echo "URL required" >&2; exit 1; }

INSECURE=0
TIMEOUT=${TIMEOUT:-120}

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --insecure) INSECURE=1; shift ;;
    --timeout) TIMEOUT=${2:-120}; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

echo -n "Waiting for $URL ..."
for i in $(seq 1 "$TIMEOUT"); do
  if [[ $INSECURE -eq 1 ]]; then
    if curl -fsSk "$URL" >/dev/null 2>&1; then echo " ready"; exit 0; fi
  else
    if curl -fsS "$URL" >/dev/null 2>&1; then echo " ready"; exit 0; fi
  fi
  echo -n "."; sleep 1
done
echo "\nTimeout waiting for $URL" >&2
exit 1

