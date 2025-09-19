#!/usr/bin/env bash
set -euo pipefail

# Create a Data View for warrants* and a Maps saved object that plots
# points from field `subject_location`.

DASH_URL=${DASH_URL:-http://localhost:5601}
OS_USER=${OS_USER:-admin}
OS_PASS=${OS_PASS:-ChangeMe_Adm1n!}
TITLE=${TITLE:-Warrants — Subject Locations}
INDEX_PATTERN_TITLE=${INDEX_PATTERN_TITLE:-warrants*}
TIME_FIELD=${TIME_FIELD:-issue_date}
MAP_ID=${MAP_ID:-warrants-map}
DATA_VIEW_ID=${DATA_VIEW_ID:-warrants-dv}

wait_ready() {
  echo -n "Waiting for Dashboards at $DASH_URL ..."
  for i in {1..120}; do
    if curl -fsS -u "$OS_USER:$OS_PASS" "$DASH_URL/api/status" >/dev/null 2>&1; then echo " ready"; return 0; fi
    echo -n "."; sleep 2
  done
  echo "\nTimeout waiting for $DASH_URL" >&2
  exit 1
}

curl_dash() {
  curl -sS -u "$OS_USER:$OS_PASS" -H 'osd-xsrf: true' "$@"
}

create_data_view() {
  echo "Creating data view '$INDEX_PATTERN_TITLE' (time field: $TIME_FIELD) as id $DATA_VIEW_ID"
  # Use saved_objects API directly (works with OSD 2.x)
  curl_dash -H 'Content-Type: application/json' \
    -X POST "$DASH_URL/api/saved_objects/index-pattern/$DATA_VIEW_ID?overwrite=true" \
    -d "{\"attributes\":{\"title\":\"$INDEX_PATTERN_TITLE\",\"timeFieldName\":\"$TIME_FIELD\"}}" >/dev/null
  echo "$DATA_VIEW_ID"
}

create_map() {
  local dv_id=$1
  echo "Creating map '$TITLE' with data view id $dv_id (id: $MAP_ID)"
  # Prepare layer list JSON string (keep minimal properties for compatibility)
  local layer
  layer=$(cat <<JSON
[
  {
    "id": "layer-warrants-points",
    "type": "VECTOR",
    "alpha": 1,
    "visible": true,
    "minZoom": 0,
    "maxZoom": 24,
    "sourceDescriptor": {
      "type": "ES_SEARCH",
      "indexPatternId": "$dv_id",
      "geoField": "subject_location",
      "filterByMapBounds": true,
      "scalingType": "MVT"
    },
    "style": { "type": "VECTOR" }
  }
]
JSON
)

  local map_state
  map_state='{"zoom":3,"center":{"lon":-98.35,"lat":39.5}}'

  # Escaped JSON for payload
  local payload
  payload=$(python3 - <<'PY'
import json, os, sys
title = os.environ['TITLE']
layer = os.environ['LAYER']
map_state = os.environ['MAP_STATE']
body = {
  "attributes": {
    "title": title,
    "description": "Auto-generated map of warrants subject_location",
    "layerListJSON": layer,
    "mapStateJSON": map_state,
    "uiStateJSON": "{}"
  },
  "references": []
}
print(json.dumps(body))
PY
)

  curl_dash -H 'Content-Type: application/json' \
    -X POST "$DASH_URL/api/saved_objects/map/$MAP_ID?overwrite=true" \
    -d "$payload" >/dev/null
  echo "Map created. Open: $DASH_URL/app/maps/map/$MAP_ID"
}

wait_ready
DV_ID=$(create_data_view)
LAYER=$(cat <<JSON
[
  {
    "id": "layer-warrants-points",
    "type": "VECTOR",
    "alpha": 1,
    "visible": true,
    "minZoom": 0,
    "maxZoom": 24,
    "sourceDescriptor": {
      "type": "ES_SEARCH",
      "indexPatternId": "$DV_ID",
      "geoField": "subject_location",
      "filterByMapBounds": true,
      "scalingType": "MVT"
    },
    "style": { "type": "VECTOR" }
  }
]
JSON
)
MAP_STATE='{"zoom":3,"center":{"lon":-98.35,"lat":39.5}}'

TITLE="$TITLE" LAYER="$LAYER" MAP_STATE="$MAP_STATE" create_map "$DV_ID"
