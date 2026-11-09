SHELL := /bin/bash

ROOT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
DEV := docker compose -f "$(ROOT)/docker-compose.dev.yaml"
INFRA := docker compose -f "$(ROOT)/infra/compose.yaml" --env-file "$(ROOT)/infra/.env"

.PHONY: help bootstrap up down shell logs rebuild image verify \
        services-up services-down services-ps native-bootstrap reset-home

help:
	@echo "bootstrap        install Docker and start the dev container"
	@echo "up               start the dev container"
	@echo "down             stop the dev container"
	@echo "shell            open zsh in the dev container"
	@echo "logs             follow dev container logs"
	@echo "rebuild          rebuild the image and recreate the container"
	@echo "image            build the image only"
	@echo "verify           print tool versions inside the container"
	@echo "services-up      start services (all, or S=name)"
	@echo "services-down    stop services, keep volumes"
	@echo "services-ps      service status"
	@echo "reset-home       delete the dev-home volume (loses logins)"
	@echo "native-bootstrap run the legacy native installer"

bootstrap:
	@bash "$(ROOT)/bootstrap-host.sh"

up:
	@$(DEV) up -d

down:
	@$(DEV) down

shell:
	@docker exec -it dev zsh

logs:
	@$(DEV) logs -f dev

rebuild:
	@$(DEV) up -d --build --force-recreate

image:
	@$(DEV) build

verify:
	@docker exec dev dev-verify

$(ROOT)/infra/.env:
	@cp "$(ROOT)/infra/.env.example" "$(ROOT)/infra/.env"

services-up: $(ROOT)/infra/.env
	@$(INFRA) up -d $(S)

services-down: $(ROOT)/infra/.env
	@$(INFRA) down

services-ps: $(ROOT)/infra/.env
	@$(INFRA) ps

reset-home:
	@echo "removing dev-env_dev-home (this deletes logins and per-container toolchains)"
	@docker volume rm dev-env_dev-home 2>/dev/null || true

native-bootstrap:
	@bash "$(ROOT)/native/bootstrap.sh"
