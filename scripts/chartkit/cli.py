from typing import List, Optional
import click
from semver import Version

from .git import diff_files, git_root, staged_files
from .charts import ChartGraph
from .mermaid import MermaidDiagram
from .versions import VersionManager


@click.group()
@click.option(
    "--roots",
    "-r",
    multiple=True,
    default=[],
    help="Root directories to scan for Helm charts. Can be specified multiple times.",
)
@click.option(
    "--internal-only",
    is_flag=True,
    default=False,
    help="Only include dependencies that are also found in the scanned charts.",
)
@click.version_option(message="ChartKit %(version)s")
@click.pass_context
def cli(ctx: click.Context, roots: list[str], internal_only: bool):
    """ChartKit: CLI tooling for Helm chart dependencies and utilities."""

    # find the git root
    if not roots or len(roots) == 0:
        roots = [git_root().as_posix()]

    ctx.obj = ChartGraph(roots=roots, internal_only=internal_only)


@cli.command()
@click.option("--json", is_flag=True, default=False, help="Output as JSON.")
@click.option("--sort", is_flag=True, default=False, help="Sort charts by depth.")
@click.option("--reverse", is_flag=True, default=False, help="Reverse the sort order.")
@click.pass_obj
def charts(
    graph: ChartGraph,
    json: bool = False,
    sort: bool = False,
    reverse: bool = False,
):
    """Prints Helm chart dependencies."""
    if sort:
        chart_names = graph.sort_by_depth(list(graph.charts.keys()), reverse=reverse)
        graph.print_charts(chart_names, json_output=json)
    else:
        graph.print_dependency_graph(json_output=json)


@cli.command()
@click.option("--json", is_flag=True, default=False, help="Output as JSON.")
@click.option(
    "--mode",
    default="info",
    type=click.Choice(["dependency", "dependent", "info"]),
    help="Type of tree to display.",
)
@click.argument("chart", type=str)
@click.pass_obj
def chart(graph: ChartGraph, chart: str, json: bool, mode: str):
    """Prints Helm either a single chart details or the a tree of dependents or dependencies."""
    if mode == "dependency":
        graph.print_dependency_graph(chart_name=chart, json_output=json)
    elif mode == "dependent":
        graph.print_dependent_graph(chart_name=chart, json_output=json)
    else:
        graph.print_chart_info(chart_name=chart, json_output=json)


@cli.command()
@click.option(
    "--all", is_flag=True, default=False, help="Update all chart dependencies."
)
@click.option(
    "--dry-run",
    is_flag=True,
    default=False,
    help="Show what would be changed, but do not write changes.",
)
@click.argument("charts", nargs=-1, type=str)
@click.pass_obj
def update_dependencies(
    graph: ChartGraph, all: bool, charts: list[str], dry_run: bool = False
):
    """Updates the dependencies for all charts."""
    graph.update_dependencies(charts, all=all, dry_run=dry_run)


@cli.command()
@click.option(
    "--include-attrs",
    is_flag=True,
    default=False,
    help="Include chart attributes (version, type) in the diagram.",
)
@click.option(
    "--output",
    default=None,
    help="Output file for the diagram.",
)
@click.option(
    "--svg-output",
    default=None,
    help="Output file for the diagram.",
)
@click.argument("chart", required=False, type=str)
@click.pass_obj
def mermaid(
    graph: ChartGraph,
    chart: Optional[str] = None,
    include_attrs: bool = False,
    output: Optional[str] = None,
    svg_output: Optional[str] = None,
):
    """Generates a diagram of Helm chart dependencies."""
    diagram = MermaidDiagram(graph, include_attrs, root_chart=chart)
    if output:
        diagram.write_mermaid_to_file(output)

    if svg_output:
        diagram.write_mermaid_to_svg(svg_output)

    if not output and not svg_output:
        click.echo(diagram.mermaid_str)


@cli.command("affected")
@click.option(
    "--base",
    default=None,
    help="Git ref to diff against (e.g. origin/main). Defaults to staged files.",
)
@click.pass_obj
def affected(graph: ChartGraph, base: Optional[str]):
    """List charts affected by file changes (one per line).

    Includes changed charts and all their dependents.
    With no --base, uses staged git files.

    \b
    Examples:
      # Show charts affected by staged changes
      chartkit affected

      # Show charts affected by a PR branch
      chartkit affected --base origin/main

      # Run tests for affected charts
      chartkit affected --base origin/main | chartkit unittest
    """
    files = diff_files(base) if base else staged_files()
    for chart in graph.get_affected_charts(files):
        click.echo(chart)


