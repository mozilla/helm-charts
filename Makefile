UV_CHECK := $(shell command -v uv 2>/dev/null)
CHART_KIT = uv run --directory ./scripts chartkit 
DRY_RUN ?= 0
ifeq ($(DRY_RUN),1)
	DRY_RUN_ARG = --dry-run
else
	DRY_RUN_ARG =
endif

%:
	@:

args = `arg="$(filter-out $@,$(MAKECMDGOALS))" && echo $${arg:-${1}}`

.PHONY: install, update-dependencies, bump-charts

install:
ifndef UV_CHECK
	@echo "uv is not installed. Please install uv"
	@exit 1
endif
	@echo "Installing pre-commit hooks..."
	@pre-commit install

update-dependencies:
	$(CHART_KIT) update-dependencies $(DRY_RUN_ARG) $(call args, '--all')

bump-charts:
	$(CHART_KIT) version bump $(DRY_RUN_ARG) $(call args, '--staged')
