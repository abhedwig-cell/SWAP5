#!/usr/bin/env python3
import json
import subprocess
import sys
from pathlib import Path

BASE = "6318f04bd4d7dd8f9a587f03decaaea63d4f5f36"
PARENT_CLOSEOUT = "4fc92f14baa5ae289839826032f9aa66776e2192"
PARENT_DECISION = "QUALIFIED_SURFACE_WATER_CONTROLLED_DRAINAGE_COMPOSITION_READINESS_READY_FOR_FPM08D1"
ARCHIVE_SHA = "1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151"
SURFACEWATER_SHA = "d38e25da1b71cf3d7872df294b1de6080e070a314f9168b8a4e4d3ff1526089e"
MOD_DRAINAGE_SHA = "cb354ea13a099422c9f3b9c87a60ccbe440c0dd3c83ba0502108da8ca70ff255"
RISK1 = "D1-RISK-01-BOTTOM-KNOT-ROUNDING-SEAM"
RISK2 = "D1-RISK-02-INTERPOLATION-ENDPOINT-ROUNDING-SEAM"

ALLOWED = {
    ".github/workflows/fpm08d1-storage-compact-state-readiness.yml",
    "integration/f-pm/F-PM08D1_STATUS.json",
    "integration/f-pm/F-PM08D1_READINESS_CONTRACT.json",
    "integration/f-pm/F-PM08D1_STORAGE_SOURCE_INVENTORY.json",
    "integration/f-pm/F-PM08D1_ARCHITECTURE_AUDIT.json",
    "integration/f-pm/F-PM08D1_READINESS_EVIDENCE.json",
    "tests/fpm/test_fpm08d1_storage_geometry.py",
    "tools/fpm/fpm08d1_storage_readiness_gate.py",
}

def sh(*args):
    return subprocess.check_output(args, text=True).strip()

def load(path):
    return json.loads(Path(path).read_text())

def require(condition, marker):
    if not condition:
        raise SystemExit(f"FPM08D1_FAIL={marker}")
    print(f"FPM08D1_{marker}=PASS")

changed = {x for x in sh("git", "diff", "--name-only", BASE, "HEAD").splitlines() if x}
require(changed <= ALLOWED, "READINESS_ONLY_FILE_DELTA")
require(not any(x.startswith("src/") for x in changed), "NO_PRODUCTION_SOURCE_DELTA")
require(not any(x.startswith("reference/") for x in changed), "NO_REFERENCE_SOURCE_DELTA")

manifest = Path("reference/swap-4.3.1/b0/file-manifest.sha256").read_text()
require(ARCHIVE_SHA in manifest, "FROZEN_ARCHIVE_IDENTITY")
require(SURFACEWATER_SHA in manifest and "SWAP/surfacewater.f90" in manifest, "FROZEN_SURFACEWATER_IDENTITY")
require(MOD_DRAINAGE_SHA in manifest and "SWAP/MOD_drainage.f90" in manifest, "FROZEN_MOD_DRAINAGE_IDENTITY")

subprocess.check_call(["git", "cat-file", "-e", f"{PARENT_CLOSEOUT}^{{commit}}"])
parent = json.loads(sh("git", "show", f"{PARENT_CLOSEOUT}:integration/f-pm/F-PM08D_STATUS.json"))
require(parent["decision"] == PARENT_DECISION, "PARENT_DECISION_LOCKED")
require(parent["state"]["qualified"] is True, "PARENT_READINESS_QUALIFIED")
require(parent["state"]["production_source_changed"] is False, "PARENT_NO_PRODUCTION_SOURCE_CHANGE")

contract = load("integration/f-pm/F-PM08D1_READINESS_CONTRACT.json")
inv = load("integration/f-pm/F-PM08D1_STORAGE_SOURCE_INVENTORY.json")
audit = load("integration/f-pm/F-PM08D1_ARCHITECTURE_AUDIT.json")
status = load("integration/f-pm/F-PM08D1_STATUS.json")

require(contract["activation_base"] == BASE, "ACTIVATION_BASE_LOCKED")
require(contract["parent_closeout"] == PARENT_CLOSEOUT, "PARENT_CLOSEOUT_LOCKED")
require(contract["frozen_source"]["archive_sha256"] == ARCHIVE_SHA, "CONTRACT_ARCHIVE_LOCKED")
require(contract["frozen_source"]["surfacewater_f90_sha256"] == SURFACEWATER_SHA, "CONTRACT_SURFACEWATER_LOCKED")
require(contract["frozen_source"]["mod_drainage_f90_sha256"] == MOD_DRAINAGE_SHA, "CONTRACT_MOD_DRAINAGE_LOCKED")

ownership = contract["state_ownership"]
require(ownership["SWST"]["authoritative"] is True and ownership["SWST"]["conserved"] is True, "SWST_AUTHORITATIVE_CONSERVED_STATE")
require(ownership["WLS"]["committed_independent_state"] is False, "WLS_NOT_DUPLICATED_STATE")
require(ownership["WLSTAR"]["storage_state_member"] is False, "WLSTAR_NOT_STORAGE_STATE")
require(ownership["WLSTAR"]["owner_child"] == "F-PM08D5", "WLSTAR_ROUTED_TO_D5")
require(ownership["WLSBAK"]["physical_state_member"] is False, "WLSBAK_NUMERICAL_HISTORY_SEPARATED")
require(ownership["NUMADJ"]["physical_state_member"] is False, "NUMADJ_DIAGNOSTIC_ONLY")

