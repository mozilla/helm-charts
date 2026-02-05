# helm-charts
Reusable Helm templates for Kubernetes workloads

## Requirements
### `uv`
Development workflows require [`uv`](https://docs.astral.sh/uv/)

### `pre-commit`
We use pre-commit to provide a useful signal that versions need to be bumped
```sh
uv tool install pre-commit
```

### `helm`
[Helm](https://helm.sh/docs/intro/install/) must be installed for unit tests to run

## Setup
Run `make install` to ensure `uv`, `pre-commit`, and `helm` are installed.

Additionally, this will install/update the `unittest` Helm plugin.

### helm-docs
`helm-docs` is required during pre-commit runs, installation methods vary by OS:
- MacOS: `brew install norwoodj/tap/helm-docs`
- Go: `go install github.com/norwoodj/helm-docs/cmd/helm-docs@latest`
- Additional info available in repo: https://github.com/norwoodj/helm-docs

## Development Helpers

### `make update-dependencies`
Update the helm dependencies of all the charts. Does a depth first travels of the depenency tree to update all chart dependencies. Can be dry-run by setting `DRY_RUN=1`
```sh
make update-dependencies DRY_RUN=1
```

### `make bump-charts`
By default it will bump the chart versions of the charts that are staged to be committed. This works well in tandem with the `pre-commit` hook that checks if charts need a version bump. It is also possible to pass individual chart names to the make target.
Default:
```sh
make bump-charts
```
With arguments:
```sh
make bump-charts mozcloud-preview-lib
```

### `make unit-tests`
This will run the unit tests for all application charts. Run `make install` if the `unittest` Helm plugin is not installed.

Run unit tests:
```sh
make unit-tests
```

Run unit tests and update snapshots:
```sh
make unit-tests UPDATE_SNAPSHOTS=1  # The following all translate as "true": 1, true, yes
```
