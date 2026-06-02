SHELL := /bin/bash
SECRET := demo-only-change-me-0123456789abcdef
# Mint tokens offline. Override DATABASE_URL so settings validation doesn't try
# to create the container's /data dir (read-only on the host).
MINT := DATABASE_URL=sqlite:///./.tokmint.db uv run --with mcp-contextforge-gateway -- python -m mcpgateway.utils.create_jwt_token
COMPOSE := docker compose

.PHONY: help up up-full down seed token token-bob logs verify-controls demo-reset ps

help:
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n",$$1,$$2}'

.env:
	cp .env.example .env

token: ## Print an admin JWT
	@$(MINT) -u admin@finbyte.demo --admin -e 10080 -s $(SECRET)

token-bob: ## Print Bob's JWT (paste into .bob/mcp.json)
	@$(MINT) -u bob@finbyte.demo --admin -e 10080 -s $(SECRET)

up: .env ## Build + start the lite stack
	@echo "AUDITOR_TOKEN=$$($(MINT) -u auditor@finbyte.demo --admin -e 10080 -s $(SECRET))" > .env.tokens
	$(COMPOSE) --env-file .env.tokens up -d --build
	@echo "waiting for gateway health..."; \
	for i in $$(seq 1 40); do curl -sf localhost:4444/health >/dev/null 2>&1 && { echo "gateway healthy"; break; } || sleep 2; done

up-full: .env ## Start the full presenter stack (postgres/redis/nginx/phoenix)
	@echo "AUDITOR_TOKEN=$$($(MINT) -u auditor@finbyte.demo --admin -e 10080 -s $(SECRET))" > .env.tokens
	$(COMPOSE) --env-file .env.tokens -f docker-compose.yml -f docker-compose.full.yml up -d --build

seed: ## Register servers/agents + build FinOps/Treasury virtual servers
	@ADMIN_TOKEN=$$($(MINT) -u admin@finbyte.demo --admin -e 10080 -s $(SECRET)) \
	  uv run --with httpx python gateway/seed/seed.py

verify-controls: ## Run the 4 money-shot proof scripts (assert block/allow)
	@bash scripts/money-shots/run-all.sh

demo-reset: ## Reset fixtures + clear rate-limit lockouts between runs
	$(COMPOSE) restart gateway expense-db
	@echo "reset done"

logs: ## Tail gateway logs
	$(COMPOSE) logs -f gateway

ps: ## Show running services
	$(COMPOSE) ps

down: ## Stop the stack
	$(COMPOSE) down
