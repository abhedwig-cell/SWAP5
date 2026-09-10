#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path

BASE = "2efba343d425770e5d581d8137cd60e83d8b7ac5"
FPM08 = "3ce245e3cac068268bdff2f0af0fdcdf022c82aa"
FVQ47_STATUS_HEAD = "12fef763fbf664972a9f26a02b666def5009fc1a"
FVQ47_CLOSEOUT = "9aa52a6e6e3b85119434fc97f056f4c9918447fd"
FVQ47_DECISION = "QUALIFIED_REMEDIATED_RESTRICTED_DIVDRA_SPATIAL_DISTRIBUTION_AND_LEV2COMP_BOUNDARY_SEAM_EQUIVALENCE"
DIVDRA_BLOB = "1f538174b7451aaa7a3c50d6078b7c1fc3ad8f5a"

EXPECTED_MANIFEST = {
    "SWAP/surfacewater.f90": "d38e25da1b71cf3d7872df294b1de6080e070a314f9168b8a4e4d3ff1526089e",
    "SWAP/MOD_drainage.f90": "cb354ea13a099422c9f3b9c87a60ccbe440c0dd3c83ba0502108da8ca70ff255",
    "SWAP/swap.f90": "39d1cbd93dbd0f99505e92ef94ac0d23bddb496529c280397d2d7c2b7eb9b58a",
    "SWAP/boundtop.f90": "69d0d4703af64212d7200898f12568853d015cea29cb45f81915bece15b63c04",
}

ALLOWED = {
    ".github/workflows/fpm08d-surface-water-control-readiness.yml",
    "integration/f-pm/F-PM08D_ARCHITECTURE_AUDIT.json",
    "integration/f-pm/F-PM08D_READINESS_CONTRACT.json",
    "integration/f-pm/F-PM08D_READINESS_EVIDENCE.json",
    "integration/f-pm/F-PM08D_STATUS.json",
    "integration/f-pm/F-PM08D_SURFACE_WATER_SOURCE_INVENTORY.json",
    "tools/fpm/fpm08d_surface_water_control_readiness_gate.py",
}


def sh(*args):
    return subprocess.check_output(args, text=True).strip()


def load(path):
    return json.loads(Path(path).read_text())


def require(cond, marker):
    if not cond:
        raise SystemExit(f"FPM08D_FAIL={marker}")
    print(f"FPM08D_{marker}=PASS")


changed = {p for p in sh("git", "diff", "--name-only", BASE, "HEAD").splitlines() if p}
require(changed <= ALLOWED, "READINESS_ONLY_FILE_DELTA")
require(not any(p.startswith("src/") for p in changed), "NO_PRODUCTION_SOURCE_DELTA")
require(not any(p.startswith("reference/") for p in changed), "NO_REFERENCE_SOURCE_DELTA")

manifest = Path("reference/swap-4.3.1/b0/file-manifest.sha256").read_text()
for path, digest in EXPECTED_MANIFEST.items():
    require(digest in manifest and path in manifest, f"FROZEN_{path.split('/')[-1].replace('.', '_').upper()}_IDENTITY")

actual_divdra_blob = sh("git", "hash-object", "src/process/mod_drainage_spatial_distribution.f90")
require(actual_divdra_blob == DIVDRA_BLOB, "CANONICAL_REMEDIATED_DIVDRA_BLOB")

for commit in (FPM08, FVQ47_STATUS_HEAD, FVQ47_CLOSEOUT):
    subprocess.check_call(["git", "cat-file", "-e", f"{commit}^{{commit}}"])
require(True, "UPSTREAM_COMMITS_PRESENT")

fvq47 = json.loads(sh("git", "show", f"{FVQ47_STATUS_HEAD}:integration/f-vq/F-VQ47_STATUS.json"))
require(fvq47["status"] == FVQ47_DECISION, "FVQ47_DECISION_LOCKED")
require(fvq47["state"]["scientifically_qualified"] is True, "FVQ47_SCIENTIFICALLY_QUALIFIED")
require(fvq47["state"]["production_source_modified_by_qualification"] is False, "FVQ47_INDEPENDENCE_LOCKED")

contract = load("integration/f-pm/F-PM08D_READINESS_CONTRACT.json")
status = load("integration/f-pm/F-PM08D_STATUS.json")
inv = load("integration/f-pm/F-PM08D_SURFACE_WATER_SOURCE_INVENTORY.json")
audit = load("integration/f-pm/F-PM08D_ARCHITECTURE_AUDIT.json")

