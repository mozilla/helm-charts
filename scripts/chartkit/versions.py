"""Manage helm chart versions."""

import json
from typing import Optional
import click
from semver import Version
from .charts import ChartGraph, ChartInfo
from .git import git_root


class VersionManager:
    version_map: dict[str, Version]
    chart_graph: ChartGraph
    updated_charts: set[str]
    dependencies_updated: dict[str, list[str]]

    def __init__(self, chart_graph: ChartGraph):
        self.chart_graph = chart_graph
        self.version_map = self.build_version_map()
        self.original_versions = dict(self.version_map)
        self.updated_charts = set()
        self.dependencies_updated = {}

    def build_version_map(self):
        version_map = {}
        for chart in self.chart_graph.charts.values():
            version_map[chart.name] = Version.parse(chart.version)
        return version_map

    def get_version(self, chart_name: str) -> str:
        return str(self.version_map.get(chart_name, "unknown"))

    def cascade_bump(
        self, chart: ChartInfo, part: str, dependency: Optional[ChartInfo] = None
    ):
        """Bump the version of the specified chart and cascade to dependents."""
        if chart.name not in self.version_map:
            return

        # If a dependency is specified, ensure it was updated
        dependency_updated = (
            self.bump_dependency(chart, dependency, self.get_version(dependency.name))
            if dependency
            else False
        )

        # Avoid re-processing charts
        if chart.name in self.updated_charts:
            return

        if dependency is None or dependency_updated:
            # Bump the specified chart
            new_version = self.bump_version(self.version_map[chart.name], part)
            if not new_version:
                return

            chart.version = str(new_version)
            self.version_map[chart.name] = new_version
            self.updated_charts.add(chart.name)

        # Find dependents and bump them as well
        dependents = self.chart_graph.find_subtree(
            chart.name, self.chart_graph.dependent_selector()
        )
        # Recursively bump dependents
        for dep in dependents.next:
            self.cascade_bump(dep.info, part, chart)

    def bump_dependency(
        self, chart: ChartInfo, dependency: ChartInfo, new_version: str
    ) -> bool:
        """Update the version of a dependency in the specified chart."""
        updated = False
        for dep in chart.dependencies:
            if dep.get("name") == dependency.name:
                dep["version"] = f"{new_version}"
                updated = True
                break
        if updated:
            self.dependencies_updated.setdefault(chart.name, []).append(dependency.name)
        return updated

    def bump_version(self, current_version: Version, part: str) -> Version:
        """Bump the version of the specified chart."""
        if part == "major":
            new_version = current_version.bump_major()
        elif part == "minor":
            new_version = current_version.bump_minor()
        elif part == "patch":
            new_version = current_version.bump_patch()
        else:
            raise ValueError("part must be 'major', 'minor', or 'patch'")

        return new_version

    def save_versions(self):
        """Save updated versions back to Chart.yaml files."""
        for chart_name in self.updated_charts:
            chart = self.chart_graph.charts.get(chart_name)
            if chart:
                chart.save_chart_yaml()

    def print_updates(self, output_format: str = "text"):
        """Print the updated charts and their new versions."""
        sorted_updates = sorted(self.updated_charts)

        if output_format == "json":
            root = git_root()
            result = {"updated": []}
            for chart_name in sorted_updates:
                chart = self.chart_graph.charts.get(chart_name)
                try:
                    path = str(chart.path.relative_to(root)) if chart else ""
                except ValueError:
                    path = str(chart.path) if chart else ""
                updates = {
                    "name": chart_name,
                    "previous_version": str(
                        self.original_versions.get(chart_name, "unknown")
                    ),
                    "version": self.get_version(chart_name),
                    "path": path,
                }
                result["updated"].append(
                    updates
                    | (
                        {
                            "dependencies": [
                                {"name": d, "version": self.get_version(d)}
                                for d in self.dependencies_updated[chart_name]
                            ]
                        }
                        if chart_name in self.dependencies_updated
                        else {}
                    )
                )
            click.echo(json.dumps(result, indent=2))
            return

        if output_format == "markdown":
            click.echo("| Chart | Current Version | New Version |")
            click.echo("|-------|-----------------|-------------|")
            for chart_name in sorted_updates:
                prev = str(self.original_versions.get(chart_name, "unknown"))
                new = self.get_version(chart_name)
                click.echo(f"| `{chart_name}` | `{prev}` | **`{new}`** |")
            return

        click.echo("Updating chart versions:")
        for chart_name in sorted_updates:
            click.echo(f"{chart_name}: {self.get_version(chart_name)}")
            if chart_name in self.dependencies_updated:
                for d in self.dependencies_updated[chart_name]:
                    click.echo(
                        f"    - dependency: {d} -> {self.chart_graph.get_chart(d).version}"
                    )
