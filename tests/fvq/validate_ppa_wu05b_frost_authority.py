#!/usr/bin/env python3
import argparse, json, pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[2]

def j(path):
    return json.loads((ROOT / path).read_text())

def req(cond, msg):
    if not cond:
        raise AssertionError(msg)

def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()

def authority():
    pre=j("integration/audits/PPA_WU05B_PREREGISTRATION.json")
    con=j("integration/audits/PPA_WU05B_FROST_AUTHORITY_CONTRACT.json")
    st=j("integration/audits/PPA_WU05B_STATUS.json")
    b0=(ROOT/"reference/swap-4.3.1/b0/file-manifest.sha256").read_text()
    f45=(ROOT/"integration/f-ci/F-CI45_STATUS.json").read_text()
    dep=j("integration/audits/PPA_WU05_DEPENDENCY_GRAPH.json")

    req(pre["workunit"]=="PPA-WU05-B", "wrong prereg workunit")
    req(con["workunit"]=="PPA-WU05-B", "wrong contract workunit")
    req(st["work_unit"]=="PPA-WU05-B", "wrong status workunit")
    ids=con["authority"]["corrected_reference"]["files"]
    req(ids["SWAP/frozencond.f90"] in b0, "frozencond identity absent from B0 manifest")
    req(ids["SWAP/temperature.f90"] in b0, "temperature identity absent from B0 manifest")
    req(dep["reference"]["patch_target_audit"]["frozencond"]=="unchanged from B0", "frozencond B1 patch relation drift")
    req(dep["reference"]["patch_target_audit"]["temperature"]=="unchanged from B0", "temperature B1 patch relation drift")
    req("no frost or latent-heat phase-change physics" in f45.lower(), "F-CI45 frost/latent-heat hold missing")
    req(con["frozen_boundaries"]["thermodynamic_phase_change"]=="OUTSIDE_LEGACY_MIGRATION_AUTHORITY_NEW_PHYSICS", "phase-change conflation")
    req(con["frozen_boundaries"]["restart"]=="UNKNOWN_DO_NOT_INFER until exact source trace.", "restart inferred")
    req(con["frozen_boundaries"]["recomputability"]=="UNKNOWN_DO_NOT_INFER until exact source trace.", "recomputability inferred")
    req(con["richards_consistency"]["swap011_preservation"].startswith("SWAP-011"), "SWAP-011 preservation missing")
    req(con["unresolved_source_trace"]["state"]=="BLOCKED_EXACT_SOURCE_MATERIALIZATION_REQUIRED", "source blocker not explicit")

    base=git("merge-base","HEAD","origin/integration/f-ci-canonical")
    changed=git("diff","--name-only",f"{base}...HEAD").splitlines()
    bad=[p for p in changed if p.startswith("src/") or p.startswith("reference/")]
    req(not bad, f"review mutated production/reference: {bad}")
    allowed=(
      ".github/workflows/ppa-wu05b-",
      "docs/audits/PPA_WU05B_",
      "integration/audits/PPA_WU05B_",
      "tests/fvq/validate_ppa_wu05b_",
    )
    extra=[p for p in changed if not p.startswith(allowed)]
    req(not extra, f"unexpected files: {extra}")

    print("PPA_WU05B_B111_IDENTITY_BINDING=PASS")
    print("PPA_WU05B_SENSIBLE_TEMPERATURE_HOLDS=PASS")
    print("PPA_WU05B_PHASE_CHANGE_NONCONFLATION=PASS")
    print("PPA_WU05B_SWAP011_CONSISTENCY_RULE=PASS")
    print("PPA_WU05B_SOURCE_BLOCKER_FAIL_CLOSED=PASS")
    print("PPA_WU05B_ZERO_PRODUCTION_REFERENCE_DELTA=PASS")

def independent():
    con=j("integration/audits/PPA_WU05B_FROST_AUTHORITY_CONTRACT.json")
    st=j("integration/audits/PPA_WU05B_STATUS.json")
    doc=(ROOT/"docs/audits/PPA_WU05B_FROST_AUTHORITY.md").read_text()
    req(con["production_admission"]=="NONE_REVIEW_ONLY_BLOCKED", "production admission claimed")
    req(st["production_admission"]=="NONE_REVIEW_ONLY_BLOCKED", "status production admission claimed")
    req("UNKNOWN_DO_NOT_INFER" in json.dumps(con), "unknown-state holds absent")
    req("latent heat" in doc.lower() and "new physics" in doc.lower(), "nonconflation narrative absent")
    req("PPA-WU05-B1" in doc and "PPA-WU05-B4" in doc, "migration slices absent")
    req("SOURCE_MATERIALIZATION_REQUIRED" in json.dumps(con), "source materialization hold absent")
    req("not an independent water mass" in doc.lower(), "mass nonclaim absent")
    req("K and dK/dh consistency" in doc, "Richards consistency section absent")
    req(con["migration_slices"][0]["state"]=="BLOCKED_SOURCE_MATERIALIZATION_REQUIRED", "B1 not blocked")
    print("PPA_WU05B_OWNER_BOUNDARY=PASS")
    print("PPA_WU05B_STATE_UNCERTAINTY_PRESERVED=PASS")
    print("PPA_WU05B_MASS_ENERGY_NONCONFLATION=PASS")
    print("PPA_WU05B_MIGRATION_SLICING=PASS")
    print("PPA_WU05B_REVIEW_ONLY_BLOCKER=PASS")

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--mode", choices=["authority","independent"], required=True)
    a=p.parse_args()
    authority() if a.mode=="authority" else independent()
    print(f"PPA-WU05-B {a.mode.upper()} VALIDATION PASS")

if __name__=="__main__":
    try: main()
    except Exception as e:
        print(f"PPA-WU05-B VALIDATION FAIL: {e}", file=sys.stderr)
        raise
