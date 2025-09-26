import sys
import subprocess
import tempfile
import os
from typing import Dict, List, Optional, Set

import click
from .charts import ChartEdge, ChartGraph, ChartInfo


class MermaidDiagram:
    """Class to generate Mermaid ER diagrams from Helm chart dependency graphs."""

    MERMAID_HEADER = """
    erDiagram
    """

    mermaid_str: str

    def __init__(
        self,
        chart_graph: ChartGraph,
        include_attrs: bool,
        root_chart: Optional[str] = None,
    ):
        """Generate a Mermaid ER diagram from the given chartgraph."""
        charts = chart_graph.charts
        edges = chart_graph.edges

        if root_chart:
            subcharts = { c.name: c for c in chart_graph.find_subtree(
                root_chart, chart_graph.dependency_selector()
            ).flatten()}
            charts = subcharts
            # filter edges to those that connect to subcharts
            edges = {e for e in edges if e.parent in subcharts}

        self.mermaid_str = self.generate(charts, edges, include_attrs)


    def generate(self, charts: Dict[str, ChartInfo], edges: Set[ChartEdge], include_attrs: bool) -> str:
        # Build identifier map
        id_map: Dict[str, str] = {name: self.sanitize_identifier(name) for name in charts.keys()}

        lines: List[str] = [self.MERMAID_HEADER]
        # Emit entities
        for name, info in sorted(charts.items(), key=lambda kv: kv[0].lower()):
            ident = id_map[name]
            if include_attrs:
                lines.append(f"    {ident} {{")
                # Keep attributes short; ER expects simple type labels
                lines.append(f'        string version "{info.version}"')
                lines.append(f'        string type "{info.type}"')
                lines.append("    }")
            else:
                # Minimal body (Mermaid requires a body). We'll include a single attr.
                lines.append(f"    {ident} {{")
                lines.append("        string type")
                lines.append("    }")

        # Emit relationships (parent depends on child)
        # Using: PARENT ||--o{ CHILD : DEPENDS_ON
        for parent, child in sorted(edges):
            p = id_map.get(parent, self.sanitize_identifier(parent))
            c = id_map.get(child, self.sanitize_identifier(child))
            lines.append(f"    {p} ||--o{{ {c} : DEPENDS_ON")

        # Emit legend mapping as comments
        lines.append("\n%% Legend: original-name -> identifier")
        for name, ident in sorted(id_map.items(), key=lambda kv: kv[0].lower()):
            lines.append(f"%%   {name} -> {ident}")

        return "\n".join(lines) + "\n"

    def sanitize_identifier(self, name: str) -> str:
        """Sanitize a chart name to a Mermaid-safe identifier.
        Mermaid ER likes [A-Za-z0-9_] and dislikes hyphens/spaces.
        We'll replace non-alnum with underscores and ensure it doesn't start with a digit.
        """
        import re

        ident = re.sub(r"[^A-Za-z0-9_]", "_", name)
        if ident and ident[0].isdigit():
            ident = f"_{ident}"
        return ident or "_unnamed_"


    def write_mermaid_to_file(self, output_path: str) -> None:
        """Write the Mermaid diagram string to the specified file."""
        with open(output_path, "w") as f:
            f.write(self.mermaid_str)
        click.echo(f"Mermaid diagram written to {output_path}")


    def write_mermaid_to_svg(self, output_path: str) -> None:
        """Write the Mermaid diagram as an SVG file using the mermaid CLI tool."""

        with tempfile.NamedTemporaryFile(mode="w", suffix=".mmd", delete=False) as temp_mmd:
            temp_mmd.write(self.mermaid_str)
            temp_mmd_path = temp_mmd.name

        cmd = [
            "npx",
            "-p",
            "@mermaid-js/mermaid-cli",
            "mmdc",
            "-i",
            temp_mmd_path,
            "-o",
            output_path,
        ]
        click.echo(f"Running Mermaid CLI to generate SVG: {' '.join(cmd)}")
        try:
            subprocess.run(cmd, check=True)
            click.echo(f"SVG written to {output_path}")
        except Exception as e:
            click.echo(f"ERROR: Failed to generate SVG: {e}", file=sys.stderr)
        finally:
            os.remove(temp_mmd_path)