param = contract["modern_storage_parameterization"]
require(param["wls_recomputed_from_swst"] is True, "WLS_DERIVED_FROM_SWST")
require(param["no_per_column_duplicate_sttab"] is True, "NO_PER_COLUMN_STTAB_DUPLICATION")
require(param["no_storage_state_for_inactive_option"] is True, "OPTIONAL_STATE_SCALES_WITH_USE")
require("22-knot" in param["reference_mode"], "REFERENCE_22_KNOT_SEMANTICS")
require(contract["source_domain"]["reader_vs_table_bottom_boundary_can_differ_by_floating_rounding"] is True, "BOTTOM_DOMAIN_SEAM_CONTRACTED")
require(contract["source_domain"]["forward_endpoint_result_can_differ_from_stored_storage_endpoint_by_floating_rounding"] is True, "INTERPOLATION_ENDPOINT_SEAM_CONTRACTED")
require(contract["physics_policy_separation"]["bottom_knot_rounding_seam_is_not_solver_tolerance"] is True, "BOTTOM_SEAM_NOT_SOLVER_TOLERANCE")
require(contract["physics_policy_separation"]["interpolation_endpoint_rounding_seam_is_not_solver_tolerance"] is True, "INTERPOLATION_ENDPOINT_SEAM_NOT_SOLVER_TOLERANCE")
contract_risks = {x["id"]: x for x in contract["source_risk_holds"]}
require(RISK1 in contract_risks and contract_risks[RISK1]["production_disposition_required"] is True, "BOTTOM_SEAM_PRODUCTION_HOLD")
require(RISK2 in contract_risks and contract_risks[RISK2]["production_disposition_required"] is True, "INTERPOLATION_ENDPOINT_PRODUCTION_HOLD")

require(inv["source_identity"]["archive_sha256"] == ARCHIVE_SHA, "INVENTORY_ARCHIVE_LOCKED")
require(inv["sttab_reference_semantics"]["number_of_knots"] == 22, "INVENTORY_22_KNOTS")
require(inv["sttab_reference_semantics"]["knot_22_bit_exact_equality_not_guaranteed"] is True, "INVENTORY_BOTTOM_KNOT_BIT_SEAM")
require(inv["sttab_reference_semantics"]["endpoint_evaluation_uses_interpolation_arithmetic"] is True, "INVENTORY_ENDPOINT_ARITHMETIC")
require(inv["reader_domain"]["deepest_secondary_open_required"] is True, "DEEPEST_SECONDARY_OPEN_REQUIRED")
require(inv["reference_mode_consequence"]["retain_22_knot_piecewise_linear_semantics"] is True, "PIECEWISE_LINEAR_REFERENCE_RETAINED")
require(inv["reference_mode_consequence"]["analytic_open_channel_formula_between_knots_is_reference_equivalent"] is False, "NO_SILENT_ANALYTIC_SUBSTITUTION")
require(inv["multiswap_layout"]["prepared_relation_shared"] is True, "MULTISWAP_PARAMETER_SHARING")
require(inv["multiswap_layout"]["per_column_table_copy_required"] is False, "MULTISWAP_NO_TABLE_COPY")
require(inv["multiswap_layout"]["persistent_reals_per_active_simulated_column_for_storage_only"] == 1, "COMPACT_ONE_REAL_STORAGE_STATE")
require(inv["multiswap_layout"]["inactive_columns_storage_state_bytes"] == 0, "INACTIVE_STATE_ZERO_BYTES")
inv_risks = {x["id"]: x for x in inv["source_level_risks"]}
require(RISK1 in inv_risks, "BOTTOM_SEAM_INVENTORIED")
require(inv_risks[RISK1]["classification"] == "frozen reference boundary seam, not configurable numerical tolerance", "BOTTOM_SEAM_CLASSIFIED")
require(RISK2 in inv_risks, "INTERPOLATION_ENDPOINT_SEAM_INVENTORIED")
require(inv_risks[RISK2]["classification"] == "frozen reference interpolation boundary seam, not configurable numerical tolerance", "INTERPOLATION_ENDPOINT_SEAM_CLASSIFIED")

require(audit["source_risk_holds"] == [RISK1, RISK2], "AUDIT_BOTH_SEAMS_BOUND")
ids = [x["id"] for x in audit["invariants"]]
require(ids == list(range(1, 31)), "ALL_30_INVARIANTS_PRESENT")
require(all(x["status"] == "PASS" for x in audit["invariants"]), "ALL_30_INVARIANTS_PASS")
require(audit["overall"] == "PASS_WITH_CHILD_SCOPE_HOLDS", "ARCHITECTURE_SCOPE_HOLDS_EXPLICIT")

require(status["source_authority"]["exact_branch_base"] == BASE, "STATUS_BASE_LOCKED")
require(status["parent_authority"]["fpm08d_closeout"] == PARENT_CLOSEOUT, "STATUS_PARENT_LOCKED")
status_risks = {x["id"]: x for x in status["source_risk_holds"]}
require(RISK1 in status_risks and RISK2 in status_risks, "STATUS_BOTH_SEAMS_BOUND")
require(status["state"]["production_source_changed"] is False, "STATUS_NO_PRODUCTION_CHANGE")
require(status["state"]["reference_source_changed"] is False, "STATUS_NO_REFERENCE_CHANGE")

proc = subprocess.run([sys.executable, "tests/fpm/test_fpm08d1_storage_geometry.py"], text=True, capture_output=True)
if proc.stdout:
    print(proc.stdout, end="")
if proc.stderr:
    print(proc.stderr, file=sys.stderr, end="")
require(proc.returncode == 0, "EXECUTABLE_STORAGE_ORACLE")

print("FPM08D1_STORAGE_COMPACT_STATE_READINESS_GATE PASS")
