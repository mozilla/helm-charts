import subprocess
from typing import List, Optional
import click

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
def cli(
    ctx: click.Context, roots: list[str], internal_only: bool
):
    """ChartKit: CLI tooling for Helm chart dependencies and utilities."""

    # find the git root
    if not roots or len(roots) == 0:
        git_root = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        roots = [git_root]

    ctx.obj = ChartGraph(
        roots=roots, internal_only=internal_only
    )


@cli.command()
@click.option("--json", is_flag=True, default=False, help="Output as JSON.")
@click.pass_obj
def charts(
    graph: ChartGraph,
    json: bool = False,
):
    """Prints Helm chart dependencies."""
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


@cli.group()
def version():
    """Manage chart versions."""
    pass


@version.command()
@click.argument("charts", nargs=-1, type=str, required=True)
@click.pass_obj
def list(graph: ChartGraph, charts: list[str]):
    """Lists the versions of all charts."""
    for chart in graph.sort_by_depth(charts):
        graph.print_dependent_graph(chart_name=chart, json_output=False, show_versions=True)


@version.command()
@click.option(
    "--part",
    type=click.Choice(["major", "minor", "patch"]),
    default="patch",
    help="Part of the version to bump.",
)
@click.option(
    "--dry-run",
    is_flag=True,
    default=False,
    help="Show what would be changed, but do not write changes.",
)
@click.option(
    "--json",
    is_flag=True,
    default=False,
    help="Output results as JSON.",
)
@click.argument("charts", nargs=-1, type=str)
@click.pass_obj
def bump(
    graph: ChartGraph,
    charts: List[str],
    part: str,
    dry_run: bool = False,
    json: bool = False,
):
    """Bumps the version of a chart and cascades to dependents."""

    if len(charts) == 0:
        click.echo("At least one chart name must be specified to bump.", err=True)
        return
    
    vm = VersionManager(graph)
    # Sort by depth (deepest first) to ensure dependents are processed after dependencies
    sorted_charts = graph.sort_by_depth(charts)
    for chart_name in sorted_charts:
        target_chart = graph.get_chart(chart_name)
        if not target_chart:
            click.echo(f"Chart '{chart_name}' not found.", err=True)
            continue
        vm.cascade_bump(target_chart, part)

    vm.print_updates(json_output=json)

    if not dry_run:
        vm.save_versions()
        click.echo("Chart versions updated.")
    else:
        click.echo("Dry run; no changes made.")


if __name__ == "__main__":
    cli()
