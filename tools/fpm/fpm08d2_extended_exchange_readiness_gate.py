#!/usr/bin/env python3
import json
import subprocess
import sys
from pathlib import Path

BASE = "c0fc660c1e68064f77f4ec4f3376d385fbe88b4a"
D_CLOSEOUT = "4fc92f14baa5ae289839826032f9aa66776e2192"
D1_CLOSEOUT = "dc523f6510e4fb14cdd09ce2ec26f0b3f613f499"
FVQ42 = "702db051bf5dd0960a962be919ea0cfbf01895a4"
FVQ43 = "3542ff83f38a9dd8de407ceca65ed968407559f5"
ARCHIVE_SHA = "1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151"
SURFACEWATER_SHA = "d38e25da1b71cf3d7872df294b1de6080e070a314f9168b8a4e4d3ff1526089e"
DRAINAGE_SHA = "48e4792acd0a129a6939008bd51e82f9fed4668fcf8d28d03da0bc6efe6944cc"
D_DECISION = "QUALIFIED_SURFACE_WATER_CONTROLLED_DRAINAGE_COMPOSITION_READINESS_READY_FOR_FPM08D1"
D1_DECISION = "QUALIFIED_SURFACE_WATER_STORAGE_GEOMETRY_AND_COMPACT_STATE_READINESS_WITH_EXPLICIT_FROZEN_ENDPOINT_SEAM_HOLDS"
FVQ42_DECISION = "QUALIFIED_EMPIRICAL_INTERFLOW_DRAINAGE_SIDE_RESPONSE_AND_SENSITIVITY_WITH_EXPLICIT_ACTIVATION_SINGULARITY"
FVQ43_DECISION = "QUALIFIED_MULTILEVEL_DRAINAGE_AGGREGATION_LEGACY_ORDER_EQUIVALENCE_AND_CONSERVATIVE_SENSITIVITY_COMPOSITION"
RISK_IDS = [
    "D2-RISK-01-SWSRF1-UNINITIALIZED-WL",
    "D2-RISK-02-NEGATIVE-POWER-INTERFLOW",
    "D2-RISK-03-PONDING-HEAD-SWITCH-DISCONTINUITY",
    "D2-RISK-04-CHANNEL-ACTIVATION-SEAM",
    "D2-RISK-05-GWLINF-DERIVATIVE-KINK",
    "D2-RISK-06-SURFACE-DRAINAGE-RESISTANCE-KINK",
    "D2-RISK-07-DRAINAGE-INFILTRATION-RESISTANCE-SEAM",
    "D2-RISK-08-PONDING-SILL-SUPPRESSION-SEAM",
]
ALLOWED = {
    ".github/workflows/fpm08d2-extended-exchange-readiness.yml",
    "integration/f-pm/F-PM08D2_STATUS.json",
    "integration/f-pm/F-PM08D2_READINESS_CONTRACT.json",
    "integration/f-pm/F-PM08D2_EXCHANGE_SOURCE_INVENTORY.json",
    "integration/f-pm/F-PM08D2_ARCHITECTURE_AUDIT.json",
    "integration/f-pm/F-PM08D2_READINESS_EVIDENCE.json",
    "tests/fpm/test_fpm08d2_extended_exchange.py",
    "tools/fpm/fpm08d2_extended_exchange_readiness_gate.py",
}


def sh(*args):
    return subprocess.check_output(args, text=True).strip()


def load(path):
    return json.loads(Path(path).read_text())


def at(commit, path):
    return json.loads(sh("git", "show", f"{commit}:{path}"))


def require(condition, marker):
    if not condition:
        raise SystemExit(f"FPM08D2_FAIL={marker}")
    print(f"FPM08D2_{marker}=PASS")


changed = {x for x in sh("git", "diff", "--name-only", BASE, "HEAD").splitlines() if x}
require(changed <= ALLOWED, "READINESS_ONLY_FILE_DELTA")
require(not any(x.startswith("src/") for x in changed), "NO_PRODUCTION_SOURCE_DELTA")
require(not any(x.startswith("reference/") for x in changed), "NO_REFERENCE_SOURCE_DELTA")

manifest = Path("reference/swap-4.3.1/b0/file-manifest.sha256").read_text()
require(ARCHIVE_SHA in manifest, "FROZEN_ARCHIVE_IDENTITY")
require(SURFACEWATER_SHA in manifest and "SWAP/surfacewater.f90" in manifest, "FROZEN_SURFACEWATER_IDENTITY")
require(DRAINAGE_SHA in manifest and "SWAP/drainage.f90" in manifest, "FROZEN_DRAINAGE_IDENTITY")

for commit in (D_CLOSEOUT, D1_CLOSEOUT, FVQ42, FVQ43):
    subprocess.check_call(["git", "cat-file", "-e", f"{commit}^{{commit}}"])
print("FPM08D2_UPSTREAM_COMMITS_EXIST=PASS")

d = at(D_CLOSEOUT, "integration/f-pm/F-PM08D_STATUS.json")
d1 = at(D1_CLOSEOUT, "integration/f-pm/F-PM08D1_STATUS.json")
v42 = at(FVQ42, "integration/f-vq/F-VQ42_STATUS.json")
v43 = at(FVQ43, "integration/f-vq/F-VQ43_STATUS.json")
require(d.get("decision") == D_DECISION and d["state"]["qualified"] is True, "PARENT_D_LOCKED")
require(d1.get("decision") == D1_DECISION and d1["state"]["qualified"] is True, "D1_CLOSEOUT_LOCKED")
require(v42.get("decision") == FVQ42_DECISION and v42.get("qualified", v42.get("state", {}).get("qualified")) is True, "FVQ42_LOCKED")
require(v43.get("decision") == FVQ43_DECISION and v43.get("state", {}).get("qualified") is True, "FVQ43_LOCKED")

