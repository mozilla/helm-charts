cwd = $(shell pwd)

update_dependencies:
	for chart in shared-data labels service workload-core; do \
		pushd mozcloud-$$chart/library; \
		helm dependencies update; \
		popd; \
	done; \
	for chart in gateway ingress job preview workload-stateless; do \
		pushd mozcloud-$$chart/library; \
		helm dependencies update; \
		popd; \
		pushd mozcloud-$$chart/application; \
		helm dependencies update; \
		popd; \
	done; \
	pushd mozcloud-workload/application; \
	helm dependencies update; \
	popd

.PHONY: update_dependencies
