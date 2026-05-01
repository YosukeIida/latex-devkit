SHELL := /bin/bash

WORKSPACE_ROOT ?= $(CURDIR)
export WORKSPACE_ROOT
LATEX_PROJECTS_DIR ?=
export LATEX_PROJECTS_DIR
PROJECTS_DIR := $(if $(LATEX_PROJECTS_DIR),$(LATEX_PROJECTS_DIR),$(WORKSPACE_ROOT)/projects)
SECRETS_DIR ?= $(WORKSPACE_ROOT)/.secrets
COOKIE_PATH ?= $(SECRETS_DIR)/.olauth

COMPOSE_FILE := $(CURDIR)/compose.yaml
COMPOSE := docker compose -f "$(COMPOSE_FILE)"
SERVICE := texd
TEXLIVE_IMAGE_REPO ?= texlive/texlive
TEXLIVE_IMAGE_TAG ?= TL2024-historic
TEXLIVE_IMAGE := $(TEXLIVE_IMAGE_REPO):$(TEXLIVE_IMAGE_TAG)

PROJ ?=
MAIN ?= main.tex
BRANCH ?= main
NAME ?=
OLIGNORE ?= .olignore
DOWNLOAD_DIR ?= build

LLEAF_BASE = uv run --project "$(CURDIR)" lleaf --cookie-path "$(COOKIE_PATH)"
LLEAF_NAME = $(if $(strip $(NAME)),-n "$(NAME)",)

.PHONY: help
help:
	@echo "Targets:"
	@echo "  make up"
	@echo "  make pull-image"
	@echo "  make down"
	@echo "  make ps"
	@echo "  make build-local PROJ=<project> MAIN=<file.tex>"
	@echo "  make watch-local PROJ=<project> MAIN=<file.tex>"
	@echo "  make git-push-all PROJ=<project> BRANCH=main"
	@echo "  make lleaf-login"
	@echo "  make lleaf-pull PROJ=<project> [NAME='Overleaf Name']"
	@echo "  make lleaf-push PROJ=<project> [NAME='Overleaf Name']"
	@echo "  make lleaf-download PROJ=<project> [NAME='Overleaf Name']"
	@echo "  make vscode-init PROJ=<project>"

.PHONY: up pull-image down ps

up:
	$(call REQUIRE_CMD,docker)
	TEXLIVE_IMAGE_REPO="$(TEXLIVE_IMAGE_REPO)" TEXLIVE_IMAGE_TAG="$(TEXLIVE_IMAGE_TAG)" $(COMPOSE) up -d $(SERVICE)

pull-image:
	$(call REQUIRE_CMD,docker)
	TEXLIVE_IMAGE_REPO="$(TEXLIVE_IMAGE_REPO)" TEXLIVE_IMAGE_TAG="$(TEXLIVE_IMAGE_TAG)" $(COMPOSE) pull $(SERVICE)

down:
	$(call REQUIRE_CMD,docker)
	$(COMPOSE) down

ps:
	$(call REQUIRE_CMD,docker)
	$(COMPOSE) ps

.PHONY: build-local
build-local:
	$(call REQUIRE_CMD,docker)
	$(call REQUIRE_PROJ)
	$(call REQUIRE_LATEXMKRC)
	$(call EXEC_IN_TEXD,latexmk -norc -r latexmkrc -interaction=nonstopmode "$(MAIN)")

.PHONY: watch-local
watch-local:
	$(call REQUIRE_CMD,fswatch)
	$(call REQUIRE_PROJ)
	@cd "$(PROJECTS_DIR)/$(PROJ)" && "$(CURDIR)/bin/watch-docker" "$(MAIN)"

.PHONY: git-push-all
git-push-all:
	$(call REQUIRE_CMD,git)
	$(call REQUIRE_PROJ)
	@cd "$(PROJECTS_DIR)/$(PROJ)" && git push origin "$(BRANCH)"
	@cd "$(PROJECTS_DIR)/$(PROJ)" && \
	if git remote get-url overleaf >/dev/null 2>&1; then \
	  git push overleaf "$(BRANCH)"; \
	else \
	  echo "INFO: remote 'overleaf' is not configured. Skipped."; \
	fi

.PHONY: lleaf-login
lleaf-login:
	$(call REQUIRE_CMD,uv)
	@mkdir -p "$(SECRETS_DIR)"
	uv run lleaf --cookie-path "$(COOKIE_PATH)" login

