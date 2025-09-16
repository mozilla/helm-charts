from typing import Optional
import click

from .charts import ChartGraph
from .mermaid import MermaidDiagram


@click.group()
def cli():
    """ChartKit: CLI tooling for Helm chart dependencies and utilities."""
    pass


@cli.group(invoke_without_command=True)
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
@click.pass_context
def charts(
    ctx: click.Context,
    roots: list[str] = ["."],
    internal_only: bool = False,
    root_chart: Optional[str] = None,
):
    """Prints Helm chart dependencies."""
    if ctx.invoked_subcommand is not None:
        ctx.obj = ctx.params
        return
    ChartGraph(
        roots=roots, internal_only=internal_only, root_chart=root_chart
    ).print_graph()


@charts.command()
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
@click.pass_context
def mermaid(
    ctx: click.Context,
    include_attrs: bool = False,
    output: Optional[str] = None,
    svg_output: Optional[str] = None,
):
    """Generates a diagram of Helm chart dependencies."""
    chart_graph = ChartGraph(
        roots=ctx.obj["roots"],
        internal_only=ctx.obj["internal_only"],
        root_chart=ctx.obj["root_chart"],
    )
    diagram = MermaidDiagram(chart_graph, include_attrs)
    if output:
        diagram.write_mermaid_to_file(output)

    if svg_output:
        diagram.write_mermaid_to_svg(svg_output)

    if not output and not svg_output:
        click.echo(diagram.mermaid_str)


if __name__ == "__main__":
    cli()
