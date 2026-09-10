#!/usr/bin/env python3
import json
import subprocess
import sys
from pathlib import Path

BASE = "c0fc660c1e68064f77f4ec4f3376d385fbe88b4a"
ARCHIVE_SHA = "1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151"
SURFACEWATER_SHA = "d38e25da1b71cf3d7872df294b1de6080e070a314f9168b8a4e4d3ff1526089e"
PARENT_D = "4fc92f14baa5ae289839826032f9aa66776e2192"
D1 = "dc523f6510e4fb14cdd09ce2ec26f0b3f613f499"
D2 = "a0b11f68884f7593f000af1c34aa42de8956ecfd"
D3 = "eb57bd2ffa9ee33a3d198e8424edc91556957344"
RISKS = {
    "D4-RISK-01-LEGACY-0P001CM-BISECTION-CAN-LEAVE-S-AND-WLS-INCONSISTENT",
    "D4-RISK-02-MASS-RESIDUAL-MUST-NOT-BE-CONFLATED-WITH-RATING-ROOT-RESIDUAL",
    "D4-RISK-03-POWER-RATING-CREST-TANGENT-SINGULAR-FOR-BETA-LT-1",
    "D4-RISK-04-D1-STORAGE-MAPPING-ENDPOINT-SEAMS",
    "D4-RISK-05-NO-FEASIBLE-RATING-STATE-OVERFLOW",
    "D4-RISK-06-LEGACY-CALENDAR-MANAGEMENT-PERIOD-SELECTION",
    "D4-RISK-07-WLSBAK-AND-PONDING-DT-LOGIC-ARE-NUMERICAL-POLICY",
    "D4-RISK-08-D3-DRY-FLOOR-AND-RAW-WSCAP-MASS-GAPS-MUST-NOT-RETURN",
    "D4-RISK-09-SWQHR2-THRESHOLD-DERIVED-HBWEIR-EXCLUDED",
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
        print(f"FPM08D4_{name}=FAIL")
        raise SystemExit(1)
    print(f"FPM08D4_{name}=PASS")


def load(path):
    return json.loads(Path(path).read_text())


def main():
    changed = [x for x in run("git", "diff", "--name-only", f"{BASE}..HEAD").stdout.splitlines() if x]
    allowed = all(
        p.startswith("integration/f-pm/F-PM08D4_")
        or p == "tests/fpm/test_fpm08d4_fixed_weir_balance.py"
        or p == "tools/fpm/fpm08d4_fixed_weir_readiness_gate.py"
        or p == ".github/workflows/fpm08d4-fixed-weir-readiness.yml"
        for p in changed
    )
    mark("READINESS_ONLY_FILE_DELTA", allowed)
    mark("NO_PRODUCTION_SOURCE_DELTA", not any(p.startswith("src/") for p in changed))
    mark("NO_REFERENCE_SOURCE_DELTA", not any(p.startswith("reference/") for p in changed))

    manifest = run("git", "show", f"{BASE}:reference/swap-4.3.1/b0/file-manifest.sha256").stdout
    mark("FROZEN_ARCHIVE_IDENTITY", ARCHIVE_SHA in manifest)
    mark("FROZEN_SURFACEWATER_IDENTITY", SURFACEWATER_SHA in manifest and "SWAP/surfacewater.f90" in manifest)

    upstream_ok = True
    for sha in (PARENT_D, D1, D2, D3):
        if run("git", "cat-file", "-e", f"{sha}^{{commit}}", check=False).returncode != 0:
            upstream_ok = False
    mark("UPSTREAM_COMMITS_EXIST", upstream_ok)

    contract = load("integration/f-pm/F-PM08D4_READINESS_CONTRACT.json")
    inventory = load("integration/f-pm/F-PM08D4_FIXED_WEIR_SOURCE_INVENTORY.json")
    audit = load("integration/f-pm/F-PM08D4_ARCHITECTURE_AUDIT.json")
    status = load("integration/f-pm/F-PM08D4_STATUS.json")

    mark("ACTIVATION_BASE_LOCKED", contract["source_authority"]["exact_branch_base"] == BASE)
    upstream = contract["authoritative_upstream"]
    mark("PARENT_D_LOCKED", upstream["fpm08d_parent_closeout"] == PARENT_D)
    mark("D1_LOCKED", upstream["fpm08d1_storage_readiness_closeout"] == D1)
    mark("D2_LOCKED", upstream["fpm08d2_extended_exchange_readiness_closeout"] == D2)
    mark("D3_LOCKED", upstream["fpm08d3_availability_mass_readiness_closeout"] == D3)

    scope = contract["restricted_scope"]
    mark("SWSEC2_ONLY", scope["SWSEC"] == 2 and scope["simulated_secondary_surface_water"] is True)
    mark("SWMAN1_FIXED_WEIR_ONLY", scope["SWMAN"] == 1 and scope["fixed_weir_target"] is True)
    mark("SWQHR1_ONLY", scope["SWQHR"] == 1 and scope["power_rating_curve"] is True)
    mark("SWQHR2_HELD", scope["tabulated_SWQHR_2"] is False)
    mark("AUTOMATIC_MANAGEMENT_HELD", scope["automatic_SWMan_2"] is False)
    mark("NO_PRODUCTION_CHANGE_ALLOWED", scope["production_source_changes_allowed"] is False)

    mass = contract["mass_and_balance_equations"]
    mark("MASS_CONSERVATION_ABSOLUTE", mass["mass_concession"] == "none")
    mark("SUPPLY_FIRST_CLASS", "q_supply" in mass["accepted_mass_identity"])
    mark("DISCHARGE_FIRST_CLASS", "q_discharge" in mass["accepted_mass_identity"])
    mark("TOP_SURFACE_VOLUME_EXPLICIT", "V_top_surface" in mass["accepted_mass_identity"])

    solve = contract["nonlinear_solve_contract"]
    mark("MASS_NOT_SOLVER_TOLERANCE", solve["mass_residual_is_solver_tolerance"] is False)
    mark("RATING_RESIDUAL_SEPARATE", solve["root_residual_and_mass_residual_must_be_reported_separately"] is True)
    mark("BRACKETED_REFERENCE_ROUTE", solve["bracketed_monotone_solution_required_as_reference_route"] is True)
    mark("NEWTON_ONLY_FORBIDDEN", solve["newton_only_dependency_forbidden"] is True)
    mark("D1_ENDPOINT_CLAMP_FORBIDDEN", solve["d1_endpoint_seams_must_not_be_silently_clamped"] is True)

    rating = contract["rating_curve"]
    mark("CREST_SINGULARITY_EXPLICIT", "diverges" in rating["crest_derivative"]["beta_lt_1"])
    mark("NO_HIDDEN_SMOOTHING", rating["hidden_smoothing_allowed"] is False)

    mark("ALL_NINE_SOURCE_RISKS_CONTRACTED", set(contract["explicit_source_holds"]) == RISKS)
    inventory_risks = {x["id"] for x in inventory["scientific_and_numerical_seams"]}
    mark("ALL_NINE_SOURCE_RISKS_INVENTORIED", inventory_risks == RISKS)

    inv_text = Path("integration/f-pm/F-PM08D4_FIXED_WEIR_SOURCE_INVENTORY.json").read_text()
    mark("LEGACY_0P001_STOP_CONFIRMED", "0.001" in inv_text and "SWST=SWSTN" in inv_text)
    mark("SWQHR2_THRESHOLD_SEAM_CONFIRMED", "Q<1e-4" in inv_text and "Q<1e-6" in inv_text)
    mark("LEGACY_NUMERICAL_HISTORY_SEPARATED", "WLSBAK" in inv_text and "numerical policy" in inv_text)

    invs = audit["invariants"]
    mark("ALL_30_INVARIANTS_PRESENT", len(invs) == 30 and {x["id"] for x in invs} == set(range(1, 31)))
    mark("ALL_30_INVARIANTS_PASS", all(x["pass"] for x in invs))

    mark("STATUS_BASE_LOCKED", status["source_authority"]["exact_branch_base"] == BASE)
    mark("STATUS_D3_LOCKED", status["parent_authorities"]["fpm08d3_closeout"] == D3)
    mark("STATUS_ALL_NINE_RISKS_BOUND", set(status["source_risk_holds"]) == RISKS)
    mark("STATUS_NO_PRODUCTION_CHANGE", status["state"]["production_source_changed"] is False)
    mark("STATUS_NO_REFERENCE_CHANGE", status["state"]["reference_source_changed"] is False)

    oracle = run("python3", "tests/fpm/test_fpm08d4_fixed_weir_balance.py")
    sys.stdout.write(oracle.stdout)
    if "FPM08D4_FIXED_WEIR_ORACLE PASS" not in oracle.stdout:
        sys.stderr.write(oracle.stderr)
        raise SystemExit(1)
    mark("EXECUTABLE_FIXED_WEIR_ORACLE", True)
    print("FPM08D4_FIXED_WEIR_READINESS_GATE PASS")


if __name__ == "__main__":
    main()
