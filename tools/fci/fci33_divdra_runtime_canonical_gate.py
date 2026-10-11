#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE_CANONICAL = "49863406a6112baa9956f9396b34e7188934e0d4"
OWNER_CLOSEOUT = "419c463b06de72e2d8b659b03354aa03ffc114e2"
FVQ49_CLOSEOUT = "290f627c7a2b61e7de96c2e9659baa533e5526c6"
CANDIDATE = "src/runtime/mod_fmr_divdra_runtime_binding.f90"
CANDIDATE_BLOB = "e4737fb6f00a11ed16e34bee44b3442ac84b31aa"
DEPENDENCIES = {
    "src/process/mod_drainage_spatial_distribution.f90": "1f538174b7451aaa7a3c50d6078b7c1fc3ad8f5a",
    "src/solver/mod_process_hydraulic_view.f90": "d7d85fe71ced0d94b29c8d9395859ae1834f7dd6",
    "src/runtime/mod_fmr_serialized_reference_backend.f90": "9af5a494526810324dc00706b444e448e770cba9",
    "src/solver/mod_b110_source_sink_provider.f90": "d6c57add72387e5c0022a44319fff08046194aac",
}
FVQ49_STATUS = "integration/f-vq/F-VQ49_STATUS.json"
PLAN = ROOT / "integration/f-ci/F-CI33_QUALIFICATION_PLAN.json"
AUDIT = ROOT / "integration/f-ci/F-CI33_ARCHITECTURE_AUDIT.json"


def git(*args: str) -> str:
    return subprocess.check_output(["git", "-C", str(ROOT), *args], text=True).strip()


def quiet(*args: str) -> bool:
    return subprocess.run(
        ["git", "-C", str(ROOT), *args],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    ).returncode == 0


def blob(rev: str, path: str) -> str:
    return git("rev-parse", f"{rev}:{path}")


def require(condition: bool, label: str) -> None:
    if not condition:
        raise SystemExit(f"FCI33_FAIL {label}")
    print(f"FCI33_{label}=PASS")


def ensure_authority(commit: str, branch: str) -> None:
    if quiet("cat-file", "-e", f"{commit}^{{commit}}"):
        return
    subprocess.check_call(["git", "-C", str(ROOT), "fetch", "--no-tags", "origin", branch])
    require(quiet("cat-file", "-e", f"{commit}^{{commit}}"), f"FETCH_{branch.replace('/', '_').upper()}")


def show_json(rev: str, path: str) -> dict:
    return json.loads(git("show", f"{rev}:{path}"))


