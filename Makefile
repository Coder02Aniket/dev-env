SHELL := /bin/bash

ROOT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
COMPOSE := docker compose -f "$(ROOT)/infra/compose.yaml" --env-file "$(ROOT)/infra/.env"

.PHONY: help bootstrap verify up down ps logs pull clean

help:
	@echo "bootstrap  run the full setup"
	@echo "verify     print tool versions and service health"
	@echo "up         start services (all, or S=name)"
	@echo "down       stop services, keep volumes"
	@echo "ps         service status and ports"
	@echo "logs       follow logs (S=name optional)"
	@echo "pull       pre-pull service images"
	@echo "clean      stop services and remove volumes"

bootstrap:
	@bash "$(ROOT)/bootstrap.sh"

verify:
	@bash "$(ROOT)/lib/verify.sh"

$(ROOT)/infra/.env:
	@cp "$(ROOT)/infra/.env.example" "$(ROOT)/infra/.env"

up: $(ROOT)/infra/.env
	@$(COMPOSE) up -d $(S)

down: $(ROOT)/infra/.env
	@$(COMPOSE) down

ps: $(ROOT)/infra/.env
	@$(COMPOSE) ps

logs: $(ROOT)/infra/.env
	@$(COMPOSE) logs -f $(S)

pull: $(ROOT)/infra/.env
	@$(COMPOSE) pull

clean: $(ROOT)/infra/.env
	@$(COMPOSE) down -v