require(contract["activation_base"] == BASE, "ACTIVATION_BASE_LOCKED")
require(contract["production_changes_allowed_in_this_initial_readiness_phase"] is False, "NO_PRODUCTION_IN_READINESS")
require(contract["mass_contract"]["mass_conservation_absolute"] is True, "ABSOLUTE_MASS_CONSERVATION")
require(contract["mass_contract"]["configurable_mass_concession_allowed"] is False, "NO_CONFIGURABLE_MASS_CONCESSION")
require(contract["transaction_contract"]["rejected_trial_books_mass"] is False, "REJECTED_TRIAL_BOOKS_NO_MASS")
require(contract["time_contract"]["day_is_fundamental_unit"] is False, "GENERIC_TIME_DAY_NOT_FUNDAMENTAL")
require(contract["time_contract"]["midnight_is_implicit_boundary"] is False, "NO_IMPLICIT_MIDNIGHT")

require(inv["frozen_source"]["archive_sha256"] == "1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151", "INVENTORY_ARCHIVE_LOCKED")
for path, digest in EXPECTED_MANIFEST.items():
    require(inv["frozen_source"]["files"][path] == digest, f"INVENTORY_{path.split('/')[-1].replace('.', '_').upper()}_LOCKED")

physical = {x["legacy"]: x for x in inv["variable_classification"]["committed_physical_state"]}
require("SWST" in physical and "WLSTAR" in physical, "COMPACT_PHYSICAL_STATE_CLASSIFIED")
derived = {x["legacy"]: x for x in inv["variable_classification"]["derived_or_forced_hydraulic_quantities"]}
require(derived["WLS"]["classification"] == "derived_from_SWST_when_SWSEC_2; forcing_when_SWSEC_1", "WLS_NOT_DUPLICATED_AS_STATE")
numhist = {x["legacy"]: x for x in inv["variable_classification"]["numerical_history"]}
require(numhist["WLSBAK(4)"]["not_physical_state"] is True, "NUMERICAL_HISTORY_SEPARATED")

balance = inv["secondary_storage_balance"]
require(balance["authoritative_modern_balance"] == "S1-S0 = dt*(q_drain_secondary + q_rapid + q_supply - q_discharge) + V_top_surface_exchange", "EXPLICIT_SURFACE_WATER_MASS_EQUATION")
require("q_supply" in balance["signs"], "SUPPLY_FIRST_CLASS_MASS_RESULT")
require("q_discharge" in balance["signs"], "DISCHARGE_FIRST_CLASS_MASS_RESULT")

risk_ids = {x["id"] for x in inv["source_level_risks_requiring_child_disposition"]}
expected_risks = {
    "D-RISK-01-SWSRF1-UNINITIALIZED-WL",
    "D-RISK-02-QHR1-QHR2-CAPACITY-HEAD-ASYMMETRY",
    "D-RISK-03-HIDDEN-SUPPLY-DISCHARGE-FLUXES",
    "D-RISK-04-LEGACY-DAY-CADENCE",
    "D-RISK-05-PHYSICAL-VS-NUMERICAL-HISTORY",
}
require(expected_risks <= risk_ids, "SOURCE_RISKS_FAIL_CLOSED")

children = [x["id"] for x in inv["child_decomposition"]]
require(children == ["F-PM08D1", "F-PM08D2", "F-PM08D3", "F-PM08D4", "F-PM08D5", "F-PM08D6"], "CHILD_DECOMPOSITION_LOCKED")
require(inv["recommended_first_child"] == "F-PM08D1", "FIRST_CHILD_D1")

ids = [x["id"] for x in audit["invariants"]]
require(ids == list(range(1, 31)), "ALL_30_INVARIANTS_PRESENT")
require(all(x["status"] == "PASS" for x in audit["invariants"]), "ALL_30_INVARIANTS_PASS")
require(audit["overall"] == "PASS_WITH_EXPLICIT_CHILD_HOLDS", "ARCHITECTURE_HOLDS_EXPLICIT")

state = status["state"]
require(state["production_source_changed"] is False, "STATUS_NO_PRODUCTION_CHANGE")
require(status["source_authority"]["exact_branch_base"] == BASE, "STATUS_BASE_LOCKED")

print("FPM08D_SURFACE_WATER_CONTROL_READINESS_GATE PASS")
