#!/usr/bin/env python3
import json
import subprocess
import sys
from pathlib import Path

BASE = "c0fc660c1e68064f77f4ec4f3376d385fbe88b4a"
D_CLOSEOUT = "4fc92f14baa5ae289839826032f9aa66776e2192"
D1_CLOSEOUT = "dc523f6510e4fb14cdd09ce2ec26f0b3f613f499"
D2_CLOSEOUT = "a0b11f68884f7593f000af1c34aa42de8956ecfd"
D2_DECISION = "QUALIFIED_RESTRICTED_EXTENDED_DRAINAGE_EXCHANGE_LAW_READINESS_WITH_EXPLICIT_SOURCE_SEAM_HOLDS"
ARCHIVE_SHA = "1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151"
SURFACEWATER_SHA = "d38e25da1b71cf3d7872df294b1de6080e070a314f9168b8a4e4d3ff1526089e"
RISK_IDS = [
    "D3-RISK-01-PRELIMITER-WSCAP-VS-ACTUAL-SUPPLY-ENABLEMENT",
    "D3-RISK-02-LEGACY-DRY-FLOOR-MASS-GAP",
    "D3-RISK-03-HIDDEN-ACTUAL-SUPPLY-FLUX",
    "D3-RISK-04-MIXED-SIGN-PROPORTIONAL-SCALING",
    "D3-RISK-05-PRE-VS-POST-SOIL-BALANCE-ENVELOPE",
    "D3-RISK-06-CAPACITY-VIOLATION-ON-NEGATIVE-FINAL-PROJECTION",
    "D3-RISK-07-MASS-DOUBLE-BOOKING",
]
ALLOWED = {
    ".github/workflows/fpm08d3-availability-mass-readiness.yml",
    "integration/f-pm/F-PM08D3_STATUS.json",
    "integration/f-pm/F-PM08D3_READINESS_CONTRACT.json",
    "integration/f-pm/F-PM08D3_MASS_SOURCE_INVENTORY.json",
    "integration/f-pm/F-PM08D3_ARCHITECTURE_AUDIT.json",
    "integration/f-pm/F-PM08D3_READINESS_EVIDENCE.json",
    "tests/fpm/test_fpm08d3_availability_mass.py",
    "tools/fpm/fpm08d3_availability_mass_readiness_gate.py",
}


def sh(*args):
    return subprocess.check_output(args, text=True).strip()


def at(commit, path):
    return json.loads(sh("git", "show", f"{commit}:{path}"))


def load(path):
    return json.loads(Path(path).read_text())


def require(condition, marker):
    if not condition:
        raise SystemExit(f"FPM08D3_FAIL={marker}")
    print(f"FPM08D3_{marker}=PASS")


changed = {x for x in sh("git", "diff", "--name-only", BASE, "HEAD").splitlines() if x}
require(changed <= ALLOWED, "READINESS_ONLY_FILE_DELTA")
require(not any(x.startswith("src/") for x in changed), "NO_PRODUCTION_SOURCE_DELTA")
require(not any(x.startswith("reference/") for x in changed), "NO_REFERENCE_SOURCE_DELTA")
manifest = Path("reference/swap-4.3.1/b0/file-manifest.sha256").read_text()
require(ARCHIVE_SHA in manifest, "FROZEN_ARCHIVE_IDENTITY")
require(SURFACEWATER_SHA in manifest and "SWAP/surfacewater.f90" in manifest, "FROZEN_SURFACEWATER_IDENTITY")

for commit in (D_CLOSEOUT, D1_CLOSEOUT, D2_CLOSEOUT):
    subprocess.check_call(["git", "cat-file", "-e", f"{commit}^{{commit}}"])
print("FPM08D3_UPSTREAM_COMMITS_EXIST=PASS")
d2 = at(D2_CLOSEOUT, "integration/f-pm/F-PM08D2_STATUS.json")
require(d2.get("decision") == D2_DECISION and d2["state"]["qualified"] is True, "D2_CLOSEOUT_LOCKED")
require(d2["state"]["production_physics_qualified"] is False, "D2_NOT_MISREPRESENTED_AS_PRODUCTION")

contract = load("integration/f-pm/F-PM08D3_READINESS_CONTRACT.json")
inv = load("integration/f-pm/F-PM08D3_MASS_SOURCE_INVENTORY.json")
audit = load("integration/f-pm/F-PM08D3_ARCHITECTURE_AUDIT.json")
status = load("integration/f-pm/F-PM08D3_STATUS.json")

