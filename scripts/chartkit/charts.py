import json
import os
import re
import subprocess
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable, Dict, List, NamedTuple, Optional, Set


import click
import ruamel.yaml
from git import Blob

from .files import files_to_chart_files, find_chart_files, load_chart
from .git import get_commit_blob

# YAML setup for round-trip and comment preservation
yaml = ruamel.yaml.YAML()
yaml.indent(mapping=2, sequence=4, offset=2)


def _print_suite_summary(passed: bool, output: str) -> None:
    """Print a compact one-line summary of a suite result.

    Parses the suite name, test counts, and elapsed time from helm unittest
    output. Full failure output is deferred and printed by the caller after
    all suites complete, so failures don't interleave with other results.
    """
    ansi_escape = re.compile(r"\x1b\[[0-9;]*m")
    suite_name = tests = time = ""
    for line in output.splitlines():
        line = ansi_escape.sub("", line)
        if m := re.match(r"^\s+(?:PASS|FAIL)\s+(.+?)\t", line):
            suite_name = m.group(1).strip()
        elif m := re.match(r"^Tests:\s+(.+)$", line):
            tests = m.group(1).strip()
        elif m := re.match(r"^Time:\s+(.+)$", line):
            time = m.group(1).strip()

    status = (
        click.style(" PASS ", fg="white", bg="green", bold=True)
        if passed
        else click.style(" FAIL ", fg="white", bg="red", bold=True)
    )
    click.echo(f"{status}  {suite_name}  ({tests}, {time})")


class ChartEdge(NamedTuple):
    parent: str
    child: str


class ChartNode:
    name: str
    info: "ChartInfo"
    next: List["ChartNode"]

    def __init__(self, name: str, info: "ChartInfo"):
        self.name = name
        self.info = info
        self.next = []

    def add_next(self, node: "ChartNode"):
        self.next.append(node)

    def to_json(self, direction: str = "next") -> dict[str, Any]:
        obj: dict[str, Any] = {"name": self.name, "info": self.info.to_json()}
        if len(self.next) > 0:
            obj[direction] = [n.to_json(direction) for n in self.next]
        return obj

    def __repr__(self) -> str:
        return f"ChartNode(name={self.name}, info={self.info}, next={self.next})"

    def flatten(self) -> List["ChartInfo"]:
        """Flatten the tree into a list of nodes."""
        nodes = [self.info]
        for child in self.next:
            nodes.extend(child.flatten())
        return nodes


@dataclass
class ChartInfo:
    name: str
    type: str
    version: str
    path: Path
    dependencies: List[dict[str, str]]  # names of dependent charts
    deprecated: bool = False

    def __repr__(self) -> str:
        return f"""Chart: {self.name}
    Type: {self.type}
    Version: {self.version}
    Path: {self.path}
    Dependencies: {self.dependencies}"""

    def to_json(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "type": self.type,
            "version": self.version,
            "path": str(self.path),
            "dependencies": self.dependencies,
        }

    @staticmethod
    def from_yaml(chart: Path | Blob) -> Optional["ChartInfo"]:
        data: Optional[Dict[str, Any]] = None
        chart_path: Path
        try:
            if isinstance(chart, Path):
                chart_path = chart.resolve()
                data = load_chart(chart_path)
            elif isinstance(chart, Blob):
                chart_path = Path(chart.path)
                data = yaml.load(chart.data_stream.read().decode("utf-8"))
            if not data:
                return None
        except Exception as e:
            click.echo(f"WARN: Failed to parse chart: {e}", err=True)
            return None

        name = data.get("name", chart_path.parent.name or "unnamed")
        return ChartInfo(
            name=name,
            type=data.get("type", "application"),
            version=data.get("version", ""),
            path=chart_path.parent,
            dependencies=data.get("dependencies", []) or [],
            deprecated=bool(data.get("deprecated", False)),
        )

    def save_chart_yaml(self):
        chart_yaml_path = self.path / "Chart.yaml"
        try:
            with chart_yaml_path.open("r", encoding="utf-8") as f:
                data = yaml.load(f) or {}
        except Exception as e:
            click.echo(f"WARN: Failed to parse {chart_yaml_path}: {e}", err=True)
            return

        data["version"] = self.version
        data["type"] = self.type
        data["name"] = self.name
        data["dependencies"] = self.dependencies

        try:
            with chart_yaml_path.open("w", encoding="utf-8") as f:
                yaml.dump(data, f)
        except Exception as e:
            click.echo(f"WARN: Failed to write {chart_yaml_path}: {e}", err=True)

    def update_dependencies(self, dry_run: bool = False):
        if len(self.dependencies) > 0:
            if dry_run:
                click.echo(
                    f"DRY-RUN: Would update dependencies for chart {self.name}..."
                )
                return
            click.echo(f"Updating dependencies for chart {self.name}...")
            try:
                subprocess.run(
                    ["helm", "dependency", "update"], cwd=self.path, check=True
                )
            except subprocess.CalledProcessError as e:
                click.echo(
                    f"WARN: Failed to update dependencies for {self.name}: {e}",
                    err=True,
                )
        else:
            click.echo(f"No dependencies to update for chart {self.name}.")

    def find_test_suites(self) -> List[Path]:
        """Return all helm-unittest suite files for this chart."""
        tests_dir = self.path / "tests"
        if not tests_dir.is_dir():
            return []
        return sorted(tests_dir.glob("*_test.yaml"))

    def get_previous_version(self, commit: str = "HEAD") -> Optional[str]:
        """Check the version of the chart in a specific commit."""
        chart_yaml_path = self.path / "Chart.yaml"
        blob = get_commit_blob(commit, str(chart_yaml_path))
        if blob is None:
            return None
        chart_info = ChartInfo.from_yaml(blob)
        return chart_info.version if chart_info else None


