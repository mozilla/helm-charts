# CLI tooling for managing helm charts and dependencies

Requires `uv` to run.

```sh
uv run ./scripts/cli.py --help
```

## Charts Command
Collects and generates a depenency graph for the given root paths.

#### View the depency tree of a single chart
```sh
uv run ./scripts/cli.py -r ./ -c mozcloud-kit
```

## Mermaid Chart subcommand
Generates mermaid charts of the previously selected chart dependency graph

#### Generate mermaid chart to stdout
```sh
uv run ./scripts/cli.py -r ./ -c mozcloud-kit mermaid
```

#### Generate mermaid chart svg
```sh
uv run ./scripts/cli.py -r ./ -c mozcloud-kit mermaid --svg-output mozcloud-kit.svg
```