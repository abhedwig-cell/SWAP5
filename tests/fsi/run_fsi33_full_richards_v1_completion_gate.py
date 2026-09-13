#!/usr/bin/env python3
import json
import subprocess
import sys
from pathlib import Path

EXPECTED_CANONICAL = "267f2a6ec61f78d3ba4ce75b3e5a7fdc08479135"
EXPECTED_TREE = "a3f9f82e62337569edb3615c3a47c2df9101ee81"
DECISION = "QUALIFIED_FULL_RICHARDS_REFERENCE_SOLVER_V1_100_PERCENT_COMPLETE"

EXPECTED_BLOBS = {
    "src/solver/mod_soil_water_solver_contract.f90": "276941d76ba951a89c43899e61fd0532418d8230",
    "src/solver/mod_reference_richards_workspace.f90": "74f99556005ae39614f9df678467b1e19097bae2",
    "src/solver/mod_reference_richards_state_binding.f90": "a2488ce3a6a6eff665a59d3dd68907d26f8304ec",
    "src/solver/mod_reference_richards_temporal_indicator.f90": "fe8f87d11257d4c6bc019f1d628ac41ba3106d4e",
    "src/solver/mod_reference_linear_solver.f90": "5b6ecd2341b315967bcfac6b879c3afe227fb245",
    "src/solver/mod_process_hydraulic_view.f90": "d7d85fe71ced0d94b29c8d9395859ae1834f7dd6",
    "src/solver/mod_b110_default_mvg_provider.f90": "fea5a1681b1c3bdefce1cdbb6d48a9396c8266b6",
    "src/solver/mod_b110_dynamic_top_boundary_provider.f90": "3eadae0f32aba49534cd58464e28c0af5bc9bf7d",
    "src/solver/mod_fixed_flux_top_boundary_provider.f90": "fb226f133bd48d8ab945f111c76897aeff49facf",
    "src/adapter/mod_reference_richards_legacy_binding.f90": "03a64b6d09fd804242bcf76f7cb5277f59a6230a",
    "src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90": "7a3cc3d01d994ea21bb0b48798cd2fb4aba9495e",
    "src/adapter/mod_b110_production_soil_water_task2.f90": "ec24ad9b01f58bd2c17a296adf1158b6c4fb656f",
    "src/legacy/b1_10_port/headcalc.f90": "3ff8d5cfd6963dfb7dafb33ec454fbc0df938a55",
    "src/runtime/mod_a23bu_worker_execution_context.f90": "d37114e1a43df0c4592d11d701f8d1ce596e50fd",
    "src/runtime/mod_fmr_serialized_reference_backend.f90": "d565b893a08d92c46077995fdec544584aa04664",
}

ALLOWED_PREFIXES = (
    "integration/f-si/F-SI33_",
    "tests/fsi/run_fsi33_full_richards_v1_completion_gate.py",
    ".github/workflows/fsi33-full-richards-v1-final-qualification.yml",
)


def run(*args: str) -> str:
    return subprocess.check_output(args, text=True).strip()


def fail(message: str) -> None:
    print(f"FSI33_GATE_FAIL {message}", file=sys.stderr)
    raise SystemExit(1)


def load(path: str):
    try:
        return json.loads(Path(path).read_text())
    except Exception as exc:
        fail(f"cannot parse {path}: {exc}")


