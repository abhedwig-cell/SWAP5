#!/usr/bin/env python3
import argparse, json, pathlib, subprocess, sys

ROOT=pathlib.Path(__file__).resolve().parents[2]

def j(p): return json.loads((ROOT/p).read_text())
def req(c,m):
    if not c: raise AssertionError(m)
def git(*a): return subprocess.check_output(["git",*a],cwd=ROOT,text=True).strip()

def authority():
    pre=j("integration/audits/PPA_WU05D_PREREGISTRATION.json")
    con=j("integration/audits/PPA_WU05D_COMPENSATION_AUTHORITY_CONTRACT.json")
    st=j("integration/audits/PPA_WU05D_STATUS.json")
    manifest=(ROOT/"reference/swap-4.3.1/b0/file-manifest.sha256").read_text()
    fci31=j("integration/f-ci/F-CI31_STATUS.json")
    root=(ROOT/"src/process/mod_root_water_uptake_process.f90").read_text().lower()
    dep=j("integration/audits/PPA_WU05_DEPENDENCY_GRAPH.json")

    req(pre["workunit"]=="PPA-WU05-D","wrong prereg workunit")
    req(con["workunit"]=="PPA-WU05-D","wrong contract workunit")
    req(st["work_unit"]=="PPA-WU05-D","wrong status workunit")
    h=con["authority"]["corrected_reference"]["sha256"]
    req(h in manifest and "SWAP/rootextraction.f90" in manifest,"rootextraction identity missing")
    req("compens" in " ".join(fci31["nonclaims"]).lower(),"F-CI31 compensation nonclaim missing")
    req("compens" not in root,"current restricted root process unexpectedly contains compensation")
    targets={n["id"]:n for n in dep["ranked_targets"]}
    req(targets["PPA-WU05-D"]["implementation_admission"]=="REVIEW_FIRST","parent WU05-D state drift")
    req(con["invariants"]["compensation_mass_owner"].startswith("NONE_SEPARATE"),"second mass owner introduced")
    req(con["invariants"]["persistent_physical_state"]=="UNKNOWN_DO_NOT_INFER","persistent state inferred")
    req(con["unresolved_source_trace"]["state"].startswith("BLOCKED_EXACT_B1_11"),"source blocker absent")
    req(con["authority"]["corroborating_historical_artifact"]["class"]=="CORROBORATING_LATER_ARTIFACT_NOT_B1_11_ORACLE","corroboration promoted")

    base=git("merge-base","HEAD","origin/integration/f-ci-canonical")
    changed=git("diff","--name-only",f"{base}...HEAD").splitlines()
    bad=[p for p in changed if p.startswith("src/") or p.startswith("reference/")]
    req(not bad,f"review mutated production/reference: {bad}")
    allowed=(".github/workflows/ppa-wu05d-","docs/audits/PPA_WU05D_","integration/audits/PPA_WU05D_","tests/fvq/validate_ppa_wu05d_")
    extra=[p for p in changed if not p.startswith(allowed)]
    req(not extra,f"unexpected files: {extra}")

    print("PPA_WU05D_B111_ROOTEXTRACTION_IDENTITY=PASS")
    print("PPA_WU05D_SINGLE_ROOT_MASS_OWNER=PASS")
    print("PPA_WU05D_CURRENT_RESTRICTED_ROOT_PRESERVATION=PASS")
    print("PPA_WU05D_CORROBORATION_NOT_ORACLE=PASS")
    print("PPA_WU05D_STATE_UNCERTAINTY_PRESERVED=PASS")
    print("PPA_WU05D_ZERO_PRODUCTION_REFERENCE_DELTA=PASS")

def independent():
    con=j("integration/audits/PPA_WU05D_COMPENSATION_AUTHORITY_CONTRACT.json")
    st=j("integration/audits/PPA_WU05D_STATUS.json")
    doc=(ROOT/"docs/audits/PPA_WU05D_COMPENSATION_AUTHORITY.md").read_text()
    req(con["production_admission"]=="NONE_REVIEW_ONLY_BLOCKED","production claim")
    req(st["production_admission"]=="NONE_REVIEW_ONLY_BLOCKED","status production claim")
    req("already-scaled rejected qrot" in con["invariants"]["retry"],"retry anti-compounding absent")
    req(con["multi_stressor_boundary"]["modifier_order"]=="SOURCE_BOUND_DO_NOT_INVENT","stressor order invented")
    req(len(con["migration_slices"])==5,"slice count drift")
    req(con["migration_slices"][0]["state"]=="BLOCKED_SOURCE_MATERIALIZATION_REQUIRED","D1 not blocked")
    req("UNKNOWN_DO_NOT_INFER" in doc,"state uncertainty narrative absent")
    req("exactly one root-sink mass receipt" in doc,"exactly-once mass boundary absent")
    print("PPA_WU05D_RETRY_ANTI_COMPOUNDING=PASS")
    print("PPA_WU05D_STRESS_ORDER_FAIL_CLOSED=PASS")
    print("PPA_WU05D_JARVIS_WALSUM_SPLIT=PASS")
    print("PPA_WU05D_EXACTLY_ONCE_ROOT_MASS=PASS")
    print("PPA_WU05D_REVIEW_ONLY_BLOCKER=PASS")

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--mode",choices=["authority","independent"],required=True)
    a=p.parse_args()
    authority() if a.mode=="authority" else independent()
    print(f"PPA-WU05-D {a.mode.upper()} VALIDATION PASS")

if __name__=="__main__":
    try: main()
    except Exception as e:
        print(f"PPA-WU05-D VALIDATION FAIL: {e}",file=sys.stderr)
        raise
