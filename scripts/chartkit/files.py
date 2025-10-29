from pathlib import Path
from typing import Any, Dict, List, Optional, Set
import os
import click
from ruamel.yaml import YAML

from .git import git_root

yaml = YAML()


def files_to_chart_files(file_paths: List[str]) -> Set[str]:
    """Find chart names (in Chart.yaml files) from a list of file paths.
    - If a path is a Chart.yaml file include it directly.
    - If the path is a values.yaml file, look for Chart.yaml in the same directory.
    - If the path is a template file or in the templates directory, look for Chart.yaml in the parent directory.
    """
    charts: Set[Path] = set()
    for path in file_paths:
        path = Path(path)
        chart_yaml: Optional[Path] = None
        if not path.is_absolute():
            path = git_root() / path
        if not path.exists():
            click.echo(f"WARN: Path does not exist: {path}", err=True)
            continue
        if os.path.isdir(path):
            chart_yaml = Path(path) / "Chart.yaml"
        elif path.name == "Chart.yaml":
            chart_yaml = path
        elif path.name == "values.yaml":
            chart_yaml = Path(path).parent / "Chart.yaml"
        elif path.suffix == ".tpl" or "templates" in path.parts:
            chart_yaml = Path(path).parent.parent / "Chart.yaml"
        if chart_yaml and chart_yaml.exists():
            charts.add(chart_yaml)

    return {
        str(load_chart(chart).get("name"))
        for chart in charts
        if load_chart(chart) is not None
    }


def find_chart_files(roots: List[Path]) -> List[Path]:
    """
    Recursively find all Chart.yaml files in the given root directories.
    Excludes Chart.lock files and handles various edge cases.
    """
    chart_files: List[Path] = []
    seen_paths: Set[Path] = set()

    for root in roots:
        if not root.exists():
            click.echo(f"WARN: Root path does not exist: {root}", err=True)
            continue
        if not root.is_dir():
            click.echo(f"WARN: Root path is not a directory: {root}", err=True)
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


def load_chart(chart_yaml_path: Path) -> Dict[str, Any]:
    try:
        with chart_yaml_path.open("r", encoding="utf-8") as f:
            return yaml.load(f) or {}
    except Exception as e:
        click.echo(f"WARN: Failed to parse {chart_yaml_path}: {e}", err=True)
        return {}


def make_path_root_relative(path: Path) -> Path:
    """Make a path relative to the git root."""
    try:
        return path.relative_to(git_root())
    except ValueError:
        return path
