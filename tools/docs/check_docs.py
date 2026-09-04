#!/usr/bin/env python3
"""Repository-local source checks for the SWAP documentation.

These checks deliberately require only the Python standard library plus PyYAML,
which is installed by the documentation dependency set. They complement, but do
not replace, ``mkdocs build --strict``.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path, PurePosixPath
from urllib.parse import unquote, urlsplit

import yaml

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / "docs"
CONFIG = ROOT / "mkdocs.yml"

MARKDOWN_LINK_RE = re.compile(r"(?<!!)\[[^\]]*\]\(([^)]+)\)")
INVARIANT_RE = re.compile(r"^(\d+)\. \*\*", re.MULTILINE)


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_config() -> dict:
    try:
        data = yaml.safe_load(CONFIG.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"cannot parse {CONFIG.relative_to(ROOT)}: {exc}")
    if not isinstance(data, dict):
        fail("mkdocs.yml must contain a YAML mapping")
    return data


def iter_nav_targets(node):
    if isinstance(node, str):
        yield node
    elif isinstance(node, list):
        for item in node:
            yield from iter_nav_targets(item)
    elif isinstance(node, dict):
        for value in node.values():
            yield from iter_nav_targets(value)


def check_nav(config: dict) -> None:
    nav = config.get("nav")
    if nav is None:
        fail("mkdocs.yml has no nav section")
    missing = []
    for target in iter_nav_targets(nav):
        if not target.endswith(".md"):
            continue
        path = DOCS / target
        if not path.is_file():
            missing.append(target)
    if missing:
        fail("navigation targets do not exist: " + ", ".join(sorted(missing)))


def normalize_markdown_target(source: Path, raw_target: str) -> Path | None:
    target = raw_target.strip()
    if not target or target.startswith("#"):
        return None
    if target.startswith("<") and target.endswith(">"):
        target = target[1:-1].strip()
    split = urlsplit(target)
    if split.scheme or split.netloc:
        return None
    if target.startswith("mailto:"):
        return None
    path_text = unquote(split.path)
    if not path_text:
        return None
    if path_text.startswith("/"):
        return None
    return (source.parent / PurePosixPath(path_text)).resolve()


def check_markdown_links() -> None:
    broken = []
    for source in sorted(DOCS.rglob("*.md")):
        text = source.read_text(encoding="utf-8")
        for match in MARKDOWN_LINK_RE.finditer(text):
            raw_target = match.group(1).split(maxsplit=1)[0]
            candidate = normalize_markdown_target(source, raw_target)
            if candidate is None:
                continue
            if candidate.suffix == "":
                if candidate.is_dir() and (candidate / "index.md").is_file():
                    continue
            if not candidate.exists():
                broken.append(f"{source.relative_to(ROOT)} -> {raw_target}")
    if broken:
        fail("broken relative Markdown links:\n  " + "\n  ".join(broken))


def check_invariants() -> None:
    path = DOCS / "architecture" / "invariants.md"
    numbers = [int(value) for value in INVARIANT_RE.findall(path.read_text(encoding="utf-8"))]
    expected = list(range(1, 31))
    if numbers != expected:
        fail(f"architecture invariants must be exactly 1..30, found {numbers}")


def check_generated_site_not_tracked() -> None:
    site = ROOT / "site"
    if site.exists():
        fail("generated site/ directory is present; remove it before packaging or commit")


def main() -> None:
    config = load_config()
    check_nav(config)
    check_markdown_links()
    check_invariants()
    check_generated_site_not_tracked()
    print("Documentation source checks passed.")


if __name__ == "__main__":
    main()
