from typing import Optional
import click

from .charts import ChartGraph
from .mermaid import MermaidDiagram
from .versions import VersionManager


@click.group()
@click.option(
    "--roots",
    "-r",
    multiple=True,
    default=["."],
    help="Root directories to scan for Helm charts. Can be specified multiple times.",
)
@click.option(
    "--internal-only",
    is_flag=True,
    default=False,
    help="Only include dependencies that are also found in the scanned charts.",
)
@click.option(
    "--root-chart",
    "-c",
    default=None,
    help="If specified, only show the dependency tree for this root chart.",
)
@click.version_option(message="ChartKit %(version)s")
@click.pass_context
def cli(
    ctx: click.Context, roots: list[str], internal_only: bool, root_chart: Optional[str]
):
    """ChartKit: CLI tooling for Helm chart dependencies and utilities."""
    ctx.obj = ChartGraph(
        roots=roots, internal_only=internal_only, root_chart=root_chart
    )


@cli.command()
@click.option("--json", is_flag=True, default=False, help="Output as JSON.")
@click.pass_obj
def charts(
    graph: ChartGraph,
    json: bool = False,
    chart: Optional[str] = None,
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
@click.pass_obj
def mermaid(
    graph: ChartGraph,
    include_attrs: bool = False,
    output: Optional[str] = None,
    svg_output: Optional[str] = None,
):
    """Generates a diagram of Helm chart dependencies."""
    diagram = MermaidDiagram(graph, include_attrs)
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
@click.argument("chart", type=str, required=True)
@click.pass_obj
def list(graph: ChartGraph, chart: str):
    """Lists the versions of all charts."""
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
@click.argument("chart", type=str)
@click.pass_obj
def bump(
    graph: ChartGraph,
    chart: str,
    part: str,
    dry_run: bool = False,
    json: bool = False,
):
    """Bumps the version of a chart and cascades to dependents."""

    vm = VersionManager(graph)
    target_chart = graph.get_chart(chart)
    if not target_chart:
        click.echo(f"Chart '{chart}' not found.", err=True)
        return

    vm.cascade_bump(target_chart, part)
    vm.print_updates(json_output=json)

    if not dry_run:
        vm.save_versions()
        click.echo("Chart versions updated.")
    else:
        click.echo("Dry run; no changes made.")


if __name__ == "__main__":
    cli()
