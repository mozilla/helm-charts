# ChartKit - CLI tooling for managing Helm charts and dependencies

Requires `uv` to run.

```sh
$ uv run chartkit --help
Usage: chartkit [OPTIONS] COMMAND [ARGS]...

  ChartKit: CLI tooling for Helm chart dependencies and utilities.

Options:
  -r, --roots TEXT  Root directories to scan for Helm charts. Can be specified
                    multiple times.
  --internal-only   Only include dependencies that are also found in the
                    scanned charts.
  --version         Show the version and exit.
  --help            Show this message and exit.

Commands:
  chart    Prints Helm either a single chart details or the a tree of...
  charts   Prints Helm chart dependencies.
  mermaid  Generates a diagram of Helm chart dependencies.
  version  Manage chart versions..
```

## Charts Command
Collects and generates a depenency graph for the given root paths.
```sh
$ uv run chartkit charts --help
Usage: chartkit charts [OPTIONS]

  Prints Helm chart dependencies.

Options:
  --json  Output as JSON.
  --help  Show this message and exit.
```

## Chart Command
Displays information about a single chart. Can print dependency/dependent tree for the given chart or chart details.
```sh
$ uv run chartkit chart --help                                    
Usage: chartkit chart [OPTIONS] CHART

  Prints Helm either a single chart details or the a tree of dependents or
  dependencies.

Options:
  --json                          Output as JSON.
  --mode [dependency|dependent|info]
                                  Type of tree to display.
  --help                          Show this message and exit.
```

#### View the depency tree of a single chart
```sh
uv run chartkit chart mozcloud-preview --mode dependency
```

## Mermaid Command
Generates mermaid charts of the previously selected chart dependency graph
```sh
$ uv run chartkit mermaid --help
Usage: chartkit mermaid [OPTIONS] [CHART]

  Generates a diagram of Helm chart dependencies.

Options:
  --include-attrs    Include chart attributes (version, type) in the diagram.
  --output TEXT      Text output file for the diagram.
  --svg-output TEXT  SVG output file for the diagram.
  --help             Show this message and exit.
```

#### Generate mermaid chart to stdout
```sh
uv run chartkit mermaid
```

#### Generate mermaid chart svg
```sh
uv run chartkit mermaid --svg-output mozcloud-workload.svg mozcloud-workload 
```

## Version Management
`chartkit` can be used to manage the version of individual charts and cascade those version updates across dependent charts.

#### List dependent tree and version details
This shows a list of charts that are dependent on a single chart or a list of charts and their version information.
```sh
$ uv run chartkit version list --help
Usage: chartkit version list [OPTIONS] CHARTS...

  Lists the versions of all charts.

Options:
  --help  Show this message and exit.
```

##### Example
```sh
uv run chartkit version list mozcloud-workload
```

#### Bump version
```sh
$ uv run chartkit version bump --help
Usage: chartkit version bump [OPTIONS] [CHARTS]...

  Bumps the version of a chart and cascades to dependents.

Options:
  --part [major|minor|patch]  Part of the version to bump.
  --dry-run                   Show what would be changed, but do not write
                              changes.
  --json                      Output results as JSON.
  --help                      Show this message and exit.
```
##### Example
For example you can take a list of changed charts and update all their versions and dependencies in one command:
```sh
$ uv run chartkit version bump \
    mozcloud-gateway \
    mozcloud-gateway-lib \
    mozcloud-preview-lib
Updating chart versions:
mozcloud-gateway: 0.4.3
    - dependency: mozcloud-gateway-lib -> 0.4.3
mozcloud-gateway-lib: 0.4.3
mozcloud-preview: 0.3.12
    - dependency: mozcloud-preview-lib -> 0.2.13
mozcloud-preview-lib: 0.2.13
    - dependency: mozcloud-gateway-lib -> 0.4.3
mozcloud-workload: 0.0.3
    - dependency: mozcloud-gateway-lib -> 0.4.3
Chart versions updated. 
```

