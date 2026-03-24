import subprocess
from pathlib import Path
from typing import Optional
import click
from git import Blob, Repo


repo = Repo(search_parent_directories=True)


def git_root() -> Path:
    """Locate the root of the git repository."""
    if repo.working_tree_dir is None:
        raise Exception("No git repository found.")
    return Path(repo.working_tree_dir)


def staged_files() -> list[str]:
    """Get files staged for commit."""
    # a_path = path in HEAD, b_path = path in index; both collected to handle renames
    paths = set()
    for diff in repo.index.diff("HEAD"):
        if diff.a_path:
            paths.add(diff.a_path)
        if diff.b_path:
            paths.add(diff.b_path)
    return list(paths)


def diff_files(base_ref: str) -> list[str]:
    """Get files changed between base_ref and HEAD (three-dot diff)."""
    result = subprocess.run(
        ["git", "diff", "--name-only", f"{base_ref}...HEAD"],
        capture_output=True,
        text=True,
        cwd=str(git_root()),
    )
    if result.returncode != 0:
        raise click.ClickException(
            f"git diff failed for ref '{base_ref}':\n{result.stderr.strip()}"
        )
    return [line for line in result.stdout.splitlines() if line]


def get_commit_tree(commit: str):
    """Get the tree object for a specific commit."""
    return repo.commit(commit).tree


def get_commit_blob(commit: str, file_path: str) -> Optional[Blob]:
    """Get the contents of a file at a specific commit."""
    from .files import make_path_root_relative

    tree = get_commit_tree(commit)
    blob = tree / str(make_path_root_relative(Path(file_path)))
    if isinstance(blob, Blob):
        return blob
    return None
