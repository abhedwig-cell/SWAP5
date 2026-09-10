#!/usr/bin/env python3
import json
from pathlib import Path
import subprocess
import sys

BASE = "8fa79a70a9faccaf8b63826df607a685eb75b046"
D3 = "eb57bd2ffa9ee33a3d198e8424edc91556957344"
D4 = "d45b5b09cb8143a9b7c01fe3021630aa5a4bf49e"
D5 = "90f8aee150df928b2cc98938c98766f037658114"
BLOBS = {
    "src/kernel/mod_kernel_transactions.f90": "f1acff10dd99c308a00f434440d6a9ef14632f0d",
    "src/transaction/mod_transaction_reference.f90": "2fd932b74dbd0ffc0ec089f49e632b7ac8852df4",
    "src/runtime/mod_fmr_checkpoint_orchestrator.f90": "232875e7192f995930c102609cee08dc8938c86a",
    "src/runtime/mod_fmr_accepted_commit_receipt.f90": "6798b3296b426950bf028814585c3f5de9be950b",
    "src/runtime/mod_fmr_divdra_runtime_binding.f90": "e4737fb6f00a11ed16e34bee44b3442ac84b31aa",
    "src/runtime/mod_fmr_divdra_serialized_runtime.f90": "9a384658ec37b68d2ef911e741aa89707dcb3e77",
}


def run(*args, check=True):
    p = subprocess.run(args, text=True, capture_output=True)
    if check and p.returncode != 0:
        sys.stderr.write(p.stdout)
        sys.stderr.write(p.stderr)
        raise SystemExit(p.returncode)
    return p


def mark(name, condition):
    if not condition:
        print(f"FPM08D6_{name}=FAIL")
        raise SystemExit(1)
    print(f"FPM08D6_{name}=PASS")


def load(path):
    return json.loads(Path(path).read_text())


def load_at(commit, path):
    return json.loads(run("git", "show", f"{commit}:{path}").stdout)


def text_at(commit, path):
    return run("git", "show", f"{commit}:{path}").stdout


