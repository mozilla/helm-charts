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

.PHONY: install, update-dependencies, bump-charts, unit-tests

install:
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

update-dependencies:
	$(CHART_KIT) update-dependencies $(DRY_RUN_ARG) $(call args, '--all')

bump-charts:
	$(CHART_KIT) version bump $(DRY_RUN_ARG) $(call args, '--staged')

unit-tests:
	@echo "$(UNIT_TEST_MESSAGE)"
	@bash -c 'find **/application -type f -name "Chart.yaml" -exec dirname {} \; | xargs -I {} helm unittest {} -s $(UPDATE_SNAPSHOTS_ARG)'
