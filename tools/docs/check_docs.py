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
TEST_BANK_CATALOG = DOCS / "verification" / "test-bank-catalog.yaml"

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


def _catalog_path_values(value, field: str, stable_id: str) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, list) and value and all(isinstance(item, str) for item in value):
        return value
    fail(f"test-bank record {stable_id} field {field} must be a path string or non-empty path list")


def _looks_like_repository_path(value: str) -> bool:
    if any(char.isspace() for char in value):
        return False
    return value.startswith(("tests/", "testbank/", ".github/", "tools/", "docs/", "src/", "reference/", "integration/"))


def check_test_bank_catalog() -> None:
    try:
        data = yaml.safe_load(TEST_BANK_CATALOG.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"cannot parse {TEST_BANK_CATALOG.relative_to(ROOT)}: {exc}")
    if not isinstance(data, dict):
        fail("test-bank catalog must contain a YAML mapping")

    required = data.get("required_traceability_fields")
    if not isinstance(required, list) or not required or not all(isinstance(item, str) for item in required):
        fail("test-bank catalog required_traceability_fields must be a non-empty string list")

    records = data.get("bounded_registrations", [])
    if not isinstance(records, list):
        fail("test-bank catalog bounded_registrations must be a list")

    seen_ids: set[str] = set()
    missing_paths: list[str] = []
    for record in records:
        if not isinstance(record, dict):
            fail("each bounded test-bank registration must be a YAML mapping")
        stable_id = record.get("stable_id")
        if not isinstance(stable_id, str) or not stable_id:
            fail("each bounded test-bank registration must have a non-empty stable_id")
        if stable_id in seen_ids:
            fail(f"duplicate bounded test-bank stable_id: {stable_id}")
        seen_ids.add(stable_id)

        if record.get("registration_status") != "complete":
            continue

        missing_fields = [field for field in required if field not in record or record[field] in (None, "", [])]
        if missing_fields:
            fail(f"complete test-bank record {stable_id} misses fields: {', '.join(missing_fields)}")

        for field in ("test_locator", "runner"):
            for locator in _catalog_path_values(record[field], field, stable_id):
                if not _looks_like_repository_path(locator):
                    continue
                if "*" in locator or "?" in locator or "[" in locator:
                    fail(f"complete test-bank record {stable_id} uses non-exact {field}: {locator}")
                candidate = ROOT / PurePosixPath(locator)
                if not candidate.is_file():
                    missing_paths.append(f"{stable_id} {field} -> {locator}")

    if missing_paths:
        fail("complete test-bank repository locators do not exist:\n  " + "\n  ".join(missing_paths))


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
    check_test_bank_catalog()
    check_invariants()
    check_generated_site_not_tracked()
    print("Documentation source checks passed.")


if __name__ == "__main__":
    main()