def main():
    changed = [x for x in run("git", "diff", "--name-only", f"{BASE}..HEAD").stdout.splitlines() if x]
    allowed = all(
        p.startswith("integration/f-pm/F-PM08D6_")
        or p == "tests/fpm/test_fpm08d6_transactional_surface_water.py"
        or p == "tools/fpm/fpm08d6_transactional_surface_water_readiness_gate.py"
        or p == ".github/workflows/fpm08d6-transactional-surface-water-readiness.yml"
        for p in changed
    )
    mark("READINESS_ONLY_FILE_DELTA", allowed)
    mark("NO_PRODUCTION_SOURCE_DELTA", not any(p.startswith("src/") for p in changed))
    mark("NO_REFERENCE_SOURCE_DELTA", not any(p.startswith("reference/") for p in changed))

    for sha in (BASE, D3, D4, D5):
        mark(f"COMMIT_{sha[:8]}_EXISTS", run("git", "cat-file", "-e", f"{sha}^{{commit}}", check=False).returncode == 0)

    for path, expected in BLOBS.items():
        actual = run("git", "rev-parse", f"{BASE}:{path}").stdout.strip()
        mark("BLOB_" + path.split("/")[-1].replace(".", "_").upper(), actual == expected)

    contract = load("integration/f-pm/F-PM08D6_READINESS_CONTRACT.json")
    inventory = load("integration/f-pm/F-PM08D6_RUNTIME_SOURCE_INVENTORY.json")
    audit = load("integration/f-pm/F-PM08D6_ARCHITECTURE_AUDIT.json")
    status = load("integration/f-pm/F-PM08D6_STATUS.json")

    mark("BASE_LOCKED", contract["source_authority"]["exact_branch_base"] == BASE)
    upstream = contract["authoritative_upstream"]
    mark("D3_LOCKED", upstream["F-PM08D3"] == D3)
    mark("D4_LOCKED", upstream["F-PM08D4"] == D4)
    mark("D5_LOCKED", upstream["F-PM08D5"] == D5)
    mark("FCI36_FINAL_HEAD_LOCKED", upstream["F-CI36_canonical_final_governance_head"] == BASE)
    mark("FCI36_EXACT_HEAD_RUN_BOUND", upstream["F-CI36_exact_head_run"] == 34527338720)

    d3 = load_at(D3, "integration/f-pm/F-PM08D3_STATUS.json")
    d4 = load_at(D4, "integration/f-pm/F-PM08D4_STATUS.json")
    d5 = load_at(D5, "integration/f-pm/F-PM08D5_STATUS.json")
    fci36 = load_at(BASE, "integration/f-ci/F-CI36_STATUS.json")
    mark("D3_QUALIFIED", d3["status"] == "QUALIFIED_CLOSED" and d3["state"]["qualified"] is True)
    mark("D4_QUALIFIED", d4["status"] == "QUALIFIED_CLOSED" and d4["state"]["qualified"] is True)
    mark("D5_QUALIFIED", d5["status"] == "QUALIFIED_CLOSED" and d5["state"]["qualified"] is True)
    mark("D5_CAPACITY_POLICY_HELD", d5["state"]["automatic_capacity_policy_qualified"] is False)
    mark("FCI36_CANONICAL_DECISION", fci36["decision"] == "QUALIFIED_CLOSED_CANONICAL_RESTRICTED_DIVDRA_ACTIVE_RUNTIME_CALLSITE_ADMISSION")
    mark("FCI36_SCOPE_RESTRICTED", "SINGLE_LEVEL_POSITIVE_DIVDRA" in fci36["qualified_scope"])

    scope = contract["scope"]
    mark("FIXED_WEIR_SCOPE", scope["fixed_weir_physical_route"]["SWSEC_2"] is True and scope["fixed_weir_physical_route"]["SWMAN_1"] is True and scope["fixed_weir_physical_route"]["SWQHR_1"] is True)
    mark("AUTOMATIC_CAPACITY_NOT_ADMITTED", scope["automatic_control_transaction_subset"]["physical_interval_admission_requiring_automatic_capacity_policy"] is False)
    mark("SWQHR2_NOT_ADMITTED", scope["automatic_control_transaction_subset"]["SWQHR_2"] is False)
    mark("DIVDRA_SCOPE_RESTRICTED", "single-level positive" in scope["DIVDRA_runtime_subset"] and scope["multilevel_negative_or_surface_water_controlled_DIVDRA"] is False)

    mass = contract["mass_contract"]
    mark("MASS_EQUATION_BOUND", mass["equation"] == "S1-S0 = dt*(q_drain_secondary + q_rapid + q_supply - q_discharge) + V_top_surface_exchange")
    mark("MASS_COMPLETE_REQUIRED", mass["accepted_mass_complete_required"] is True)
    mark("MISSING_MASK_ZERO_REQUIRED", mass["missing_contribution_mask_must_be_zero"] is True)
    mark("SCALAR_DRAINAGE_AUTHORITATIVE", mass["q_drain_secondary_scalar_is_authoritative"] is True and mass["DIVDRA_node_field_is_not_additional_mass"] is True)
    mark("NO_PHYSICAL_MASS_CONCESSION", mass["physical_mass_conservation_absolute"] is True and mass["configurable_physical_mass_concession"] is False)
    mark("MASS_TOLERANCE_NUMERIC_ONLY", "numeric verification threshold only" in mass["mass_tolerance_role"] and "never permission" in mass["mass_tolerance_role"])

    state = contract["state_ownership"]
    mark("FIXED_STATE_COMPACT", state["persistent_fixed_weir_state"] == ["SWST"])
    mark("AUTOMATIC_STATE_COMPACT", state["persistent_automatic_control_state_when_SWMan2_active"] == ["SWST", "WLSTAR"])
    mark("WLS_DERIVED", state["derived_not_persistent"] == ["WLS"])
    mark("ROLLBACK_ALL_PHYSICAL_STATE", "SWST" in state["rollback_requirement"] and "WLSTAR" in state["rollback_requirement"] and "accepted ledger unchanged" in state["rollback_requirement"])

    holds = set(contract["explicit_holds"])
    mark("ELEVEN_HOLDS_PRESENT", len(holds) == 11)
    mark("AUTO_CAPACITY_HOLD", "D6-HOLD-01-AUTOMATIC-DISCHARGE-CAPACITY-POLICY-NOT-QUALIFIED" in holds)
    mark("DOUBLE_BOOKING_HOLD", "D6-HOLD-05-DIVDRA-NODE-FIELD-CANNOT-BE-DOUBLE-BOOKED-WITH-AUTHORITATIVE-SCALAR" in holds)
    mark("SECOND_COMMIT_AUTHORITY_HOLD", "D6-HOLD-11-RUNTIME-MUST-NOT-OWN-SECOND-COMMIT-AUTHORITY" in holds)

    inv_sources = {x["path"]: x["blob"] for x in inventory["canonical_runtime_sources"]}
    mark("INVENTORY_BLOBS_EXACT", inv_sources == BLOBS)
    mark("TWELVE_RUNTIME_RISKS_PRESENT", len(inventory["runtime_risks"]) == 12)

    invs = audit["invariants"]
    mark("ALL_30_INVARIANTS_PRESENT", len(invs) == 30 and {x["id"] for x in invs} == set(range(1, 31)))
    mark("ALL_30_INVARIANTS_PASS", all(x["pass"] for x in invs) and audit["violations"] == 0)

    kernel = text_at(BASE, "src/kernel/mod_kernel_transactions.f90")
    tx = text_at(BASE, "src/transaction/mod_transaction_reference.f90")
    orch = text_at(BASE, "src/runtime/mod_fmr_checkpoint_orchestrator.f90")
    receipt = text_at(BASE, "src/runtime/mod_fmr_accepted_commit_receipt.f90")
    bind = text_at(BASE, "src/runtime/mod_fmr_divdra_runtime_binding.f90")
    divrun = text_at(BASE, "src/runtime/mod_fmr_divdra_serialized_runtime.f90")

    mark("KERNEL_CHECKPOINT_CANDIDATE_COMMIT_SEAM", "capture_checkpoint" in kernel and "commit_candidate" in kernel and "rollback_candidate" in kernel)
    mark("TRANSACTION_COMPLETENESS_FIELDS_EXIST", "accepted_mass_complete" in tx and "accepted_missing_contribution_mask" in tx)
    mark("TRANSACTION_MASS_TOLERANCE_IS_NUMERIC_POLICY_FIELD", "mass_tolerance" in tx and "mass_rejections" in tx)
    mark("ORCHESTRATOR_DELEGATES_FKT", "committed_state%capture_checkpoint" in orch and "kernel%commit_candidate" in orch and "kernel%rollback_candidate" in orch)
    mark("RECEIPT_VALIDATES_BEFORE_COMMIT", receipt.index("checkpoint%ready()") < receipt.index("kernel%commit_candidate") and receipt.index("candidate_state%ready()") < receipt.index("kernel%commit_candidate"))
    mark("DIVDRA_SCALAR_RETAINED", "authoritative_scalar_transfer = scalar_transfer" in bind)
    mark("DIVDRA_PUBLICATION_LAST", bind.index("call distribute_single_level_positive_divdra") < bind.index("allocate(drainage_flux_by_level") < bind.index("published = .true."))
    mark("DIVDRA_PREFLIGHT_BEFORE_RUNTIME", divrun.index("call fmr_preflight_serialized_divdra") < divrun.index("call fmr_run_serialized_physical_multiswap"))
    mark("DIVDRA_TEMPORARY_FIELD_CLEANUP", "cleanup_materialized_divdra" in divrun and "deallocate(forcing_registry(forcing_index)%drainage_flux_by_level)" in divrun)

    mark("STATUS_BASE_LOCKED", status["source_authority"]["exact_branch_base"] == BASE)
    mark("STATUS_NO_PRODUCTION_CHANGE", status["state"]["production_source_changed"] is False)
    mark("STATUS_NO_REFERENCE_CHANGE", status["state"]["reference_source_changed"] is False)
    mark("STATUS_NO_RUNTIME_IMPLEMENTATION_CLAIM", status["state"]["runtime_implementation_qualified"] is False)

    oracle = run("python3", "tests/fpm/test_fpm08d6_transactional_surface_water.py")
    sys.stdout.write(oracle.stdout)
    if "FPM08D6_TRANSACTION_ORACLE PASS" not in oracle.stdout:
        sys.stderr.write(oracle.stderr)
        raise SystemExit(1)
    mark("EXECUTABLE_TRANSACTION_ORACLE", True)
    print("FPM08D6_TRANSACTIONAL_SURFACE_WATER_READINESS_GATE PASS")


if __name__ == "__main__":
    main()
