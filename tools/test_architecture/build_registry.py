#!/usr/bin/env python3
"""Build the F-TA01 register from explicit suite metadata and repository discovery."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "test-architecture" / "test-register.json"


SUITES = {
    "fci": {
        "component": "canonical-integration",
        "owner": "F-CI",
        "contract": "canonical source, transaction, interval, mass and exit-gate contracts",
        "invariants": [1, 2, 3, 7, 9, 13, 23, 29, 30],
        "surface": ["src/adapter/**", "src/runtime/**", "src/transaction/**", "integration/f-ci/**"],
        "dependencies": ["corrected B1.10 reference", "gfortran", "Python 3"],
        "expected": "ARCHITECTURE_CONTRACT",
        "tolerance": "test-owned; UNKNOWN where the runner does not expose it",
        "cost": "FOCUSED",
    },
    "fkt": {
        "component": "kernel-transactions",
        "owner": "F-KT",
        "contract": "checkpoint, trial, retry, commit, rollback and temporal provenance",
        "invariants": [3, 5, 7, 8, 9, 13, 29, 30],
        "surface": ["src/kernel/**", "src/transaction/**", "src/runtime/mod_canonical_*"],
        "dependencies": ["gfortran", "canonical contracts"],
        "expected": "ARCHITECTURE_CONTRACT",
        "tolerance": "exact contract assertions; mass tolerance remains runner-owned",
        "cost": "FOCUSED",
    },
    "fmr": {
        "component": "multiswap-runtime",
        "owner": "F-MR",
        "contract": "runtime composition, isolation and serialized physical dispatch",
        "invariants": [4, 5, 6, 7, 8, 13, 16, 23, 24, 26, 27, 28, 30],
        "surface": ["src/runtime/**", "src/kernel/**", "src/adapter/**", "integration/f-mr/**"],
        "dependencies": ["F-KT", "F-SI", "corrected B1.10 reference", "gfortran"],
        "expected": "ARCHITECTURE_CONTRACT",
        "tolerance": "runner-owned; F-MR04/F-MR05 authoritative mass gate 1e-12",
        "cost": "BROAD",
    },
    "fsi": {
        "component": "solver-isolation",
        "owner": "F-SI",
        "contract": "solver interface, binding and workspace isolation",
        "invariants": [3, 5, 20, 21, 22, 23, 25, 30],
        "surface": ["src/solver/**", "src/legacy/b1_10_port/**", "src/adapter/mod_reference_richards_*"],
        "dependencies": ["corrected B1.10 reference", "gfortran"],
        "expected": "ARCHITECTURE_CONTRACT",
        "tolerance": "UNKNOWN unless stated by the owning F-SI evidence",
        "cost": "FOCUSED",
    },
    "fvq": {
        "component": "independent-qualification",
        "owner": "F-VQ",
        "contract": "exact source-bound independent scientific admission",
        "invariants": [7, 9, 13, 16, 25, 26, 30],
        "surface": ["candidate checkout at pinned commit", "integration/f-vq/**"],
        "dependencies": ["exact candidate checkout", "qualified immutable reference package", "gfortran"],
        "expected": "QUALIFIED_GOLDEN_CASE",
        "tolerance": "bitwise state/mass identity plus hard mass residual <= 1e-12",
        "cost": "QUALIFICATION",
    },
    "transaction": {
        "component": "transaction-reference",
        "owner": "A23BL",
        "contract": "transaction attempt context and reference semantics",
        "invariants": [7, 8, 13, 30],
        "surface": ["src/transaction/**"],
        "dependencies": ["gfortran", "OpenMP runtime"],
        "expected": "ARCHITECTURE_CONTRACT",
        "tolerance": "exact contract assertions",
        "cost": "FAST",
    },
    "runtime": {
        "component": "worker-runtime",
        "owner": "A23BU",
        "contract": "worker-owned execution context",
        "invariants": [5, 6, 16, 26, 27, 30],
        "surface": ["src/runtime/mod_a23bu_worker_execution_context.f90"],
        "dependencies": ["gfortran"],
        "expected": "ARCHITECTURE_CONTRACT",
        "tolerance": "exact contract assertions",
        "cost": "FAST",
    },
    "performance": {
        "component": "performance-tooling",
        "owner": "MP",
        "contract": "measurement, repeatability, workload and host-admission tooling",
        "invariants": [6, 16, 24, 26, 30],
        "surface": ["tools/performance/**", "benchmarks/performance/**"],
        "dependencies": ["Python 3", "host-dependent optional measurement inputs"],
        "expected": "INVARIANT",
        "tolerance": "protocol-owned; performance observations are not scientific tolerances",
        "cost": "FAST",
    },
    "vq": {
        "component": "corrected-reference-qualification",
        "owner": "F-VQ",
        "contract": "reference identity, reconstruction and water-balance qualification",
        "invariants": [13, 25, 30],
        "surface": ["tools/vq/**", "reference/swap-4.3.1/**"],
        "dependencies": ["Python 3", "corrected reference snapshots", "external compiler/case where requested"],
        "expected": "CORRECTED_LEGACY_REFERENCE",
        "tolerance": "case-owned; UNKNOWN unless pinned in the case or gate",
        "cost": "FOCUSED",
    },
    "reference_patch": {
        "component": "corrected-reference-patches",
        "owner": "VQ/reference",
        "contract": "individual corrected legacy findings and admissions",
        "invariants": [13, 25, 30],
        "surface": ["reference/swap-4.3.1/patches/**"],
        "dependencies": ["exact B0/B1 preimage", "patch-specific compiler and fixture"],
        "expected": "CORRECTED_LEGACY_REFERENCE",
        "tolerance": "patch-owned; UNKNOWN where no executable gate declares it",
        "cost": "FOCUSED",
    },
}


def command_for(path: str) -> str:
    if path.endswith(".sh"):
        return f"bash {path}"
    if path.startswith("tests/test_") or path.startswith("tools/vq/test_"):
        return f"python3 -m unittest {path[:-3].replace('/', '.')}"
    if path.endswith("_gate.py") or path.endswith("verify_source_archive.py"):
        return f"python3 {path}"
    return "NOT_DIRECTLY_EXECUTABLE"


def category_for(path: str, suite: str) -> str:
    if suite == "fvq" or "admission_gate" in path or "qualification" in path:
        return "QG"
    if path.endswith(".f90") or path.endswith(".F90"):
        return "CT"
    if path.startswith("tests/test_") or "/test_" in path:
        return "UT"
    if "reference" in path or suite in {"vq", "reference_patch"}:
        return "RR"
    return "IT"


def stable_id(path: str, category: str) -> str:
    token = path.upper()
    for old, new in ((".GITHUB/WORKFLOWS/", "WF-"), ("REFERENCE/SWAP-4.3.1/PATCHES/", ""),
                     ("TESTS/", ""), ("TOOLS/", ""), ("/RUN_", "/"), ("/TEST_", "/")):
        token = token.replace(old, new)
    token = token.rsplit(".", 1)[0]
    token = "-".join(part for part in token.replace("_", "-").replace("/", "-").split("-") if part)
    return f"{category}-{token}"


def discover() -> list[tuple[str, str, str]]:
    found: list[tuple[str, str, str]] = []
    patterns = [
        ("tests", "*"),
        ("tools/vq", "test_*.py"),
        ("tools/vq", "*_gate.py"),
        ("reference/swap-4.3.1/patches", "run_*_gate.py"),
        ("reference/swap-4.3.1/b0", "verify_source_archive.py"),
        (".github/workflows", "*.yml"),
    ]
    for base, pattern in patterns:
        for item in sorted((ROOT / base).rglob(pattern)):
            if not item.is_file() or "__pycache__" in item.parts:
                continue
            path = item.relative_to(ROOT).as_posix()
            if path.startswith(".github/"):
                suite = "performance" if "performance" in path else ("fvq" if "fvq" in path else ("vq" if "vq-" in path else path.split("/")[-1].split("-")[0]))
            elif path.startswith("reference/"):
                suite = "reference_patch" if "/patches/" in path else "vq"
            elif path.startswith("tools/vq/"):
                suite = "vq"
            else:
                first = path.split("/")[1]
                suite = "performance" if first.startswith("test_mp_") else first
            if suite not in SUITES:
                suite = "performance" if "performance" in path else "vq"
            role = "workflow" if path.startswith(".github/") else ("runner" if "run_" in item.name or item.name.endswith("_gate.py") else ("support" if "stubs" in item.name or item.name.startswith("mod_") else "test_source"))
            found.append((path, suite, role))
    return sorted(set(found))


def main() -> None:
    records = []
    seen_ids: set[str] = set()
    for path, suite, artifact_role in discover():
        meta = SUITES[suite]
        category = "QG" if artifact_role == "workflow" else category_for(path, suite)
        test_id = stable_id(path, category)
        if test_id in seen_ids:
            raise SystemExit(f"duplicate test_id: {test_id}")
        seen_ids.add(test_id)
        directly_executable = command_for(path) != "NOT_DIRECTLY_EXECUTABLE"
        records.append({
            "test_id": test_id,
            "name": Path(path).stem.replace("_", " "),
            "category": category,
            "component": meta["component"],
            "workstream_owner": meta["owner"],
            "scientific_process_or_contract": meta["contract"],
            "requirement_or_invariant": [f"INV-{n:02d}" for n in meta["invariants"]],
            "source_surface": meta["surface"],
            "dependencies": meta["dependencies"],
            "fixture": "declared inside owning runner or UNKNOWN",
            "expected_value_source": meta["expected"],
            "tolerance_policy": meta["tolerance"],
            "execution_command": command_for(path),
            "cost_class": "QUALIFICATION" if artifact_role == "workflow" else meta["cost"],
            "qualification_role": "formal source-bound gate" if category == "QG" else "supporting evidence only; does not promote itself",
            "current_status": "DISCOVERED_NOT_REEXECUTED_FTA01",
            "artifact_path": path,
            "artifact_role": artifact_role,
            "traceable_alias": Path(path).stem.upper().replace("RUN_", "").replace("TEST_", "").replace("_GATE", "").replace("_", "-"),
        })
    payload = {
        "schema_version": 1,
        "work_unit": "F-TA01",
        "baseline_qualification_head": "65efc66cc76fa9005eac46e5779439c5ada574d1",
        "qualified_candidate_source_commit": "c28e7a2810b4a3678c577335a6a3086b173eb976",
        "qualified_candidate_source_tree": "a1a161e5e33fc143a7dc7f3c1b9749fc96f861f6",
        "reference": "B1.10 corrected legacy reference",
        "status_semantics": "Discovery does not inherit PASS or qualification from historical evidence.",
        "categories": {"UT": "unit", "CT": "contract/component", "IT": "integration", "INV": "invariant", "RR": "reference regression", "QG": "qualification gate"},
        "cost_classes": ["FAST", "FOCUSED", "BROAD", "QUALIFICATION"],
        "tests": records,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)} with {len(records)} records")


if __name__ == "__main__":
    main()
