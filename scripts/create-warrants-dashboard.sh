#!/usr/bin/env bash
set -euo pipefail

DASH_URL=${DASH_URL:-http://localhost:5601}
OS_USER=${OS_USER:-admin}
OS_PASS=${OS_PASS:-ChangeMe_Adm1n!}
INDEX_PATTERN_TITLE=${INDEX_PATTERN_TITLE:-warrants*}
TIME_FIELD=${TIME_FIELD:-issue_date}
DATA_VIEW_ID=${DATA_VIEW_ID:-warrants-dv}

MAP_ID=${MAP_ID:-warrants-map}
SEARCH_ID=${SEARCH_ID:-warrants-search}
VIZ_ID=${VIZ_ID:-warrants-by-severity}
DASH_ID=${DASH_ID:-warrants-overview}

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

ensure_data_view() {
  echo "Ensuring data view '$INDEX_PATTERN_TITLE' exists as id $DATA_VIEW_ID"
  # Create/overwrite via saved_objects API
  curl_dash -H 'Content-Type: application/json' \
    -X POST "$DASH_URL/api/saved_objects/index-pattern/$DATA_VIEW_ID?overwrite=true" \
    -d "{\"attributes\":{\"title\":\"$INDEX_PATTERN_TITLE\",\"timeFieldName\":\"$TIME_FIELD\"}}" >/dev/null
  echo "$DATA_VIEW_ID"
}

ensure_map() {
  echo "Creating/overwriting saved map ($MAP_ID)"
  ./scripts/create-warrants-map.sh >/dev/null
}

create_search() {
  local dv_id=$1
  echo "Creating saved search ($SEARCH_ID)"
  local payload
  payload=$(python3 - <<PY
import json, os
dv=os.environ['DV']
body={
  "attributes": {
    "title": "All Warrants",
    "columns": ["warrant_id","status","jurisdiction","priority","issue_date"],
    "sort": ["issue_date","desc"],
    "kibanaSavedObjectMeta": {
      "searchSourceJSON": json.dumps({
        "index": dv,
        "query": {"language":"kuery","query":""},
        "filter": []
      })
    }
  },
  "references": [
    {"type":"index-pattern","name":"kibanaSavedObjectMeta.searchSourceJSON.index","id": dv}
  ]
}
print(json.dumps(body))
PY
)
  curl_dash -H 'Content-Type: application/json' \
    -X POST "$DASH_URL/api/saved_objects/search/$SEARCH_ID?overwrite=true" \
    -d "$payload" >/dev/null
}

create_viz() {
  local dv_id=$1
  echo "Creating visualization ($VIZ_ID)"
  local payload
  payload=$(python3 - <<PY
import json, os
dv=os.environ['DV']
vis_state={
  "title": "Warrants by severity",
  "type": "pie",
  "aggs": [
    {"id":"1","enabled":True,"type":"count","schema":"metric","params":{}},
    {"id":"2","enabled":True,"type":"terms","schema":"segment","params":{
      "field":"severity","size":10,"order":"desc","orderBy":"1"
    }}
  ],
  "params": {"isDonut": True, "type": "pie", "legendPosition": "right"}
}
body={
  "attributes": {
    "title": "Warrants by severity",
    "visState": json.dumps(vis_state),
    "kibanaSavedObjectMeta": {
      "searchSourceJSON": json.dumps({"index": dv, "query": {"language":"kuery","query":""}, "filter": []})
    }
  },
  "references": [
    {"type":"index-pattern","name":"kibanaSavedObjectMeta.searchSourceJSON.index","id": dv}
  ]
}
print(json.dumps(body))
PY
)
  curl_dash -H 'Content-Type: application/json' \
    -X POST "$DASH_URL/api/saved_objects/visualization/$VIZ_ID?overwrite=true" \
    -d "$payload" >/dev/null
}

create_dashboard() {
  echo "Creating dashboard ($DASH_ID)"
  local payload
  payload=$(python3 - <<'PY'
import json, os
map_id=os.environ['MAP_ID']
viz_id=os.environ['VIZ_ID']
search_id=os.environ['SEARCH_ID']
panels=[
  {
    "panelIndex":"1",
    "type":"map",
    "id": map_id,
    "gridData": {"x":0,"y":0,"w":24,"h":18,"i":"1"},
    "embeddableConfig": {}
  },
  {
    "panelIndex":"2",
    "type":"visualization",
    "id": viz_id,
    "gridData": {"x":24,"y":0,"w":24,"h":18,"i":"2"},
    "embeddableConfig": {}
  },
  {
    "panelIndex":"3",
    "type":"search",
    "id": search_id,
    "gridData": {"x":0,"y":18,"w":48,"h":14,"i":"3"},
    "embeddableConfig": {}
  }
]
body={
  "attributes": {
    "title": "Warrants Overview",
    "description": "Auto-generated dashboard with map, status breakdown, and table",
    "panelsJSON": json.dumps(panels),
    "optionsJSON": json.dumps({"useMargins": True, "hidePanelTitles": False}),
    "timeRestore": True,
    "timeFrom": "now-90d",
    "timeTo": "now",
    "refreshInterval": json.dumps({"pause": True, "value": 0})
  },
  "references": [
    {"type":"map","name":"panel_1","id": map_id},
    {"type":"visualization","name":"panel_2","id": viz_id},
    {"type":"search","name":"panel_3","id": search_id}
  ]
}
print(json.dumps(body))
PY
)
  curl_dash -H 'Content-Type: application/json' \
    -X POST "$DASH_URL/api/saved_objects/dashboard/$DASH_ID?overwrite=true" \
    -d "$payload" >/dev/null
  echo "Dashboard created. Open: $DASH_URL/app/dashboards#/view/$DASH_ID"
}

wait_ready
DV_ID=$(ensure_data_view)
ensure_map
DV="$DV_ID" create_search "$DV_ID"
DV="$DV_ID" create_viz "$DV_ID"
MAP_ID="$MAP_ID" VIZ_ID="$VIZ_ID" SEARCH_ID="$SEARCH_ID" create_dashboard