require(contract["activation_base"] == BASE, "ACTIVATION_BASE_LOCKED")
require(contract["parent_closeouts"]["F-PM08D2"] == D2_CLOSEOUT, "D2_SHA_LOCKED")
require(contract["frozen_source"]["archive_sha256"] == ARCHIVE_SHA, "CONTRACT_ARCHIVE_LOCKED")
require(contract["frozen_source"]["surfacewater_f90_sha256"] == SURFACEWATER_SHA, "CONTRACT_SURFACEWATER_LOCKED")
require(contract["mass_sign_convention"]["mass_conservation_absolute"] is True, "MASS_CONSERVATION_ABSOLUTE")
require(contract["mass_sign_convention"]["configurable_physical_mass_concession"] is False, "NO_CONFIGURABLE_MASS_CONCESSION")
require(contract["pre_solver_limiter_contract"]["persistent_state"] is False, "STATELESS_LIMITER")
require(contract["pre_solver_limiter_contract"]["books_supply_mass"] is False, "LIMITER_DOES_NOT_BOOK_SUPPLY")
require(contract["pre_solver_limiter_contract"]["books_any_committed_mass"] is False, "LIMITER_DOES_NOT_COMMIT_MASS")
require(contract["critical_supply_capacity_rule"]["raw_WSCAP_is_not_sufficient_input"] is True, "RAW_WSCAP_NOT_PHYSICAL_AVAILABILITY")
require(contract["explicit_actual_flux_contract"]["q_supply_and_q_discharge_are_results_not_inferred_scratch"] is True, "SUPPLY_DISCHARGE_FIRST_CLASS")
require(contract["dry_floor_contract"]["legacy_minus_0_1_cm_gap_not_admitted"] is True, "LEGACY_DRY_GAP_NOT_ADMITTED")
require(contract["mixed_sign_reference_semantics"]["mixed_sign_limiter_activation_production_admitted"] is False, "MIXED_SIGN_INITIAL_ROUTE_HELD")
require(contract["transaction_boundary"]["commit_is_atomic_with_surface_water_state_and_mass_ledger"] is True, "ATOMIC_STATE_LEDGER_COMMIT_REQUIRED")
require([x["id"] for x in contract["source_risks"]] == RISK_IDS, "ALL_SEVEN_SOURCE_RISKS_CONTRACTED")

require(inv["supply_capacity_semantics"]["pre_limiter_uses_WSCAP_unconditionally_within_management_period"] is True, "SOURCE_PRELIMITER_WSCAP_CONFIRMED")
require(inv["supply_capacity_semantics"]["automatic_management_equivalent_reader_guard_found"] is False, "AUTOMATIC_SUPPLY_GUARD_GAP_CONFIRMED")
require(inv["legacy_dry_floor_mass_gap"]["maximum_unmatched_negative_projection_magnitude_cm"] == 0.1, "LEGACY_POINT_ONE_CM_WINDOW_CONFIRMED")
require(inv["legacy_dry_floor_mass_gap"]["mass_conservation_disposition"] == "not admissible as a physical mass tolerance in SWAP5", "SOURCE_MASS_GAP_FAIL_CLOSED")
require(inv["mixed_sign_scaling_observation"]["positive_level_fluxes_are_reduced_when_present"] is True, "MIXED_SIGN_SCALING_CHARACTERIZED")
require(inv["pre_post_soil_composition"]["consequence"].startswith("a pre-solver nonnegative envelope does not prove"), "PRE_POST_ENVELOPE_LIMIT_RECOGNIZED")

ids = [x["id"] for x in audit["invariants"]]
require(ids == list(range(1, 31)), "ALL_30_INVARIANTS_PRESENT")
require(all(x["status"] == "PASS" for x in audit["invariants"]), "ALL_30_INVARIANTS_PASS")
require(audit["overall"] == "PASS_WITH_EXPLICIT_MASS_SOURCE_HOLDS", "ARCHITECTURE_MASS_HOLDS_EXPLICIT")

require(status["source_authority"]["exact_branch_base"] == BASE, "STATUS_BASE_LOCKED")
require(status["parent_authorities"]["fpm08d2_closeout"] == D2_CLOSEOUT, "STATUS_D2_LOCKED")
require(status["source_risk_holds"] == RISK_IDS, "STATUS_ALL_SEVEN_RISKS_BOUND")
require(status["state"]["production_source_changed"] is False, "STATUS_NO_PRODUCTION_CHANGE")
require(status["state"]["reference_source_changed"] is False, "STATUS_NO_REFERENCE_CHANGE")

proc = subprocess.run([sys.executable, "tests/fpm/test_fpm08d3_availability_mass.py"], text=True, capture_output=True)
if proc.stdout:
    print(proc.stdout, end="")
if proc.stderr:
    print(proc.stderr, file=sys.stderr, end="")
require(proc.returncode == 0, "EXECUTABLE_AVAILABILITY_MASS_ORACLE")
print("FPM08D3_AVAILABILITY_MASS_READINESS_GATE PASS")