.PHONY: lleaf-pull
lleaf-pull:
	$(call REQUIRE_CMD,uv)
	$(call REQUIRE_PROJ)
	$(call REQUIRE_COOKIE)
	$(call REQUIRE_OLIGNORE)
	$(call RUN_IN_PROJ,$(LLEAF_BASE) pull $(LLEAF_NAME) -i "$(OLIGNORE)")

.PHONY: lleaf-push
lleaf-push:
	$(call REQUIRE_CMD,uv)
	$(call REQUIRE_PROJ)
	$(call REQUIRE_COOKIE)
	$(call REQUIRE_OLIGNORE)
	$(call RUN_IN_PROJ,$(LLEAF_BASE) push $(LLEAF_NAME) -i "$(OLIGNORE)")

.PHONY: lleaf-download
lleaf-download:
	$(call REQUIRE_CMD,uv)
	$(call REQUIRE_PROJ)
	$(call REQUIRE_COOKIE)
	$(call REQUIRE_OLIGNORE)
	$(call RUN_IN_PROJ,mkdir -p "$(DOWNLOAD_DIR)")
	$(call RUN_IN_PROJ,$(LLEAF_BASE) download $(LLEAF_NAME) --download-path "$(DOWNLOAD_DIR)" -i "$(OLIGNORE)")
	@echo "Downloaded into: $(PROJECTS_DIR)/$(PROJ)/$(DOWNLOAD_DIR)/"

.PHONY: vscode-init
vscode-init:
	$(call REQUIRE_PROJ)
	@mkdir -p "$(PROJECTS_DIR)/$(PROJ)/.vscode"
	@sed "s|LATEX_DEVKIT_DIR|$(CURDIR)|g" "$(CURDIR)/templates/vscode/settings.json" \
	  > "$(PROJECTS_DIR)/$(PROJ)/.vscode/settings.json"
	@echo "Installed VS Code settings: $(PROJECTS_DIR)/$(PROJ)/.vscode/settings.json"

define REQUIRE_CMD
	@if ! command -v $(1) >/dev/null 2>&1; then \
	  echo "ERROR: command not found: $(1)"; \
	  exit 2; \
	fi
endef

define REQUIRE_PROJ
	@if [ -z "$(strip $(PROJ))" ]; then \
	  echo "ERROR: PROJ is required"; \
	  exit 2; \
	fi
	@if [ ! -d "$(PROJECTS_DIR)/$(PROJ)" ]; then \
	  echo "ERROR: project not found: $(PROJECTS_DIR)/$(PROJ)"; \
	  exit 2; \
	fi
endef

define REQUIRE_LATEXMKRC
	@if [ ! -f "$(PROJECTS_DIR)/$(PROJ)/latexmkrc" ]; then \
	  echo "ERROR: latexmkrc not found in $(PROJECTS_DIR)/$(PROJ)"; \
	  exit 2; \
	fi
endef

define REQUIRE_SERVICE_RUNNING
	@if ! $(COMPOSE) ps --status running --services | grep -qx "$(SERVICE)"; then \
	  echo "ERROR: $(SERVICE) is not running."; \
	  echo "Hint: run 'make up' first."; \
	  exit 2; \
	fi
endef

define REQUIRE_COOKIE
	@if [ ! -f "$(COOKIE_PATH)" ]; then \
	  echo "ERROR: cookie not found: $(COOKIE_PATH)"; \
	  echo "Hint: run make lleaf-login"; \
	  exit 2; \
	fi
endef

define REQUIRE_OLIGNORE
	@if [ ! -f "$(PROJECTS_DIR)/$(PROJ)/$(OLIGNORE)" ]; then \
	  echo "ERROR: $(OLIGNORE) not found in $(PROJECTS_DIR)/$(PROJ)"; \
	  exit 2; \
	fi
endef

define RUN_IN_PROJ
	@cd "$(PROJECTS_DIR)/$(PROJ)" && bash -lc '$(1)'
endef

define EXEC_IN_TEXD
	@$(COMPOSE) run --rm -T $(SERVICE) bash -lc 'TEXBIN="$$(ls -d /usr/local/texlive/*/bin/* 2>/dev/null | head -n 1)"; if [ -n "$$TEXBIN" ]; then export PATH="$$TEXBIN:$$PATH"; fi; cd "/workspace/projects/$(PROJ)" && $(1)'
endef
