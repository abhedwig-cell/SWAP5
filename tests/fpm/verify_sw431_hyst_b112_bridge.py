#!/usr/bin/env python3
"""NUT B1.12 preservation successor for the opt-in SW431 HYST runtime layout.

Immutable NUT evidence is checked at its owning admitted source.  The current
merge tree gets a fresh O0/O2 NUT production test, while non-HYST layout code
is required to be byte-for-byte equal to the current canonical first parent.
This is a narrow successor, not a reissue of historical evidence digests.
"""
from pathlib import Path
import base64, hashlib, json, os, subprocess, sys, tempfile

ROOT=Path(__file__).resolve().parents[2]
CORE="src/runtime/mod_fmr_runtime_core.f90"
B112_COMMIT="f1f1e99e8e2bf352a75aec97145e01853530d9fe"
RECORD="integration/audits/MC_NUT_SOL_STATUS.json"
ARCHIVE="integration/audits/evidence/MC_NUT01_B112_RETAINED_QUALIFICATION_20261017.tar.xz.b64"

def git(*args, cwd=ROOT):
    return subprocess.check_output(["git",*args], cwd=cwd, text=True).strip()

def check(v, why):
    if not v: raise ValueError(why)

def sha(x):
    return hashlib.sha256(x).hexdigest()

head=git("rev-parse","HEAD")
base=git("rev-parse","HEAD^1")
check(git("rev-parse","HEAD^2"),"expected qualified PR merge-tree checkout")
check(git("rev-parse","HEAD:reference")==git("rev-parse",base+":reference"),"reference changed")
previous=subprocess.check_output(["git","show",base+":"+CORE],cwd=ROOT).decode()
current=(ROOT/CORE).read_text()
anchor="  integer(int64), parameter, public :: FMR_OPTIONAL_STATE_LAYOUT_RUTTER = 505003_int64\n"
addition="  integer(int64), parameter, public :: FMR_OPTIONAL_STATE_LAYOUT_HYSTERESIS = 431101_int64\n"
case_before="          FMR_OPTIONAL_STATE_LAYOUT_RUTTER)\n"
case_after="          FMR_OPTIONAL_STATE_LAYOUT_RUTTER, FMR_OPTIONAL_STATE_LAYOUT_HYSTERESIS)\n"
check(previous.count(anchor)==1 and previous.count(case_before)==1,"unknown canonical layout contract")
expected=previous.replace(anchor,anchor+addition).replace(case_before,case_after)
check(current==expected,"HYST altered existing optional layout/known-set semantics")
check(current.count(addition)==1 and current.count(case_after)==1,"HYST layout ambiguous")
print("SW431_HYST_B112_DEFAULT_LAYOUT_EXACT_PARENT_PROJECTION=PASS",flush=True)

# The PR is not authorized to change B1.12 process/crop nitrogen owners. A
# change in the moving canonical parent is handled by its own admission owner.
excluded=["src/process/mod_soil_n_pool_state.f90",
          "src/process/mod_crop_senescence_residue.f90",
          "src/crop/mod_wofost81_nitrogen.f90",
          "src/runtime/mod_fmr_b111_reactive_n_route.f90",
          "src/runtime/mod_fmr_crop_soil_n_material_application.f90"]
for path in excluded:
    check(git("rev-parse","HEAD:"+path)==git("rev-parse",base+":"+path),"unowned NUT change "+path)
print("SW431_HYST_B112_NUT_OWNER_CODE_PRESERVATION=PASS",flush=True)

record=json.loads((ROOT/RECORD).read_text())["b112_retained_stock_20261016"]
check(record["qualified"] is True and record["aquifer"]=="EXCLUDED"
      and record["ledger_promotion"]==[],"unqualified NUT B1.12 inheritance")
evidence=record["evidence"]
check(evidence["path"]==ARCHIVE,"unknown NUT qualification archive")
raw=base64.b64decode((ROOT/ARCHIVE).read_bytes())
check(sha(raw)==evidence["sha256"] and len(raw)==evidence["bytes"],
      "immutable B1.12 qualification archive drift")
print("SW431_HYST_B112_FROZEN_EVIDENCE_IDENTITY=PASS",flush=True)

# Verify the immutable admission with its original script in its original
# checkout. Never fool the original verifier with projected or substituted
# file bytes, and never modify its input hashes.
with tempfile.TemporaryDirectory(prefix="swap5-hyst-b112-") as workdir:
    worktree=Path(workdir)/"incumbent"
    subprocess.run(["git","worktree","add","--detach",str(worktree),B112_COMMIT],
                   cwd=ROOT,check=True,capture_output=True)
    try:
        p=subprocess.run([sys.executable,"-B","tests/nut-crop/verify_b112_retained_successor.py"],
                         cwd=worktree,capture_output=True,text=True,
                         env={**os.environ,"PYTHONDONTWRITEBYTECODE":"1"})
        check(p.returncode==0,"frozen admitted NUT proof rejected "+p.stderr[-1800:])
        print("SW431_HYST_B112_FROZEN_ADMITTED_OWNER_VERIFIED=PASS",flush=True)
    finally:
        subprocess.run(["git","worktree","remove","--force",str(worktree)],
                       cwd=ROOT,check=True,capture_output=True)

# Fresh real production NUT stock/harvest/partition O0/O2 against the exact
# *current* merge tree, never against an old checkout or a copied formula.
with tempfile.TemporaryDirectory(prefix="swap5-hyst-b112-native-") as tmp:
    out=Path(tmp)/"native"
    p=subprocess.run([sys.executable,"-B","tests/nut-crop/run_b112_retained.py",
                      "--output",str(out)],cwd=ROOT,capture_output=True,text=True,
                     env={**os.environ,"PYTHONDONTWRITEBYTECODE":"1"})
    check(p.returncode==0,"current NUT O0/O2 native failure "+p.stdout[-1400:]+p.stderr[-1400:])
    result=json.loads((out/"result.json").read_text())
    check(result["execution_commit"]==head,"NUT test executed wrong merge tree")
    check(result["status"]=="B112_SMALL_PRODUCTION_PASS_NOT_ADMITTED","unexpected NUT result")
    check(result["runs"]["O0"]==result["runs"]["O2"],"NUT numerical optimization drift")
    for opt in ("O0","O2"):
        data=result["runs"][opt]
        check("B112_PHYSICAL_PARTITION_CASES=20" in data["test_b112_retained_split"],"NUT stock split missing")
        check("B112_ACTUAL_DAILY_PARTIAL_HARVEST_CASES=54" in data["test_b112_retained_day"],"NUT daily/harvest missing")
        check("B112_REAL_INVALID_STORAGE_RESIDUE_REJECTIONS=27" in data["test_b112_retained_day"],"NUT invalid residue accepted")
    print("SW431_HYST_B112_CURRENT_NATIVE_O0_O2=PASS",flush=True)
print("SW431_HYD_HYST_B112_IMPACT_SUCCESSOR=PASS",flush=True)