class ChartGraph:
    chart_files: List[Path]
    charts: Dict[str, ChartInfo]
    edges: Set[ChartEdge]

    def __init__(
        self,
        roots: List[str] = ["."],
        internal_only: bool = True,
    ):
        root_paths = [Path(p).resolve() for p in roots]
        self.chart_files = find_chart_files(root_paths)
        self.charts = self.collect_charts()
        self.edges = self.build_graph(self.charts, internal_only)

    def ensure_charts_or_files(self, charts: List[str]) -> List[str]:
        """Ensure that the provided list contains valid chart names or file paths.
        If a file path is provided, it will be converted to the corresponding chart name.
        """

        def is_chart(c: str) -> bool:
            return c in self.charts

        valid_charts = [c for c in charts if is_chart(c)]
        valid_charts.extend(
            files_to_chart_files([c for c in charts if not is_chart(c)])
        )
        return valid_charts

    def collect_charts(self) -> Dict[str, ChartInfo]:
        charts: Dict[str, ChartInfo] = {}

        for chart_path in self.chart_files:
            chart_info = ChartInfo.from_yaml(chart_path)
            if not chart_info:
                continue
            if chart_info.deprecated:
                continue
            charts[chart_info.name] = chart_info
        return charts

    def build_graph(
        self,
        charts: Dict[str, ChartInfo],
        internal_only: bool,
    ) -> Set[ChartEdge]:
        edges: Set[ChartEdge] = set()
        internal_names = set(charts.keys())

        for parent, info in charts.items():
            for d in info.dependencies:
                # Helm dependency fields: name (required), alias (optional)
                child = (d.get("alias") or d.get("name") or "").strip()
                if not child:
                    continue
                if internal_only and child not in internal_names:
                    # Try to map alias to actual local subchart under charts/
                    # If alias not found, skip
                    continue
                edges.add(ChartEdge(parent, child))
        return edges

    def get_roots(self) -> List[str]:
        # get roots from edges
        all_children = {child for _, child in self.edges}
        roots = [name for name in self.charts.keys() if name not in all_children]
        if not roots:
            roots = list(self.charts.keys())  # fallback to all charts
        return roots

    def print_dependency_graph(
        self,
        chart_name: Optional[str] = None,
        json_output: bool = False,
        show_versions: bool = False,
    ):
        """Print the full dependency graph as a tree."""
        if chart_name:
            self.print_subtree(
                self.find_subtree(chart_name, self.dependency_selector()),
                level=1,
                json_output=json_output,
                show_versions=show_versions,
            )
        else:
            roots = self.get_roots()
            for root in sorted(roots):
                self.print_subtree(
                    self.find_subtree(root, self.dependency_selector()),
                    level=1,
                    json_output=json_output,
                )

    def print_dependent_graph(
        self, chart_name: str, json_output: bool = False, show_versions: bool = False
    ):
        """Print all parent charts that depend on the given chart."""
        self.print_subtree(
            self.find_subtree(chart_name, self.dependent_selector()),
            level=1,
            json_output=json_output,
            show_versions=show_versions,
        )

    def print_subtree(
        self,
        subtree: ChartNode,
        level: int,
        is_last: bool = True,
        json_output: bool = False,
        show_versions: bool = False,
    ):
        """Recursively print the subtree starting from chart."""
        if json_output:
            click.echo(json.dumps(subtree.to_json(), indent=2))
        else:
            prefix = (
                ""
                if level == 1
                else "│   " * (level - 1) + ("└──" if is_last else "├──")
            )
            click.echo(
                f"{prefix}{subtree.name}{' v' + subtree.info.version if show_versions else ''}"
            )
            for idx, node in enumerate(subtree.next):
                self.print_subtree(
                    node,
                    level=level + 1,
                    is_last=idx == len(subtree.next) - 1,
                    show_versions=show_versions,
                )

    def make_edge_selector(
        self,
        edges: Set[ChartEdge],
        comparator: Callable[[ChartEdge, str], bool],
        selector: Callable[[ChartEdge], str],
    ) -> Callable[[str], Set[str]]:
        def wrapper(root: str) -> Set[str]:
            return {selector(edge) for edge in edges if comparator(edge, root)}

        return wrapper

    def dependent_selector(self) -> Callable[[str], Set[str]]:
        """Return a function that finds all parents of a given chart."""
        return self.make_edge_selector(
            self.edges,
            lambda edge, child: edge.child == child,
            lambda edge: edge.parent,
        )

    def dependency_selector(self) -> Callable[[str], Set[str]]:
        """Return a function that finds all children of a given chart."""
        return self.make_edge_selector(
            self.edges,
            lambda edge, parent: edge.parent == parent,
            lambda edge: edge.child,
        )

    def find_subtree(
        self, chart_name: str, selector: Callable[[str], Set[str]]
    ) -> ChartNode:
        """Recursively find the subtree for a given chart."""
        root = ChartNode(chart_name, self.get_chart(chart_name))
        for node in selector(chart_name):
            root.add_next(self.find_subtree(node, selector))
        return root

    def get_chart(self, chart_name: str) -> ChartInfo:
        """Get chart info by name."""
        try:
            return self.charts[chart_name]
        except KeyError:
            raise KeyError(f"Chart '{chart_name}' not found")

    def get_chart_depth(self, chart_name: str) -> int:
        """Get the depth of a chart in the dependency graph."""

        def _depth(name: str, visited: Set[str]) -> int:
            visited.add(name)
            children = self.dependency_selector()(name)
            if not children:
                return 1
            return 1 + max(_depth(child, visited) for child in children)

        try:
            return _depth(chart_name, set())
        except KeyError:
            raise KeyError(f"Chart '{chart_name}' not found")

    def sort_by_depth(self, chart_names: List[str], reverse: bool = False) -> List[str]:
        """Sort chart names by their depth in the dependency graph (deepest first)."""
        return sorted(
            list(filter(lambda name: name in self.charts, chart_names)),
            key=lambda name: self.get_chart_depth(name) if name in self.charts else 0,
            reverse=reverse,
        )

    def print_charts(self, chart_names: List[str], json_output: bool = False):
        """Print chart information for the given chart names."""
        if json_output:
            charts_info = [
                self.get_chart(name).to_json()
                for name in chart_names
                if name in self.charts
            ]
            click.echo(json.dumps(charts_info, indent=2))
        else:
            for name in chart_names:
                self.print_chart_info(name)

    def print_chart_info(self, chart_name: str, json_output: bool = False):
        chart = self.get_chart(chart_name)
        if chart:
            if json_output:
                click.echo(json.dumps(chart.to_json(), indent=2))
            else:
                click.echo(chart)
        else:
            click.echo(f"Chart '{chart_name}' not found.", err=True)

    def get_affected_charts(self, files: List[str]) -> List[str]:
        """Return charts affected by the given files, including their dependents."""
        changed_names = files_to_chart_files(files)
        affected: Set[str] = set()
        for name in changed_names:
            if name not in self.charts:
                continue
            subtree = self.find_subtree(name, self.dependent_selector())
            for chart_info in subtree.flatten():
                if chart_info.name in self.charts:
                    affected.add(chart_info.name)
        return sorted(affected)

    def run_unit_tests(
        self,
        chart_names: Optional[List[str]] = None,
        update_snapshot: bool = False,
        parallel: Optional[int] = None,
        verbose: bool = False,
    ) -> bool:
        """Run helm unit tests in parallel for all non-deprecated charts."""
        workers = parallel or os.cpu_count() or 4

        charts_to_test = (
            [self.charts[n] for n in chart_names if n in self.charts]
            if chart_names is not None
            else list(self.charts.values())
        )

        suites = [
            (chart, testfile)
            for chart in charts_to_test
            for testfile in chart.find_test_suites()
        ]

        if not suites:
            click.echo("No test suites found.")
            return True

        click.echo(f"Running {len(suites)} test suites with PARALLEL={workers}...")

        def run_suite(chart: ChartInfo, testfile: Path) -> tuple[bool, str]:
            cmd = [
                "helm",
                "unittest",
                str(chart.path),
                "-f",
                str(testfile),
                "--with-subchart=false",
            ]
            if update_snapshot:
                cmd.append("-u")
            cmd.append("--color")
            result = subprocess.run(cmd, capture_output=True, text=True)
            return result.returncode == 0, result.stdout + result.stderr

        failures: List[str] = []
        with ThreadPoolExecutor(max_workers=workers) as executor:
            futures = [executor.submit(run_suite, chart, tf) for chart, tf in suites]
            for future in as_completed(futures):
                passed, output = future.result()
                if verbose:
                    click.echo(output, nl=False)
                else:
                    _print_suite_summary(passed, output)
                if not passed:
                    failures.append(output)

        if not verbose and failures:
            click.echo("\n--- Failures ---\n")
            for output in failures:
                click.echo(output, nl=False)

        return not failures

    def update_dependencies(
        self, chart_names: List[str], all: bool = False, dry_run: bool = False
    ):
        charts = self.charts.keys() if all else chart_names
        for name in self.sort_by_depth(list(charts)):
            chart = self.get_chart(name)
            if chart:
                chart.update_dependencies(dry_run=dry_run)
            else:
                click.echo(f"Chart '{name}' not found.", err=True)
