from typing import Optional
import click

from .charts import ChartGraph
from .mermaid import MermaidDiagram

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
@click.pass_context
def cli(ctx: click.Context, roots: list[str], internal_only: bool, root_chart: Optional[str]):
    """ChartKit: CLI tooling for Helm chart dependencies and utilities."""
    click.echo(f"Scanning roots: {', '.join(roots)}")
    ctx.obj = ChartGraph(
        roots=roots, internal_only=internal_only, root_chart=root_chart
    )


@cli.command()
@click.pass_obj
def charts(
    graph: ChartGraph,
):
    """Prints Helm chart dependencies."""
    graph.print_graph()

@cli.command()
@click.option(
    "--chart",
    "-c",
    required=True,
    help="Chart name to find parents for.",
)
@click.pass_obj
def chart_parents(graph: ChartGraph, chart: str):
    """Prints Helm chart dependencies."""
    def print_parents(chart: str, level: int = 0):
        parents = graph.find_parents(chart)
        prefix = "    " * level
        for parent in sorted(parents):
            click.echo(f"{prefix}{parent}")
            print_parents(parent, level + 1)
    print_parents(chart)

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


if __name__ == "__main__":
    cli()