def allowed_delta(path: str) -> bool:
    if path == CANDIDATE:
        return True
    if path.startswith("integration/f-ci/F-CI33_") or path.startswith("integration/f-ci/F-CI33R_"):
        return True
    if path.startswith("tests/fci/fci33_") or path.startswith("tests/fci/run_fci33_"):
        return True
    if path == "tools/fci/fci33_divdra_runtime_canonical_gate.py":
        return True
    if path == "tools/fci/fci33r_current_postimage_gate.py":
        return True
    if path == ".github/workflows/fci33-fmr33-divdra-runtime-canonical-admission.yml":
        return True
    if path == ".github/workflows/fci33r-current-canonical-postimage-reconciliation.yml":
        return True
    if path == ".github/workflows/fci-canonical.yml":
        return True
    return False


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("admission", "canonical"), required=True)
    args = parser.parse_args()

    ensure_authority(OWNER_CLOSEOUT, "work/f-mr33-divdra-runtime-binding")
    ensure_authority(FVQ49_CLOSEOUT, "qualification/f-vq49-fmr33-divdra-runtime-binding")

    require(quiet("merge-base", "--is-ancestor", BASE_CANONICAL, "HEAD"), "G01_BASE_IS_ANCESTOR")
    live = git("rev-parse", "refs/remotes/origin/integration/f-ci-canonical")
    if args.mode == "admission":
        require(live == BASE_CANONICAL, "G02_LIVE_CANONICAL_BASE_LOCK")
    else:
        require(live == git("rev-parse", "HEAD"), "G02_CANONICAL_HEAD_IDENTITY")

    changed_src = [p for p in git("diff", "--name-only", f"{BASE_CANONICAL}..HEAD", "--", "src").splitlines() if p]
    require(changed_src == [CANDIDATE], "G03_EXACT_ONE_NEW_SOURCE_PATH")
    require(not quiet("cat-file", "-e", f"{BASE_CANONICAL}:{CANDIDATE}"), "G04_CANDIDATE_ABSENT_ON_BASE")
    require(blob("HEAD", CANDIDATE) == CANDIDATE_BLOB, "G05_CANDIDATE_BLOB_EXACT")
    require(blob(OWNER_CLOSEOUT, CANDIDATE) == CANDIDATE_BLOB, "G06_OWNER_CANDIDATE_LOCK")
    require(quiet("diff", "--quiet", f"{BASE_CANONICAL}..HEAD", "--", "reference"), "G07_ZERO_REFERENCE_DELTA")

    all_changed = [p for p in git("diff", "--name-only", f"{BASE_CANONICAL}..HEAD").splitlines() if p]
    require(all(allowed_delta(p) for p in all_changed), "G08_DELTA_ALLOWLIST")

    for i, (path, expected) in enumerate(DEPENDENCIES.items(), start=9):
        require(blob(BASE_CANONICAL, path) == expected, f"G{i:02d}_BASE_DEPENDENCY_LOCK")
        require(blob("HEAD", path) == expected, f"G{i:02d}_HEAD_DEPENDENCY_UNCHANGED")

    fvq = show_json(FVQ49_CLOSEOUT, FVQ49_STATUS)
    require(fvq.get("decision") == "QUALIFIED_INDEPENDENT_FMR33_RESTRICTED_DIVDRA_RUNTIME_BINDING_COMPOSITION", "G13_FVQ49_DECISION_LOCK")
    candidate = fvq.get("candidate", {})
    require(candidate.get("owner_closeout") == OWNER_CLOSEOUT and candidate.get("path") == CANDIDATE and candidate.get("blob") == CANDIDATE_BLOB, "G14_FVQ49_CANDIDATE_LOCK")
    state = fvq.get("state", {})
    require(state.get("tested") is True and state.get("independently_qualified") is True and state.get("canonical_admitted") is False, "G15_FVQ49_SCOPE_LOCK")
    guard = fvq.get("independence_guard", {})
    require(guard.get("owner_tests_used_as_oracle") is False and guard.get("f_vq47_science_reopened") is False, "G16_FVQ49_INDEPENDENCE_LOCK")

    plan = json.loads(PLAN.read_text(encoding="utf-8"))
    q = plan.get("independent_qualification_authority", {})
    rerun = q.get("exact_closeout_rerun", {})
    require(plan.get("clean_base") == BASE_CANONICAL and plan.get("owner_authority", {}).get("production_blob") == CANDIDATE_BLOB, "G17_PLAN_SOURCE_LOCK")
    require(q.get("closeout") == FVQ49_CLOSEOUT and q.get("decision") == fvq.get("decision"), "G18_PLAN_QUALIFICATION_LOCK")
    require(rerun.get("run") == 34483080296 and rerun.get("job") == 102890456097 and rerun.get("conclusion") == "success", "G19_FVQ49_EXACT_RERUN_PROVENANCE")
    scope = plan.get("admission_scope", {})
    require(scope.get("modify_existing_production_source") is False and scope.get("modify_reference_source") is False and scope.get("active_runtime_callsite_composition") is False, "G20_NONCLAIM_LOCK")
    mass = plan.get("mass_governance", {})
    require(mass.get("mass_conservation_absolute") is True and mass.get("runtime_binding_may_renormalize") is False and mass.get("configurable_mass_tolerance_allowed") is False, "G21_MASS_GOVERNANCE_LOCK")

    audit = json.loads(AUDIT.read_text(encoding="utf-8"))
    entries = audit.get("entries", [])
    require(audit.get("invariant_count") == 30 and len(entries) == 30 and audit.get("violations") == 0, "G22_ARCHITECTURE_AUDIT_30_OF_30")
    require([e.get("invariant") for e in entries] == list(range(1, 31)), "G23_ARCHITECTURE_AUDIT_NUMBERING")
    require(all(e.get("disposition") != "VIOLATION" for e in entries), "G24_ARCHITECTURE_NO_VIOLATION")

    text = (ROOT / CANDIDATE).read_text(encoding="utf-8").lower()
    require("use mod_process_hydraulic_view" in text and "use mod_drainage_spatial_distribution" in text, "G25_EXPLICIT_PROCESS_BOUNDARY")
    prohibited = ("mod_fmr_serialized_reference_backend", "headcalc", "jacobian", "modflow", "open(", "read(", "write(")
    require(not any(token in text for token in prohibited), "G26_NO_FORBIDDEN_RUNTIME_COUPLING")
    require(text.count("call distribute_single_level_positive_divdra") == 1, "G27_SINGLE_PROCESS_INVOCATION")
    require("allocate(drainage_flux_by_level(1,n))" in text and "drainage_flux_by_level(1,:) = node_transfer%soil_to_drain_rate" in text, "G28_EXACT_ROW_PUBLICATION")
    require("intent(in) :: scalar_transfer" in text and re.search(r"(?m)^\s*scalar_transfer\s*=", text) is None, "G29_AUTHORITATIVE_SCALAR_NOT_MUTATED")
    require("save ::" not in text and " save " not in text, "G30_NO_PERSISTENT_SAVE_STATE")

    print(f"FCI33_MODE={args.mode}")
    print("FCI33_CANONICAL_RUNTIME_SOURCE_ADMISSION_GATE=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
