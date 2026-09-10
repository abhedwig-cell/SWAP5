#!/usr/bin/env python3
import json
import subprocess
import sys
from pathlib import Path

BASE = "9e13bdcfd4b9ec6c93a2050e95cc8bad127aca6d"
ARCHIVE_SHA = "1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151"
SURFACEWATER_SHA = "d38e25da1b71cf3d7872df294b1de6080e070a314f9168b8a4e4d3ff1526089e"
PARENT_D = "4fc92f14baa5ae289839826032f9aa66776e2192"
D1 = "dc523f6510e4fb14cdd09ce2ec26f0b3f613f499"
D3 = "eb57bd2ffa9ee33a3d198e8424edc91556957344"
D4 = "d45b5b09cb8143a9b7c01fe3021630aa5a4bf49e"
RISKS = {
    "D5-RISK-01-LEGACY-DAY-AND-CALENDAR-EVENT-ARITHMETIC",
    "D5-RISK-02-INITIAL-TCUM-IMPLICIT-ADJUSTMENT-TRIGGER",
    "D5-RISK-03-WLSTAR-IS-CONDITIONAL-COMMITTED-CONTROL-MEMORY",
    "D5-RISK-04-DROPR-0P001-ACTIVATION-SEAM",
    "D5-RISK-05-SWQHR1-CURRENT-WLS-VS-SWQHR2-TARGET-WLSTAR-CAPACITY-ASYMMETRY",
    "D5-RISK-06-SWQHR1-NEGATIVE-WOVER-POWER-DOMAIN",
    "D5-RISK-07-STRICT-DISCAP-GREATER-THAN-WDIS-EQUALITY-SEAM",
    "D5-RISK-08-D4-OVERFLOW-FALLBACK-STATE-INCONSISTENCY-MUST-NOT-RETURN",
    "D5-RISK-09-HEAD-DEPTH-TO-NODE-MAPPING-MUST-NOT-COUPLE-CONTROL-TO-SOLVER-INTERNALS",
    "D5-RISK-10-WLSBAK-OSSWLM-NUMERICAL-HISTORY-SEPARATE-FROM-CONTROL-STATE",
    "D5-RISK-11-SWQHR2-HBWEIR-THRESHOLD-SEAM-REMAINS-UNQUALIFIED",
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
        print(f"FPM08D5_{name}=FAIL")
        raise SystemExit(1)
    print(f"FPM08D5_{name}=PASS")


def load(path):
    return json.loads(Path(path).read_text())


def main():
    changed = [x for x in run("git", "diff", "--name-only", f"{BASE}..HEAD").stdout.splitlines() if x]
    allowed = all(
        p.startswith("integration/f-pm/F-PM08D5_")
        or p == "tests/fpm/test_fpm08d5_automatic_control.py"
        or p == "tools/fpm/fpm08d5_automatic_control_readiness_gate.py"
        or p == ".github/workflows/fpm08d5-automatic-control-readiness.yml"
        for p in changed
    )
    mark("READINESS_ONLY_FILE_DELTA", allowed)
    mark("NO_PRODUCTION_SOURCE_DELTA", not any(p.startswith("src/") for p in changed))
    mark("NO_REFERENCE_SOURCE_DELTA", not any(p.startswith("reference/") for p in changed))

    manifest = run("git", "show", f"{BASE}:reference/swap-4.3.1/b0/file-manifest.sha256").stdout
    mark("FROZEN_ARCHIVE_IDENTITY", ARCHIVE_SHA in manifest)
    mark("FROZEN_SURFACEWATER_IDENTITY", SURFACEWATER_SHA in manifest and "SWAP/surfacewater.f90" in manifest)

    upstream_ok = all(
        run("git", "cat-file", "-e", f"{sha}^{{commit}}", check=False).returncode == 0
        for sha in (PARENT_D, D1, D3, D4)
    )
    mark("UPSTREAM_COMMITS_EXIST", upstream_ok)

    contract = load("integration/f-pm/F-PM08D5_READINESS_CONTRACT.json")
    inventory = load("integration/f-pm/F-PM08D5_AUTOMATIC_CONTROL_SOURCE_INVENTORY.json")
    audit = load("integration/f-pm/F-PM08D5_ARCHITECTURE_AUDIT.json")
    status = load("integration/f-pm/F-PM08D5_STATUS.json")

    mark("ACTIVATION_BASE_LOCKED", contract["source_authority"]["exact_branch_base"] == BASE)
    up = contract["authoritative_upstream"]
    mark("PARENT_D_LOCKED", up["fpm08d_parent_closeout"] == PARENT_D)
    mark("D1_LOCKED", up["fpm08d1_storage_readiness_closeout"] == D1)
    mark("D3_LOCKED", up["fpm08d3_mass_readiness_closeout"] == D3)
    mark("D4_LOCKED", up["fpm08d4_fixed_weir_readiness_closeout"] == D4)

    scope = contract["scope"]
    mark("SWMAN2_TARGET_SCOPE", scope["SWMAN_2_target_selection"] is True)
    mark("GENERIC_EVENT_SCOPE", scope["explicit_generic_event_schedule"] is True)
    mark("WLSTAR_STATE_SCOPE", scope["conditional_WLSTAR_control_memory"] is True)
    mark("CLEAN_HYDRAULIC_VIEW_SCOPE", scope["clean_scalar_hydraulic_control_view"] is True)
    mark("CAPACITY_POLICY_NOT_ADMITTED", scope["automatic_capacity_production_policy_admission"] is False)
    mark("SWQHR2_NOT_ADMITTED", scope["SWQHR_2_production_admission"] is False)
    mark("NO_PRODUCTION_CHANGE_ALLOWED", scope["production_source_changes_allowed"] is False)

    ev = contract["event_translation"]
    mark("CALENDAR_EXTERNALIZED", "outside kernel" in ev["modern_rule"])
    mark("EVENT_SUBDIVISION_REQUIRED", "subdivide interval" in ev["event_inside_interval"])
    target = contract["target_selection"]
    mark("INITIAL_EVENT_EXPLICIT", "explicit initial" in target["initialization"])
    mark("BETWEEN_EVENTS_REUSE_WLSTAR", "reuse committed WLSTAR exactly" in target["between_adjustment_events"])

    control_inputs = contract["control_inputs"]
    mark("THREE_SCALAR_HYDRAULIC_VIEW", set(control_inputs["physical_hydraulic_summary"]) == {"groundwater_level", "total_air_volume", "selected_pressure_head"})
    forbidden = " ".join(control_inputs["forbidden_dependencies"])
    mark("NO_HEADCALC_INTERNAL_DEPENDENCY", "HeadCalc internal arrays" in forbidden)
    mark("NO_THETA_ARRAY_TRAVERSAL_IN_POLICY", "THETA/THETAS/DZ traversal" in forbidden)

    state = contract["control_state"]
    mark("WLSTAR_ONLY_PHYSICAL_CONTROL_MEMORY", state["persistent_physical_control_memory"] == ["WLSTAR only when SWMAN=2"])
    not_state = set(state["not_physical_state"])
    mark("NUMERICAL_HISTORY_SEPARATED", {"NUMADJ", "WLSBAK", "OSSWLM"}.issubset(not_state))
    mark("TRIAL_WLSTAR_ROLLBACK_REQUIRED", "rollback exactly" in state["transactional_requirement"])

    drop = contract["drop_rate"]
    mark("DROPR_SEAM_EXPLICIT", drop["DROPR_at_or_below_0p001_means_no_limiting_in_frozen_source"] is True)
    mark("DROP_RATE_GENERIC_DT", drop["dt_is_generic_interval_duration"] is True)
    mark("DROP_RATE_ROLLBACK", drop["rejected_trial_must_not_advance_WLSTAR"] is True)

    cap = contract["capacity_discrepancy"]
    mark("QHR_HEAD_ASYMMETRY_EXPLICIT", "current WLS" in cap["source_SWQHR1"] and "target WLSTAR" in cap["source_SWQHR2"])
    mark("NEGATIVE_WOVER_RISK_EXPLICIT", "negative" in cap["risk_current_WLS_below_crest"])
    mark("NO_SILENT_CAPACITY_RECONCILIATION", "no automatic-weir capacity production formula is admitted" in cap["disposition"])
    mark("D4_OVERFLOW_HOLD_INHERITED", "must not reproduce legacy inconsistent SWST/WLS" in cap["overflow_fallback"])

    mark("ALL_ELEVEN_SOURCE_RISKS_CONTRACTED", set(contract["explicit_source_holds"]) == RISKS)
    inventory_risks = {x["id"] for x in inventory["source_risks"]}
    mark("ALL_ELEVEN_SOURCE_RISKS_INVENTORIED", inventory_risks == RISKS)
    inv_text = Path("integration/f-pm/F-PM08D5_AUTOMATIC_CONTROL_SOURCE_INVENTORY.json").read_text()
    mark("SOURCE_EVENT_TRIGGER_CONFIRMED", "rday=(T+1)/INTWL" in inv_text and "tcum<1e-10" in inv_text)
    mark("SOURCE_CAPACITY_ASYMMETRY_CONFIRMED", "WLS-HBWEIR" in inv_text and "FUN_QHTAB(IMPER,WLSTAR)" in inv_text)
    mark("SOURCE_STRICT_EQUALITY_SEAM_CONFIRMED", "equality is treated as overflow" in inv_text)

    invs = audit["invariants"]
    mark("ALL_30_INVARIANTS_PRESENT", len(invs) == 30 and {x["id"] for x in invs} == set(range(1,31)))
    mark("ALL_30_INVARIANTS_PASS", all(x["pass"] for x in invs))

    mark("STATUS_BASE_LOCKED", status["source_authority"]["exact_branch_base"] == BASE)
    mark("STATUS_D4_LOCKED", status["parent_authorities"]["fpm08d4_closeout"] == D4)
    mark("STATUS_ALL_ELEVEN_RISKS_BOUND", set(status["source_risk_holds"]) == RISKS)
    mark("STATUS_NO_PRODUCTION_CHANGE", status["state"]["production_source_changed"] is False)
    mark("STATUS_NO_REFERENCE_CHANGE", status["state"]["reference_source_changed"] is False)
    mark("STATUS_CAPACITY_POLICY_UNQUALIFIED", status["state"]["automatic_capacity_policy_qualified"] is False)

    oracle = run("python3", "tests/fpm/test_fpm08d5_automatic_control.py")
    sys.stdout.write(oracle.stdout)
    if "FPM08D5_AUTOMATIC_CONTROL_ORACLE PASS" not in oracle.stdout:
        sys.stderr.write(oracle.stderr)
        raise SystemExit(1)
    mark("EXECUTABLE_AUTOMATIC_CONTROL_ORACLE", True)
    print("FPM08D5_AUTOMATIC_CONTROL_READINESS_GATE PASS")


if __name__ == "__main__":
    main()
