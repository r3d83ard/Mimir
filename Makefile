SHELL := /bin/bash

.PHONY: up down ps logs backup restore export-dash import-dash status

up:
	@docker compose up -d
	@./scripts/wait-for-http.sh https://localhost:9200 --insecure --timeout 120
	@./scripts/wait-for-http.sh http://localhost:5601/api/status --timeout 120
	@echo "Stack is up."

up-auto:
	@docker compose --profile auto-restore up -d
	@./scripts/wait-for-http.sh https://localhost:9200 --insecure --timeout 120
	@./scripts/wait-for-http.sh http://localhost:5601/api/status --timeout 120
	@echo "Stack (with auto-restore) is up."

down:
	@docker compose down

ps:
	@docker compose ps

logs:
	@docker compose logs -f opensearch dashboards

backup:
	@./scripts/opensearch-snapshot.sh backup
	@./scripts/dashboards-objects.sh export

restore:
	@./scripts/opensearch-snapshot.sh restore latest
	@./scripts/dashboards-objects.sh import || true

export-dash:
	@./scripts/dashboards-objects.sh export

import-dash:
	@./scripts/dashboards-objects.sh import

status:
	@curl -sSk -u admin:$$OPENSEARCH_INITIAL_ADMIN_PASSWORD https://localhost:9200 | jq . || curl -sSk https://localhost:9200

.PHONY: generate-warrants load-warrants
generate-warrants:
	@./scripts/load-warrants.sh --generate 1000

load-warrants:
	@./scripts/load-warrants.sh

.PHONY: search-geo
search-geo:
	@./scripts/search-warrants-geo.sh 37.7749 -122.4194 10km | head -n 80

.PHONY: create-warrants-map
create-warrants-map:
	@./scripts/create-warrants-map.sh

.PHONY: create-warrants-dashboard
create-warrants-dashboard:
	@./scripts/create-warrants-dashboard.sh