contract = load("integration/f-pm/F-PM08D2_READINESS_CONTRACT.json")
inv = load("integration/f-pm/F-PM08D2_EXCHANGE_SOURCE_INVENTORY.json")
audit = load("integration/f-pm/F-PM08D2_ARCHITECTURE_AUDIT.json")
status = load("integration/f-pm/F-PM08D2_STATUS.json")

require(contract["activation_base"] == BASE, "ACTIVATION_BASE_LOCKED")
require(contract["parent_closeouts"]["F-PM08D"] == D_CLOSEOUT, "PARENT_D_SHA_LOCKED")
require(contract["parent_closeouts"]["F-PM08D1"] == D1_CLOSEOUT, "D1_SHA_LOCKED")
require(contract["frozen_source"]["archive_sha256"] == ARCHIVE_SHA, "CONTRACT_ARCHIVE_LOCKED")
require(contract["frozen_source"]["surfacewater_f90_sha256"] == SURFACEWATER_SHA, "CONTRACT_SURFACEWATER_LOCKED")
require(contract["frozen_source"]["drainage_f90_sha256"] == DRAINAGE_SHA, "CONTRACT_DRAINAGE_LOCKED")

scope = contract["restricted_admitted_domain_for_future_candidate"]
require(scope["legacy_surface_water_routes"] == [2, 3], "SWSRF23_ONLY")
require(scope["SWSRF_1_admitted"] is False, "SWSRF1_HELD")
require(scope["negative_power_interflow_admitted"] is False, "NEGATIVE_POWER_HELD")
require(scope["availability_limiter_inside_exchange_law"] is False, "LIMITER_OUTSIDE_LAW")
require(scope["multilevel_aggregation_inside_exchange_law"] is False, "AGGREGATION_OUTSIDE_LAW")
require(scope["DIVDRA_inside_exchange_law"] is False, "DIVDRA_OUTSIDE_LAW")
require(scope["calendar_or_management_period_logic_inside_exchange_law"] is False, "GENERIC_TIME_NO_CALENDAR_LOGIC")
require(contract["modern_component_boundary"]["persistent_state"] is False, "STATELESS_PROCESS")
require(contract["sign_convention"]["mass_authority"].startswith("the returned signed exchange"), "AUTHORITATIVE_SIGNED_MASS_TRANSFER")

sens = contract["physical_sensitivity_contract"]
require(sens["first_class_inputs"] == ["groundwater_level", "resolved_surface_water_control_head", "ponding_depth"], "FIRST_CLASS_SENSITIVITY_INPUTS")
require(sens["finite_flux_must_not_be_erased_when_a_tangent_is_unavailable"] is True, "FINITE_FLUX_SURVIVES_TANGENT_UNAVAILABLE")
require(sens["solver_chain_rule_owned_outside_process"] is True, "SOLVER_CHAIN_RULE_OUTSIDE_PROCESS")
require(sens["no_hidden_smoothing_or_epsilon_band"] is True, "NO_HIDDEN_SMOOTHING")

contract_risks = [x["id"] for x in contract["source_risks"]]
require(contract_risks == RISK_IDS, "ALL_EIGHT_SOURCE_RISKS_CONTRACTED")
inv_risks = ["D2-RISK-01-SWSRF1-UNINITIALIZED-WL", "D2-RISK-02-NEGATIVE-POWER-INTERFLOW"] + [x["id"] for x in inv["nonsmooth_and_discontinuous_seams"]]
require(inv_risks == RISK_IDS, "ALL_EIGHT_SOURCE_RISKS_INVENTORIED")
require(inv["SWSRF1_undefined_value_characterization"]["D2_admission"] is False, "UNDEFINED_WL_ROUTE_EXCLUDED")
require(inv["canonical_context_at_activation"]["canonical_extended_exchange_module_present"] is False, "NO_PREEXISTING_CANONICAL_EXTENDED_EXCHANGE")
require(inv["state_and_mass_classification"]["persistent_state"] == [], "NO_PERSISTENT_EXCHANGE_STATE")

ids = [x["id"] for x in audit["invariants"]]
require(ids == list(range(1, 31)), "ALL_30_INVARIANTS_PRESENT")
require(all(x["status"] == "PASS" for x in audit["invariants"]), "ALL_30_INVARIANTS_PASS")
require(audit["overall"] == "PASS_WITH_EXPLICIT_SOURCE_SEAM_HOLDS", "ARCHITECTURE_SOURCE_HOLDS_EXPLICIT")

require(status["source_authority"]["exact_branch_base"] == BASE, "STATUS_BASE_LOCKED")
require(status["parent_authorities"]["fpm08d_closeout"] == D_CLOSEOUT, "STATUS_PARENT_D_LOCKED")
require(status["parent_authorities"]["fpm08d1_closeout"] == D1_CLOSEOUT, "STATUS_D1_LOCKED")
require(status["source_risk_holds"] == RISK_IDS, "STATUS_ALL_EIGHT_RISKS_BOUND")
require(status["state"]["production_source_changed"] is False, "STATUS_NO_PRODUCTION_CHANGE")
require(status["state"]["reference_source_changed"] is False, "STATUS_NO_REFERENCE_CHANGE")

proc = subprocess.run([sys.executable, "tests/fpm/test_fpm08d2_extended_exchange.py"], text=True, capture_output=True)
if proc.stdout:
    print(proc.stdout, end="")
if proc.stderr:
    print(proc.stderr, file=sys.stderr, end="")
require(proc.returncode == 0, "EXECUTABLE_EXTENDED_EXCHANGE_ORACLE")
print("FPM08D2_RESTRICTED_EXTENDED_EXCHANGE_READINESS_GATE PASS")
