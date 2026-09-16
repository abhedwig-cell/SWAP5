#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
from pathlib import Path

BASE = "e765d96ee80af0629fb399e18bf58124dade7641"
STALE = "d81ef430ebaa601469a165dfc5b9866b813b71aa"
WORKFLOW = Path(".github/workflows/fci-canonical.yml")
MARKER = "  current-restricted-canonical-preservation:\n"

EXPECTED_SRC_DELTA = {
    "src/process/mod_restricted_soil_temperature.f90",
    "src/process/mod_restricted_surface_evaporation.f90",
    "src/process/mod_soil_temperature_contract.f90",
    "src/runtime/mod_coupling_application_accuracy_adapter.f90",
    "src/runtime/mod_coupling_application_accuracy_contract.f90",
    "src/runtime/mod_fmr_process_hydraulic_view_binding.f90",
    "src/runtime/mod_fmr_restart_state_contract.f90",
    "src/runtime/mod_fmr_serialized_reference_backend.f90",
    "src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90",
}

OLD_SURFACE = [
    "src/runtime/mod_a23bu_worker_execution_context.f90",
    "src/transaction/mod_transaction_reference.f90",
    "src/transaction/mod_fkt_temporal_indicator_history.f90",
    "src/runtime/mod_canonical_contracts.f90",
    "src/runtime/mod_canonical_interval_runtime.f90",
    "src/kernel/mod_kernel_transactions.f90",
    "src/runtime/mod_fmr_runtime_core.f90",
    "src/runtime/mod_fmr_checkpoint_orchestrator.f90",
    "src/runtime/mod_fmr_accepted_commit_receipt.f90",
    "src/solver/mod_soil_water_solver_contract.f90",
    "src/solver/mod_reference_richards_workspace.f90",
    "src/solver/mod_reference_richards_state_binding.f90",
    "src/solver/mod_b110_default_mvg_provider.f90",
    "src/solver/mod_b110_source_sink_provider.f90",
    "src/solver/mod_b110_root_sink_provider.f90",
    "src/solver/mod_fixed_flux_top_boundary_provider.f90",
    "src/solver/mod_reference_linear_solver.f90",
    "src/solver/mod_reference_richards_temporal_indicator.f90",
    "src/solver/mod_surface_evaporation_capacity_contract.f90",
    "src/solver/mod_b110_surface_evaporation_capacity_provider.f90",
    "src/legacy/b1_10_port/headcalc.f90",
    "src/adapter/mod_reference_richards_legacy_binding.f90",
    "src/adapter/mod_b110_serialized_context_binding.f90",
    "src/process/mod_snow_process.f90",
    "src/runtime/mod_fmr_serialized_reference_backend.f90",
    "src/runtime/mod_fmr_serialized_multiswap_runtime.f90",
    "src/runtime/mod_fmr_parallel_physical_scheduler.f90",
    "src/runtime/mod_fmr_parallel_worker_pool.f90",
    "src/runtime/mod_fmr_parallel_root_uptake_pool.f90",
    "src/runtime/mod_fmr_committed_restart.f90",
    "src/runtime/mod_fmr_restart_state_contract.f90",
    "src/runtime/mod_fmr_reference_et_root_uptake_composition.f90",
    "src/solver/mod_process_hydraulic_view.f90",
    "src/process/mod_drainage_spatial_distribution.f90",
    "src/runtime/mod_fmr_divdra_runtime_binding.f90",
    "src/runtime/mod_fmr_divdra_serialized_composition.f90",
    "src/runtime/mod_fmr_divdra_serialized_runtime.f90",
]

ADDITIONS = [
    "src/process/mod_restricted_surface_evaporation.f90",
    "src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90",
    "src/runtime/mod_fmr_process_hydraulic_view_binding.f90",
    "src/process/mod_soil_temperature_contract.f90",
    "src/process/mod_restricted_soil_temperature.f90",
    "src/runtime/mod_coupling_application_accuracy_contract.f90",
    "src/runtime/mod_coupling_application_accuracy_adapter.f90",
]

ADMISSION_STATUS = {
    "integration/f-ci/F-CI41_STATUS.json": (
        "QUALIFIED_RESTRICTED_SURFACE_EVAPORATION_RUNTIME_MATERIALIZATION_FOR_CURRENT_CANONICAL_ADMISSION_WITHIN_FROZEN_SWINTER0_SWREDU0_SCOPE",
        ["src/process/mod_restricted_surface_evaporation.f90", "src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90"],
    ),
    "integration/f-ci/F-CI42_STATUS.json": (
        "QUALIFIED_FPE11_SURFACE_EVAPORATION_ALLOCATION_PERFORMANCE_ADMITTED_TO_CURRENT_CANONICAL",
        ["src/runtime/mod_fmr_process_hydraulic_view_binding.f90", "src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90"],
    ),
    "integration/f-ci/F-CI43_STATUS.json": (
        "QUALIFIED_FPM07B_RESTRICTED_SOIL_TEMPERATURE_FOR_CURRENT_CANONICAL_ADMISSION",
        ["src/process/mod_soil_temperature_contract.f90", "src/process/mod_restricted_soil_temperature.f90"],
    ),
    "integration/f-ci/F-CI44_STATUS.json": (
        "QUALIFIED_FGC10_APPLICATION_ACCURACY_CONTRACT_FOR_CURRENT_CANONICAL_ADMISSION",
        ["src/runtime/mod_coupling_application_accuracy_contract.f90"],
    ),
    "integration/f-ci/F-CI45_STATUS.json": (
        "QUALIFIED_FMR39_RESTRICTED_SOIL_TEMPERATURE_RUNTIME_FOR_CURRENT_CANONICAL_ADMISSION",
        ["src/runtime/mod_fmr_serialized_reference_backend.f90", "src/runtime/mod_fmr_restart_state_contract.f90"],
    ),
    "integration/f-ci/F-CI46_STATUS.json": (
        "QUALIFIED_FGC14_EXTERNAL_ACCURACY_RUNTIME_ADAPTER_FOR_CURRENT_CANONICAL_ADMISSION",
        ["src/runtime/mod_coupling_application_accuracy_adapter.f90"],
    ),
}


