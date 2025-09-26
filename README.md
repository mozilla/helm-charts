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

## Setup
Run `make install` to ensure both `uv` and `pre-commit` are installed.

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
