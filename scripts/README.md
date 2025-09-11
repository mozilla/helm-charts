# CLI tooling for managing helm charts and dependencies

Requires `uv` to run.

```sh
$ uv run ./scripts/cli.py --help

Usage: cli.py [OPTIONS] COMMAND [ARGS]...

  CLI tool for helm-charts scripts.

Options:
  --help  Show this message and exit.

Commands:
  charts  Prints Helm chart dependencies.

```

## Charts Command
Collects and generates a depenency graph for the given root paths.
```sh
$ uv run ./scripts/cli.py charts --help

Usage: cli.py charts [OPTIONS] COMMAND [ARGS]...

  Prints Helm chart dependencies.

Options:
  -r, --roots TEXT       Root directories to scan for Helm charts. Can be
                         specified multiple times.
  --internal-only        Only include dependencies that are also found in the
                         scanned charts.
  -c, --root-chart TEXT  If specified, only show the dependency tree for this
                         root chart.
  --help                 Show this message and exit.

Commands:
  mermaid  Generates a diagram of Helm chart dependencies.
```

#### View the depency tree of a single chart
```sh
uv run ./scripts/cli.py charts -r ./ -c mozcloud-kit
```

## Mermaid Chart subcommand
Generates mermaid charts of the previously selected chart dependency graph
```sh
$ uv run ./scripts/cli.py charts mermaid --help
Usage: cli.py charts mermaid [OPTIONS]

  Generates a diagram of Helm chart dependencies.

Options:
  --include-attrs    Include chart attributes (version, type) in the diagram.
  --output TEXT      Output file for the diagram.
  --svg-output TEXT  Output file for the diagram.
  --help             Show this message and exit.
```

#### Generate mermaid chart to stdout
```sh
uv run ./scripts/cli.py charts -r ./ -c mozcloud-kit mermaid
```

#### Generate mermaid chart svg
```sh
uv run ./scripts/cli.py charts -r ./ -c mozcloud-kit mermaid --svg-output mozcloud-kit.svg
```