def git(*args: str) -> str:
    cp = subprocess.run(["git", *args], check=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return cp.stdout.strip()


def require(cond: bool, message: str) -> None:
    if not cond:
        raise SystemExit(f"FCI47_FAIL: {message}")


def main() -> None:
    canonical = git("rev-parse", "origin/integration/f-ci-canonical")
    require(canonical == BASE, f"canonical race: {canonical}")
    require(git("merge-base", "--is-ancestor", STALE, BASE) == "", "unexpected merge-base output")

    src_delta = set(filter(None, git("diff", "--name-only", f"{STALE}..{BASE}", "--", "src").splitlines()))
    require(src_delta == EXPECTED_SRC_DELTA, f"F-CI40 -> F-CI46P src delta mismatch: {sorted(src_delta)}")
    print("FCI47_FCI40_TO_FCI46P_EXACT_NINE_SOURCE_DELTA=PASS")

    local_prod_delta = git("diff", "--name-only", f"{BASE}..HEAD", "--", "src", "reference")
    require(local_prod_delta == "", f"F-CI47 production/reference delta: {local_prod_delta}")
    print("FCI47_NO_PRODUCTION_OR_REFERENCE_DELTA=PASS")

    for path, (decision, files) in ADMISSION_STATUS.items():
        obj = json.loads(Path(path).read_text())
        require(obj.get("decision") == decision, f"decision mismatch: {path}")
        serialized = json.dumps(obj, sort_keys=True)
        for filename in files:
            require(filename in serialized, f"admission provenance missing {filename} in {path}")
            require(git("rev-parse", f"HEAD:{filename}") == git("rev-parse", f"{BASE}:{filename}"), f"target blob drift: {filename}")
    print("FCI47_FCI41_THROUGH_FCI46_ADMISSION_PROVENANCE=PASS")

    base_text = git("show", f"{BASE}:{WORKFLOW.as_posix()}") + "\n"
    current_text = WORKFLOW.read_text()
    require(MARKER in base_text and MARKER in current_text, "moving-preservation job marker missing")
    base_prefix, base_suffix = base_text.split(MARKER, 1)
    current_prefix, current_suffix = current_text.split(MARKER, 1)
    require(current_prefix == base_prefix, "historical/frozen canonical workflow prefix changed")
    require(f"AUTH={STALE}" in base_suffix, "source workflow does not contain expected stale authority")
    require(f"AUTH={BASE}" in current_suffix, "candidate workflow missing reconciled authority")
    require(f"AUTH={STALE}" not in current_suffix, "candidate still uses stale moving authority")

    for path in OLD_SURFACE:
        require(current_suffix.count(path) == 1, f"old dependency entry removed or duplicated: {path}")
    for path in ADDITIONS:
        require(current_suffix.count(path) == 1, f"new dependency entry absent or duplicated: {path}")
    require(len(set(OLD_SURFACE) | set(ADDITIONS)) == len(OLD_SURFACE) + len(ADDITIONS), "surface lists overlap")
    print("FCI47_FROZEN_WORKFLOW_PREFIX_BYTE_IDENTITY=PASS")
    print("FCI47_OLD_DEPENDENCY_SURFACE_RETAINED=PASS")
    print("FCI47_EXACT_SEVEN_LATER_ADMITTED_PATHS_ADDED=PASS")

    require(git("merge-base", "--is-ancestor", BASE, "HEAD") == "", "unexpected target ancestry output")
    for path in OLD_SURFACE + ADDITIONS:
        require(git("rev-parse", f"HEAD:{path}") == git("rev-parse", f"{BASE}:{path}"), f"current preservation mismatch: {path}")
    require(git("rev-parse", "HEAD:src") == git("rev-parse", f"{BASE}:src"), "src tree changed")
    require(git("rev-parse", "HEAD:reference") == git("rev-parse", f"{BASE}:reference"), "reference tree changed")
    print("FCI47_RECONCILED_MOVING_PRESERVATION_SURFACE=PASS")
    print("FCI47_SRC_REFERENCE_TREE_IDENTITY=PASS")

    audit = json.loads(Path("integration/f-ci/F-CI47_ARCHITECTURE_AUDIT.json").read_text())
    require(audit.get("overall") == "30_OF_30_NO_ADVERSE_DELTA", "architecture audit overall")
    require(audit.get("mass_conservation") == "HARD_UNCHANGED", "mass conservation audit")
    require(len(audit.get("invariants", [])) == 30, "architecture audit does not contain 30 invariants")
    require(all(x.get("status") == "PASS" for x in audit["invariants"]), "architecture invariant failure")
    print("FCI47_ARCHITECTURE_INVARIANTS=PASS:30_OF_30")
    print("FCI47_MASS_CONSERVATION=HARD_UNCHANGED")
    print("FCI47_MOVING_PRESERVATION_AUTHORITY_RECONCILIATION=PASS")


if __name__ == "__main__":
    main()
