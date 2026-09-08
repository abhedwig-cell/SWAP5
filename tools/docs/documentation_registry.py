#!/usr/bin/env python3
"""Generate or validate the DOC-Q01 canonical documentation registry."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / "docs"
REGISTRY = DOCS / "governance" / "documentation-registry.json"
CONTROL_ARTIFACTS = (
    ROOT / "mkdocs.yml",
    ROOT / "requirements-docs.txt",
    ROOT / ".github" / "workflows" / "docs.yml",
    ROOT / "tools" / "docs" / "check_docs.py",
    ROOT / "tools" / "docs" / "documentation_registry.py",
    ROOT / "tools" / "docs" / "verify_publication.py",
)
SCHEMA_VERSION = "doc-q01-registry-v1"
CANONICAL_SOURCE_COMMIT = "7f906fcc53a4133b0e410eac7cf79fbb4eb672ab"
GOVERNANCE_INPUT_COMMIT = "a6b991b4702e061accd1b16f9450f99e18aba032"

CATEGORIES = {
    "SCIENTIFIC_MODEL_DESCRIPTION",
    "TECHNICAL_ARCHITECTURE",
    "PARAMETERS_AND_VARIABLES",
    "VERIFICATION_AND_QUALIFICATION",
    "APPLICABILITY_AND_LIMITATIONS",
    "USER_DOCUMENTATION",
    "MODEL_QUALITY_AND_UNCERTAINTY",
    "LEGACY_AND_REFERENCE",
    "DEVELOPMENT_AND_VERSION_HISTORY",
    "OPERATIONS_AND_MAINTENANCE",
}
PUBLICATION_STATUSES = {
    "DRAFT", "DEVELOPMENT", "REVIEWED", "RECONCILED",
    "PUBLISHED_CANONICAL", "SUPERSEDED", "ARCHIVED",
}
QUALITY_STATUSES = {
    "NOT_ASSESSED", "DOCUMENTED", "IMPLEMENTATION_TRACED",
    "TEST_EVIDENCED", "QUALIFIED",
}
REQUIRED_FIELDS = {
    "document_id", "path", "title", "category", "intended_audience",
    "source_of_truth", "publication_status", "quality_status",
    "related_component", "related_workstream", "related_source_commit",
    "theory_reference", "implementation_reference",
    "test_or_evidence_reference", "known_discrepancies", "status",
}
HEADING = re.compile(r"^#\s+(.+?)\s*$", re.MULTILINE)


def nav_targets() -> set[str]:
    config = yaml.safe_load((ROOT / "mkdocs.yml").read_text(encoding="utf-8"))

    def walk(node):
        if isinstance(node, str):
            yield node
        elif isinstance(node, list):
            for item in node:
                yield from walk(item)
        elif isinstance(node, dict):
            for value in node.values():
                yield from walk(value)

    return {f"docs/{p}" for p in walk(config["nav"]) if p.endswith(".md")}


def category_for(path: str) -> str:
    if not path.startswith("docs/"):
        return "OPERATIONS_AND_MAINTENANCE"
    if path.endswith("benchmark-record.schema.json"):
        return "PARAMETERS_AND_VARIABLES"
    if path.startswith("docs/architecture/") or path.startswith("docs/decisions/"):
        return "TECHNICAL_ARCHITECTURE"
    if path.startswith("docs/verification/") or path.startswith("docs/integration/"):
        return "VERIFICATION_AND_QUALIFICATION"
    if path.startswith("docs/legacy/"):
        return "LEGACY_AND_REFERENCE"
    if path.startswith("docs/performance/"):
        return "MODEL_QUALITY_AND_UNCERTAINTY"
    if path.startswith("docs/development/"):
        return "DEVELOPMENT_AND_VERSION_HISTORY"
    if path.startswith("docs/governance/"):
        return "OPERATIONS_AND_MAINTENANCE"
    return "USER_DOCUMENTATION"


def audience_for(category: str) -> list[str]:
    if category == "USER_DOCUMENTATION":
        return ["users", "developers"]
    if category in {"VERIFICATION_AND_QUALIFICATION", "MODEL_QUALITY_AND_UNCERTAINTY"}:
        return ["reviewers", "scientists", "developers"]
    return ["maintainers", "developers", "reviewers"]


def title_for(path: Path) -> str:
    if path == REGISTRY and not path.exists():
        return "DOC-Q01 canonical documentation registry"
    if path.suffix == ".md":
        match = HEADING.search(path.read_text(encoding="utf-8"))
        return match.group(1).strip() if match else "UNKNOWN"
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError):
        return path.name
    return str(data.get("title") or path.name)


def record_for(path: Path, visible: set[str]) -> dict:
    relative = path.relative_to(ROOT).as_posix()
    category = category_for(relative)
    is_governance = relative.startswith("docs/governance/")
    return {
        "document_id": "DOC-" + re.sub(r"[^A-Z0-9]+", "-", relative.upper()).strip("-"),
        "path": relative,
        "title": title_for(path),
        "category": category,
        "intended_audience": audience_for(category),
        "source_of_truth": relative,
        "publication_status": "DEVELOPMENT" if is_governance else "REVIEWED",
        "quality_status": "DOCUMENTED" if is_governance else "NOT_ASSESSED",
        "online_navigation_candidate": relative in visible,
        "related_component": "documentation-governance" if is_governance else "UNKNOWN",
        "related_workstream": "DOC-Q01" if is_governance else "UNKNOWN",
        "related_source_commit": CANONICAL_SOURCE_COMMIT if is_governance else "UNKNOWN",
        "theory_reference": "NOT_APPLICABLE" if is_governance else "UNKNOWN",
        "implementation_reference": "NOT_APPLICABLE" if is_governance else "UNKNOWN",
        "test_or_evidence_reference": (
            "tools/docs/documentation_registry.py" if is_governance else "UNKNOWN"
        ),
        "known_discrepancies": [] if is_governance else ["DOC-Q01 provenance and content assessment pending"],
        "status": "ACTIVE",
    }


def build_registry() -> dict:
    visible = nav_targets()
    paths = [p for p in DOCS.rglob("*") if p.is_file() and p != REGISTRY]
    paths.extend(CONTROL_ARTIFACTS)
    paths.sort()
    records = [record_for(path, visible) for path in paths]
    records.append(record_for(REGISTRY, visible))
    records.sort(key=lambda item: item["path"])
    return {
        "schema_version": SCHEMA_VERSION,
        "registry_id": "DOC-Q01-CANONICAL-DOCUMENTATION-REGISTRY",
        "generated_from": {
            "repository": "abhedwig-cell/SWAP5",
            "canonical_source_branch": "integration/f-ci-canonical",
            "canonical_source_commit": CANONICAL_SOURCE_COMMIT,
            "documentation_governance_input_commit": GOVERNANCE_INPUT_COMMIT,
            "corrected_legacy_reference": "B1.10",
            "inventory_base_commit": GOVERNANCE_INPUT_COMMIT,
        },
        "policy": {
            "online_visibility_is_canonical_publication": False,
            "publication_implies_qualification": False,
            "unknown_provenance_is_fail_closed": True,
        },
        "documents": records,
    }


def validate(data: dict) -> None:
    errors: list[str] = []
    if data.get("schema_version") != SCHEMA_VERSION:
        errors.append("unexpected schema_version")
    records = data.get("documents")
    if not isinstance(records, list):
        errors.append("documents must be a list")
        records = []
    paths: list[str] = []
    ids: list[str] = []
    for index, record in enumerate(records):
        missing = REQUIRED_FIELDS - set(record)
        if missing:
            errors.append(f"record {index} misses {sorted(missing)}")
        if record.get("category") not in CATEGORIES:
            errors.append(f"record {index} has invalid category")
        if record.get("publication_status") not in PUBLICATION_STATUSES:
            errors.append(f"record {index} has invalid publication_status")
        if record.get("quality_status") not in QUALITY_STATUSES:
            errors.append(f"record {index} has invalid quality_status")
        paths.append(record.get("path", ""))
        ids.append(record.get("document_id", ""))
    if len(paths) != len(set(paths)) or len(ids) != len(set(ids)):
        errors.append("document paths and IDs must be unique")
    actual = {p.relative_to(ROOT).as_posix() for p in DOCS.rglob("*") if p.is_file()}
    actual.update(p.relative_to(ROOT).as_posix() for p in CONTROL_ARTIFACTS)
    if set(paths) != actual:
        errors.append(f"inventory mismatch: missing={sorted(actual-set(paths))}, stale={sorted(set(paths)-actual)}")
    if errors:
        raise SystemExit("Registry validation failed:\n- " + "\n- ".join(errors))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true", help="regenerate the registry")
    args = parser.parse_args()
    if args.write:
        REGISTRY.parent.mkdir(parents=True, exist_ok=True)
        REGISTRY.write_text(json.dumps(build_registry(), indent=2) + "\n", encoding="utf-8")
    data = json.loads(REGISTRY.read_text(encoding="utf-8"))
    validate(data)
    print(f"Documentation registry valid: {len(data['documents'])} artifacts")


if __name__ == "__main__":
    main()
