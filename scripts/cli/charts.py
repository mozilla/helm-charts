import sys
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple
import yaml

ChartInfo = Dict[str, str]
Edge = Tuple[str, str]  # parent -> child

class ChartGraph:
    chart_files: List[Path]
    charts: Dict[str, ChartInfo]
    edges: Set[Edge]

    def __init__(
        self,
        roots: List[str],
        internal_only: bool = False,
        root_chart: Optional[str] = None,
    ):

        root_paths = [Path(p).resolve() for p in roots]
        self.chart_files = self.find_chart_files(root_paths)
        self.charts, self.name_to_path = self.collect_charts()
        self.deps = self.collect_edges()
        self.edges = self.build_graph(self.charts, self.deps, internal_only)

        if root_chart:
            self.charts, self.edges = self.filter_by_root_chart(
                root_chart, self.charts, self.deps, self.edges
            )


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
                return yaml.safe_load(f) or {}
        except Exception as e:
            print(f"WARN: Failed to parse {chart_yaml_path}: {e}", file=sys.stderr)
            return None

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


    def collect_charts(self) -> Tuple[Dict[str, ChartInfo], Dict[str, Path]]:
        charts: Dict[str, ChartInfo] = {}
        name_to_path: Dict[str, Path] = {}

        for chart_path in self.chart_files:
            data = self.load_chart(chart_path)
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


    def collect_edges(self) -> Dict[str, List[dict]]:
        """Return mapping of chart name -> list of dependency objects.
        We preserve raw dependency dicts for alias/conditions info.
        """
        deps: Dict[str, List[dict]] = {}
        for chart_path in self.chart_files:
            data = self.load_chart(chart_path)
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
        self,
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
        self,
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
        self,
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
        tree_charts = self.find_dependency_tree(root_chart, deps, charts)

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
    
    def get_roots(self) -> List[str]:
        # get roots from edges
        all_children = {child for _, child in self.edges}
        roots = [name for name in self.charts.keys() if name not in all_children]
        if not roots:
            roots = list(self.charts.keys())  # fallback to all charts
        return roots

    def print_graph(self):
        roots = self.get_roots()
        for root in sorted(roots):
            children = {child for parent, child in self.edges if parent == root}
            self.print_subtree(root, children, level=1)

    def print_subtree(self, chart: str, children: Set[str], level: int, is_last: bool = True):
        prefix = "" if level == 1 else "│   " * (level - 1) + ("└──" if is_last else "├──")
        print(f"{prefix}{chart}")
        for child in children:
            subchildren = {c for p, c in self.edges if p == child}
            if subchildren:
                self.print_subtree(child, subchildren, level + 1)