@cli.command("unittest")
@click.argument("charts", nargs=-1, type=str)
@click.option(
    "--update-snapshot",
    "-u",
    is_flag=True,
    default=False,
    help="Update snapshots.",
)
@click.option(
    "--parallel",
    "-p",
    default=None,
    help="Number of parallel workers (default: CPU count).",
)
@click.option(
    "--verbose",
    is_flag=True,
    default=False,
    envvar="CI",
    help="Verbose output. Enabled automatically when the CI environment variable is set.",
)
@click.pass_obj
def run_unittest(
    graph: ChartGraph,
    charts: tuple,
    update_snapshot: bool,
    parallel: int,
    verbose: bool,
):
    """Run helm unit tests in parallel for all non-deprecated charts.

    If CHART arguments are given, only those charts are tested.
    If no arguments are given, all non-deprecated charts are tested.

    \b
    Examples:
      # Run all tests
      chartkit unittest

      # Run tests for specific charts
      chartkit unittest mozcloud mozcloud-gateway
    """
    passed = graph.run_unit_tests(
        chart_names=list(charts) or None,
        update_snapshot=update_snapshot,
        parallel=parallel,
        verbose=verbose,
    )
    if not passed:
        raise SystemExit(1)


@cli.group()
def version():
    """Manage chart versions."""
    pass


@version.command("list")
@click.argument("charts", nargs=-1, type=str)
@click.pass_obj
def list_versions(graph: ChartGraph, charts: list[str]):
    """Lists the versions of all charts."""
    charts = graph.ensure_charts_or_files(charts)
    for chart in graph.sort_by_depth(charts):
        graph.print_dependent_graph(
            chart_name=chart, json_output=False, show_versions=True
        )


@version.command()
@click.option(
    "--release-type",
    type=click.Choice(["major", "minor", "patch"]),
    default="patch",
    help="Semver part to increment (major, minor, or patch). Cascades to dependent charts.",
)
@click.option(
    "--dry-run",
    is_flag=True,
    default=False,
    help="Show what would be changed, but do not write changes.",
)
@click.option(
    "--format",
    "output_format",
    type=click.Choice(["text", "json", "markdown"]),
    default="text",
    help="Output format for version bump results (text, json, or markdown).",
)
@click.option(
    "--staged",
    is_flag=True,
    default=False,
    help="Bump versions for charts with staged changes (in git).",
)
@click.argument("charts", nargs=-1, type=str)
@click.pass_obj
def bump(
    graph: ChartGraph,
    charts: List[str],
    release_type: str,
    dry_run: bool = False,
    output_format: str = "text",
    staged: bool = False,
):
    """Bumps the version of a chart and cascades to dependents. Deprecated charts are ignored."""

    charts = get_chart_arguments(graph, charts, staged)
    if not charts:
        click.echo(
            "No charts to bump. Specify chart names, file paths, or use --staged.",
            err=True,
        )
        raise SystemExit(1)

    vm = VersionManager(graph)
    # Sort by depth (shallowest first) to ensure dependencies are processed before dependents
    sorted_charts = graph.sort_by_depth(charts)
    for chart_name in sorted_charts:
        target_chart = graph.get_chart(chart_name)
        if not target_chart:
            click.echo(f"Chart '{chart_name}' not found.", err=True)
            continue
        vm.cascade_bump(target_chart, release_type)

    vm.print_updates(output_format=output_format)

    if not dry_run:
        vm.save_versions()
        click.echo("Chart versions updated.", err=True)
    else:
        click.echo("Dry run; no changes made.", err=True)


@version.command()
@click.option(
    "--commit",
    default="HEAD",
    help="Git commit to check against (default: HEAD).",
)
@click.argument("charts", nargs=-1, type=str)
@click.pass_obj
def check(graph: ChartGraph, charts: List[str], commit: str):
    """Checks the previous version of a chart against a specific commit.
    If the file has changed but not the version, it indicates that a version bump is needed."""
    # resolve charts from staged files if needed
    charts = get_chart_arguments(graph, charts, staged=True)
    charts_to_bump = []
    for chart in charts:
        current_version = Version.parse(graph.get_chart(chart).version)
        previous_version = Version.parse(
            graph.get_chart(chart).get_previous_version(commit) or "0.0.0"
        )
        needs_bump = (
            current_version == previous_version or current_version < previous_version
        )
        if needs_bump:
            charts_to_bump.append(chart)
    if len(charts_to_bump) == 0:
        click.echo("All specified charts are up to date.")
    else:
        click.echo(
            f"""The following charts need version bumps: \n - {"\n  - ".join(charts_to_bump)}
Please bump their versions using the 'bump' command. eg:
  make bump-charts
""",
            err=True,
        )
        exit(1)


def get_chart_arguments(
    graph: ChartGraph, charts: List[str], staged: bool
) -> List[str]:
    """Helper function to get chart names or file paths."""
    if staged:
        charts = staged_files()
        if len(charts) == 0:
            click.echo("No staged changes found in any charts.", err=True)
            return []
    elif len(charts) == 0:
        click.echo("At least one chart name or file path must be specified.", err=True)
        return []

    return graph.ensure_charts_or_files(charts)


if __name__ == "__main__":
    cli()
