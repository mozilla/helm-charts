from pathlib import Path
from typing import Optional
from git import Blob, Repo


repo = Repo(search_parent_directories=True)


def git_root() -> Path:
    """Locate the root of the git repository."""
    if repo.working_tree_dir is None:
        raise Exception("No git repository found.")
    return Path(repo.working_tree_dir)


def staged_files() -> list[str]:
    """Get a list of staged files in the git repository."""
    return [
        item.a_path
        for item in repo.index.diff("HEAD")
        if item.a_path and item.change_type == "M"
    ]


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