def main() -> None:
    live_ref = "refs/remotes/origin/integration/f-ci-canonical"
    try:
        live_canonical = run("git", "rev-parse", live_ref)
    except Exception:
        fail("live integration/f-ci-canonical remote ref missing; workflow must fetch it")
    if live_canonical != EXPECTED_CANONICAL:
        fail(f"canonical drift: expected {EXPECTED_CANONICAL}, got {live_canonical}")
    tree = run("git", "rev-parse", f"{EXPECTED_CANONICAL}^{{tree}}")
    if tree != EXPECTED_TREE:
        fail(f"canonical tree mismatch: expected {EXPECTED_TREE}, got {tree}")
    merge_base = run("git", "merge-base", "HEAD", EXPECTED_CANONICAL)
    if merge_base != EXPECTED_CANONICAL:
        fail(f"branch is not based on exact canonical; merge-base={merge_base}")

    changed = [p for p in run("git", "diff", "--name-only", f"{EXPECTED_CANONICAL}..HEAD").splitlines() if p]
    unexpected = [p for p in changed if not any(p.startswith(prefix) for prefix in ALLOWED_PREFIXES)]
    if unexpected:
        fail("unexpected changes outside F-SI33 evidence/gate surface: " + ", ".join(unexpected))
    if any(p.startswith("src/") or p.startswith("reference/") for p in changed):
        fail("production/reference source changed by F-SI33")

    for path, expected in EXPECTED_BLOBS.items():
        actual = run("git", "rev-parse", f"HEAD:{path}")
        if actual != expected:
            fail(f"source blob mismatch {path}: expected {expected}, got {actual}")

    audit = load("integration/f-si/F-SI33_COMPLETENESS_AUDIT.json")
    authority = load("integration/f-si/F-SI33_FULL_RICHARDS_REFERENCE_SOLVER_V1_COMPLETION_AUTHORITY.json")
    result = load("integration/f-si/F-SI33_F_RG01C_COMPLETION_RESULT.json")
    status_path = Path("integration/f-si/F-SI33_STATUS.json")
    status = load(str(status_path)) if status_path.exists() else None

    if audit.get("decision") != DECISION or audit.get("completion_percent") != 100.0:
        fail("audit decision/completion mismatch")
    if audit.get("gaps") != [] or audit.get("production_source_changed_by_F_SI33") is not False:
        fail("audit contains gaps or source change")
    criteria = audit.get("criteria", [])
    if len(criteria) != 20:
        fail(f"expected 20 criteria, got {len(criteria)}")
    valid_classes = {"PASS_CURRENT_CANONICAL", "PASS_PRESERVED", "PASS_BY_EXISTING_INDEPENDENT_QUALIFICATION", "OUTSIDE_FROZEN_SCOPE"}
    for item in criteria:
        if item.get("classification") not in valid_classes:
            fail(f"criterion {item.get('id')} is not passing/frozen-scope classified")
    hard = audit.get("hard_100_percent_gates", {})
    if any(not str(value).startswith("PASS") for value in hard.values()):
        fail("one or more hard 100 percent gates are not PASS")

    if authority.get("decision") != DECISION or authority.get("gap_count") != 0:
        fail("completion authority mismatch")
    if authority.get("canonical_preservation_authority", {}).get("sha") != EXPECTED_CANONICAL:
        fail("completion authority canonical mismatch")
    if authority.get("denominator_changed") is not False or authority.get("scope_reduced") is not False:
        fail("completion authority changed denominator or scope")
    if authority.get("production_source_changed") is not False or authority.get("reference_source_changed") is not False:
        fail("completion authority reports source change")

    if result.get("decision") != DECISION or result.get("domain_id") != "D03":
        fail("F-RG01C completion result mismatch")
    if result.get("set_completion_percent") != 100.0 or result.get("set_earned_weight") != 8.0:
        fail("F-RG01C D03 completion values mismatch")
    if result.get("denominator_unchanged") is not True or result.get("scope_reduced") is not False:
        fail("F-RG01C denominator/scope invariant mismatch")

    fci49p = load("integration/f-ci/F-CI49P_STATUS.json")
    if fci49p.get("decision") != "QUALIFIED_FCI49_POSTIMAGE_AND_MOVING_PRESERVATION_AUTHORITY_RECONCILIATION_FINALIZED":
        fail("F-CI49P definitive solver-service preservation authority missing")
    if fci49p.get("definitive_fkt15_source") != "48336cb7f14e9246b03c23e549fe7354a93f9e6b":
        fail("F-CI49P definitive F-KT15 source mismatch")
    if fci49p.get("state", {}).get("post_reconciliation_broad_canonical_green") is not True:
        fail("F-CI49P broad post-reconciliation gate not green")

    fci57 = load("integration/f-ci/F-CI57_STATUS.json")
    if fci57.get("completion_authority_statement") != "QUALIFIED_KERNEL_TRANSACTIONS_GENERIC_TIME_MASS_V1_100_PERCENT_COMPLETE":
        fail("current canonical F-CI57/F-KT mass completion authority missing")
    if fci57.get("mass_conservation") != "PASS_FAIL_CLOSED_COMPLETE_ZERO_MASK_FINITE_RESIDUAL_WITHIN_TOLERANCE":
        fail("current canonical fail-closed mass authority mismatch")

    if status is not None:
        if status.get("decision") != DECISION or status.get("completion_percent") != 100.0:
            fail("final status mismatch")
        if status.get("current_canonical", {}).get("sha") != EXPECTED_CANONICAL:
            fail("final status canonical mismatch")
        if status.get("production_source_changed") is not False:
            fail("final status reports production source change")

    print(f"FSI33_GATE {DECISION}")


if __name__ == "__main__":
    main()
