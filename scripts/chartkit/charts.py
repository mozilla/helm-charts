from dataclasses import dataclass
import sys
from pathlib import Path
from typing import Any, Callable, Dict, List, NamedTuple, Optional, Set, Tuple

# import yaml
import ruamel.yaml
import json

# YAML setup for round-trip and comment preservation
yaml = ruamel.yaml.YAML()
yaml.indent(mapping=2, sequence=4, offset=2)


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

    def save_chart_yaml(self):
        chart_yaml_path = self.path / "Chart.yaml"
        try:
            with chart_yaml_path.open("r", encoding="utf-8") as f:
                data = yaml.load(f) or {}
        except Exception as e:
            print(f"WARN: Failed to parse {chart_yaml_path}: {e}", file=sys.stderr)
            return

        data["version"] = self.version
        data["type"] = self.type
        data["name"] = self.name
        data["dependencies"] = self.dependencies

        try:
            with chart_yaml_path.open("w", encoding="utf-8") as f:
                yaml.dump(data, f)
        except Exception as e:
            print(f"WARN: Failed to write {chart_yaml_path}: {e}", file=sys.stderr)


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
        self.chart_files = self.find_chart_files(root_paths)
        self.charts, self.name_to_path = self.collect_charts()
        self.edges = self.build_graph(self.charts, internal_only)

    def find_chart_files(self, roots: List[Path]) -> List[Path]:
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

    def load_chart(self, chart_yaml_path: Path) -> Optional[dict]:
        try:
            with chart_yaml_path.open("r", encoding="utf-8") as f:
                return yaml.load(f) or {}
        except Exception as e:
            print(f"WARN: Failed to parse {chart_yaml_path}: {e}", file=sys.stderr)
            return None

    def collect_charts(self) -> Tuple[Dict[str, ChartInfo], Dict[str, Path]]:
        charts: Dict[str, ChartInfo] = {}
        name_to_path: Dict[str, Path] = {}

        for chart_path in self.chart_files:
            data = self.load_chart(chart_path)
            if not data:
                continue
            name = data.get("name", chart_path.parent.name or "unnamed")
            charts[name] = ChartInfo(
                name=name,
                type=data.get("type", "application"),
                version=data.get("version", ""),
                path=chart_path.parent,
                dependencies=data.get("dependencies", []) or [],
            )
            name_to_path[name] = chart_path.parent
        return charts, name_to_path

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
            print(json.dumps(subtree.to_json(), indent=2))
        else:
            prefix = (
                ""
                if level == 1
                else "│   " * (level - 1) + ("└──" if is_last else "├──")
            )
            print(
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

    def sort_by_depth(self, chart_names: List[str]) -> List[str]:
        """Sort chart names by their depth in the dependency graph (deepest first)."""
        return sorted(
            chart_names,
            key=lambda name: self.get_chart_depth(name) if name in self.charts else 0,
            reverse=True,
        )

    def print_chart_info(self, chart_name: str, json_output: bool = False):
        chart = self.get_chart(chart_name)
        if chart:
            if json_output:
                print(json.dumps(chart.to_json(), indent=2))
            else:
                print(chart)
        else:
            print(f"Chart '{chart_name}' not found.", file=sys.stderr)
