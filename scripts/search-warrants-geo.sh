#!/usr/bin/env bash
set -euo pipefail

# Simple geo-distance search helper for the warrants index.
# Usage: search-warrants-geo.sh <lat> <lon> [radius]
# Example: ./scripts/search-warrants-geo.sh 37.7749 -122.4194 10km

INDEX=${INDEX:-warrants}
OS_URL=${OS_URL:-https://localhost:9200}
OS_USER=${OS_USER:-admin}
OS_PASS=${OS_PASS:-ChangeMe_Adm1n!}

LAT=${1:-}
LON=${2:-}
RADIUS=${3:-10km}

[[ -z "$LAT" || -z "$LON" ]] && { echo "Usage: $0 <lat> <lon> [radius]" >&2; exit 1; }

read -r -d '' BODY <<JSON
{
  "query": {
    "bool": {
      "filter": {
        "geo_distance": {
          "distance": "$RADIUS",
          "subject_location": {"lat": $LAT, "lon": $LON}
        }
      }
    }
  }
}
JSON

curl -sSk -u "$OS_USER:$OS_PASS" -H 'Content-Type: application/json' \
  -X POST "$OS_URL/$INDEX/_search?pretty" -d "$BODY"

