#!/usr/bin/env python3
# /// script
# requires-python = ">=3.8"
# dependencies = [
#   "pyyaml>=6.0"
# ]
# ///
"""
helm-to-mermaid-er.py

Parse a repository of Helm charts and emit a Mermaid ER diagram (erDiagram) that
shows dependency relationships between charts (application and library types).

Features
- Walks a directory tree to find Chart.yaml files
- Reads chart metadata (name, version, type)
- Reads dependencies declared in Chart.yaml (Helm v3)
- Optionally inspects nested charts/ subfolders for local subcharts
- Sanitizes entity names for Mermaid identifiers, and emits a legend mapping
  original names -> sanitized identifiers
- Outputs to stdout or a file

Usage
    uv run helm2mermaid.py --root . > graph.mmd
    uv run helm2mermaid.py --root . --root-chart mozcloud-workload-stateless > app-deps.mmd
    uv run helm2mermaid.py --root . --svg-output graph.svg --include-attrs

Options
    --root PATH            Root directory to scan (repeatable)
    --root-chart NAME      Only diagram the dependency tree starting from this chart
    --only-internal        Only draw edges to dependencies that exist within the scanned roots
    --include-attrs        Include basic attributes (version, type, path) per entity
    --output FILE          Path to write Mermaid text (default: stdout)

Requires: PyYAML (pip install pyyaml)

Note: This script relies on Chart.yaml 'dependencies' for relationships. If you
are composing subcharts purely via values or runtime discovery, those edges will
not be reflected.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

import yaml

ChartInfo = Dict[str, str]
Edge = Tuple[str, str]  # parent -> child

MERMAID_HEADER = """
erDiagram
"""


def find_chart_files(roots: List[Path]) -> List[Path]:
    """
    Recursively find all Chart.yaml files in the given root directories.
    Excludes Chart.lock files and handles various edge cases.
    """
    chart_files: List[Path] = []
    seen_paths: Set[Path] = set()

    for root in roots:
        if not root.exists():
            print(f"WARN: Root path does not exist: {root}", file=sys.stderr)
            continue
        if not root.is_dir():
            print(f"WARN: Root path is not a directory: {root}", file=sys.stderr)
            continue

        # Use rglob to recursively find all Chart.yaml files
        for p in root.rglob("Chart.yaml"):
            # Skip if this is actually Chart.lock or other variants
            if p.name != "Chart.yaml":
                continue

            # Skip if we've already seen this path (handles overlapping roots)
            resolved_path = p.resolve()
            if resolved_path in seen_paths:
                continue
            seen_paths.add(resolved_path)

            # Skip if the file is not readable
            if not p.is_file() or not p.exists():
                continue

            chart_files.append(p)

    return sorted(chart_files)  # Sort for consistent output


def load_chart(chart_yaml_path: Path) -> Optional[dict]:
    try:
        with chart_yaml_path.open("r", encoding="utf-8") as f:
            return yaml.safe_load(f) or {}
    except Exception as e:
        print(f"WARN: Failed to parse {chart_yaml_path}: {e}", file=sys.stderr)
        return None


def sanitize_identifier(name: str) -> str:
    """Sanitize a chart name to a Mermaid-safe identifier.
    Mermaid ER likes [A-Za-z0-9_] and dislikes hyphens/spaces.
    We'll replace non-alnum with underscores and ensure it doesn't start with a digit.
    """
    import re

    ident = re.sub(r"[^A-Za-z0-9_]", "_", name)
    if ident and ident[0].isdigit():
        ident = f"_{ident}"
    return ident or "_unnamed_"


def collect_charts(
    chart_files: List[Path],
) -> Tuple[Dict[str, ChartInfo], Dict[str, Path]]:
    charts: Dict[str, ChartInfo] = {}
    name_to_path: Dict[str, Path] = {}

    for chart_path in chart_files:
        data = load_chart(chart_path)
        if not data:
            continue
        name = data.get("name")
        if not name:
            # If name missing, try directory name
            name = chart_path.parent.name
        chart_type = data.get("type", "application")
        version = data.get("version", "")
        charts[name] = {
            "name": name,
            "type": chart_type,
            "version": version,
            "path": str(chart_path.parent.resolve()),
        }
        name_to_path[name] = chart_path.parent
    return charts, name_to_path


def collect_edges(chart_files: List[Path]) -> Dict[str, List[dict]]:
    """Return mapping of chart name -> list of dependency objects.
    We preserve raw dependency dicts for alias/conditions info.
    """
    deps: Dict[str, List[dict]] = {}
    for chart_path in chart_files:
        data = load_chart(chart_path)
        if not data:
            continue
        name = data.get("name", chart_path.parent.name)
        dep_list = data.get("dependencies", []) or []
        if isinstance(dep_list, list):
            deps[name] = dep_list
        else:
            deps[name] = []
    return deps


def build_graph(
    charts: Dict[str, ChartInfo],
    deps: Dict[str, List[dict]],
    internal_only: bool,
) -> Set[Edge]:
    edges: Set[Edge] = set()
    internal_names = set(charts.keys())

    for parent, dep_list in deps.items():
        for d in dep_list:
            # Helm dependency fields: name (required), alias (optional)
            child = (d.get("alias") or d.get("name") or "").strip()
            if not child:
                continue
            if internal_only and child not in internal_names:
                # Try to map alias to actual local subchart under charts/
                # If alias not found, skip
                continue
            edges.add((parent, child))
    return edges


def find_dependency_tree(
    root_chart: str,
    deps: Dict[str, List[dict]],
    charts: Dict[str, ChartInfo],
) -> Set[str]:
    """
    Find all charts in the dependency tree starting from root_chart.
    Returns a set of chart names that are reachable from the root.
    """
    visited = set()
    to_visit = [root_chart]

    while to_visit:
        current = to_visit.pop()
        if current in visited:
            continue
        visited.add(current)

        # Find dependencies of current chart
        if current in deps:
            for dep in deps[current]:
                child = (dep.get("alias") or dep.get("name") or "").strip()
                if child and child not in visited:
                    to_visit.append(child)

    return visited


def filter_by_root_chart(
    root_chart: str,
    charts: Dict[str, ChartInfo],
    deps: Dict[str, List[dict]],
    edges: Set[Edge],
) -> Tuple[Dict[str, ChartInfo], Set[Edge]]:
    """
    Filter charts and edges to only include those in the dependency tree of root_chart.
    """
    if root_chart not in charts:
        print(
            f"ERROR: Root chart '{root_chart}' not found in discovered charts",
            file=sys.stderr,
        )
        available_charts = sorted(charts.keys())
        print(f"Available charts: {', '.join(available_charts)}", file=sys.stderr)
        sys.exit(1)

    # Find all charts in the dependency tree
    tree_charts = find_dependency_tree(root_chart, deps, charts)

    # Filter charts to only include those in the tree
    filtered_charts = {
        name: info for name, info in charts.items() if name in tree_charts
    }

    # Filter edges to only include those between charts in the tree
    filtered_edges = {
        (parent, child)
        for parent, child in edges
        if parent in tree_charts and child in tree_charts
    }

    return filtered_charts, filtered_edges


def generate_mermaid(
    charts: Dict[str, ChartInfo],
    edges: Set[Edge],
    include_attrs: bool,
) -> str:
    # Build identifier map
    id_map: Dict[str, str] = {name: sanitize_identifier(name) for name in charts.keys()}

    lines: List[str] = [MERMAID_HEADER]

    # Emit entities
    for name, info in sorted(charts.items(), key=lambda kv: kv[0].lower()):
        ident = id_map[name]
        if include_attrs:
            lines.append(f"    {ident} {{")
            # Keep attributes short; ER expects simple type labels
            ver = info.get("version", "")
            typ = info.get("type", "")
            lines.append(f'        string version "{ver}"')
            lines.append(f'        string type "{typ}"')
            lines.append("    }")
        else:
            # Minimal body (Mermaid requires a body). We'll include a single attr.
            lines.append(f"    {ident} {{")
            lines.append("        string type")
            lines.append("    }")

    # Emit relationships (parent depends on child)
    # Using: PARENT ||--o{ CHILD : DEPENDS_ON
    for parent, child in sorted(edges):
        p = id_map.get(parent, sanitize_identifier(parent))
        c = id_map.get(child, sanitize_identifier(child))
        lines.append(f"    {p} ||--o{{ {c} : DEPENDS_ON")

    # Emit legend mapping as comments
    lines.append("\n%% Legend: original-name -> identifier")
    for name, ident in sorted(id_map.items(), key=lambda kv: kv[0].lower()):
        lines.append(f"%%   {name} -> {ident}")

    return "\n".join(lines) + "\n"


def main():

    parser = argparse.ArgumentParser(
        description="Generate Mermaid erDiagram from Helm charts"
    )
    parser.add_argument(
        "--root",
        action="append",
        required=True,
        help="Root directory to scan (repeatable)",
    )
    parser.add_argument(
        "--root-chart",
        type=str,
        help="Only diagram the dependency tree starting from this chart name",
    )
    parser.add_argument(
        "--only-internal",
        action="store_true",
        help="Only draw edges to dependencies that exist within scanned roots",
    )
    parser.add_argument(
        "--include-attrs",
        action="store_true",
        help="Include version/type/path attributes in each entity",
    )
    parser.add_argument(
        "--output",
        "-o",
        type=str,
        default="-",
        help="Output file (default: '-' for stdout)",
    )
    parser.add_argument(
        "--svg-output",
        type=str,
        default=None,
        help="If set, use Mermaid CLI to output SVG to this file (requires npx and @mermaid-js/mermaid-cli)",
    )

    args = parser.parse_args()

    roots = [Path(p).resolve() for p in args.root]

    # Discover charts
    chart_files = find_chart_files(roots)
    if not chart_files:
        print("ERROR: No Chart.yaml files found under --root paths", file=sys.stderr)
        sys.exit(2)

    charts, _ = collect_charts(chart_files)
    deps = collect_edges(chart_files)
    edges = build_graph(charts, deps, internal_only=args.only_internal)

    # Filter by root chart if specified
    if args.root_chart:
        charts, edges = filter_by_root_chart(args.root_chart, charts, deps, edges)

    mermaid = generate_mermaid(charts, edges, include_attrs=args.include_attrs)

    out_path = None
    if args.output == "-":
        sys.stdout.write(mermaid)
    else:
        out_path = Path(args.output)
        out_path.write_text(mermaid, encoding="utf-8")
        print(f"Wrote {out_path}")

    # If --svg-output is set, run Mermaid CLI to generate SVG
    if args.svg_output:
        if not out_path:
            # Need to write Mermaid to a temp file
            import tempfile

            with tempfile.NamedTemporaryFile("w", suffix=".mmd", delete=False) as tmp:
                tmp.write(mermaid)
                tmp_path = tmp.name
        else:
            tmp_path = str(out_path)
        import subprocess

        svg_path = args.svg_output
        cmd = [
            "npx",
            "-p",
            "@mermaid-js/mermaid-cli",
            "mmdc",
            "-i",
            tmp_path,
            "-o",
            svg_path,
        ]
        print(f"Running Mermaid CLI to generate SVG: {' '.join(cmd)}")
        try:
            subprocess.run(cmd, check=True)
            print(f"SVG written to {svg_path}")
        except Exception as e:
            print(f"ERROR: Failed to generate SVG: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
