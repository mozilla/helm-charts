UV_CHECK := $(shell command -v uv 2>/dev/null)
HELM_CHECK := $(shell command -v helm 2>/dev/null)
HELM_UNITTEST_CHECK := $(shell helm plugin list | grep unittest 2>/dev/null)
CHART_KIT = uv run --directory ./scripts chartkit 
DRY_RUN ?= 0
ifeq ($(DRY_RUN),1)
	DRY_RUN_ARG = --dry-run
else
	DRY_RUN_ARG =
endif

UPDATE_SNAPSHOTS ?= 0
UPDATE_SNAPSHOTS_FLAG := $(filter 1 true yes True Yes TRUE YES,$(UPDATE_SNAPSHOTS))
ifneq ($(UPDATE_SNAPSHOTS_FLAG),)
	UNIT_TEST_MESSAGE = Running unit tests for all charts and creating new snapshots...
	UPDATE_SNAPSHOTS_ARG = -u
else
	UNIT_TEST_MESSAGE = Running unit tests for all charts...
	UPDATE_SNAPSHOTS_ARG =
endif

%:
	@:

args = `arg="$(filter-out $@,$(MAKECMDGOALS))" && echo $${arg:-${1}}`




.PHONY: help install, update-dependencies, bump-charts, unit-tests, clean

.PHONY: help

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

install: ## Install dependencies and pre-commit hooks
ifndef UV_CHECK
	@echo "uv is not installed. Please install uv..."
	@exit 1
endif
ifndef HELM_CHECK
	@echo "helm is not installed. Please install helm..."
	@exit 1
endif
	@echo "Installing pre-commit hooks..."
	@pre-commit install
ifndef HELM_UNITTEST_CHECK
	@echo "Installing unittest Helm plugin..."
	@helm plugin install https://github.com/helm-unittest/helm-unittest.git
else
	@echo "Updating unittest Helm plugin..."
	@helm plugin update unittest
endif

update-dependencies: ## Update chart dependencies (args: chart path or --all, set DRY_RUN=1 for dry run)
	$(CHART_KIT) update-dependencies $(DRY_RUN_ARG) $(call args, '--all')

bump-charts: ## Bump chart versions (args: chart path or --staged, set DRY_RUN=1 for dry run)
	$(CHART_KIT) version bump $(DRY_RUN_ARG) $(call args, '--staged')

unit-tests: ## Run unit tests for all charts (set UPDATE_SNAPSHOTS=1 to update snapshots)
	@missing=$$(find **/application -type f -name "Chart.yaml" -exec dirname {} \; | while read dir; do [ ! -d "$$dir/charts" ] && echo "$$dir"; done); \
	if [ -n "$$missing" ]; then \
		echo "Dependencies not found in: $$missing"; \
		echo "Running update-dependencies..."; \
		$(MAKE) update-dependencies; \
	fi
	@echo "$(UNIT_TEST_MESSAGE)"
	@bash -c 'find **/application -type f -name "Chart.yaml" -exec dirname {} \; | xargs -I {} helm unittest {} -s $(UPDATE_SNAPSHOTS_ARG)'

clean: ## Remove all downloaded chart dependencies
	@echo "Removing downloaded chart dependencies..."
	@find **/application -type d -name "charts" -exec rm -rf {} + 2>/dev/null || true
	@echo "Clean complete"
