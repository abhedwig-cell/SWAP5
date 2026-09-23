#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, math
from pathlib import Path

TOL=1.0e-12
EXPECTED_O0={
  "B01_R512_T32_V02_O0","B01_R1024_T32_V02_O0","B01_R2048_T32_V02_O0",
  "B14_R512_T32_V01_O0","B14_R1024_T32_V01_O0","B14_R2048_T32_V01_O0"
}
SENTINELS=[
  ("B01_R1024_T32_V02_O0","B01_R1024_T32_V02_O2"),
  ("B14_R512_T32_V01_O0","B14_R512_T32_V01_O2"),
]

def kv(line:str)->dict[str,str]:
    out={}
    for part in line.strip().split("|")[1:]:
        if "=" in part:
            k,v=part.split("=",1); out[k]=v
    return out

def f(x:str)->float:
    return float(x.replace("D","E").replace("d","e"))

def parse(log:Path, rc_path:Path)->dict:
    raw=log.read_text(errors="replace")
    rc=int(rc_path.read_text().strip()) if rc_path.exists() else 999
    fallbacks=[]
    histories=[]
    for line in raw.splitlines():
        if line.startswith("RNP04_FALLBACK|"):
            d=kv(line)
            dt=f(d["T1"])-f(d["HISTORY_STEP_T0"])
            bound=f(d["REP_BOUND_CM"])
            expected=max(TOL,bound/dt)
            item={
              "class":d["CLASS"].strip(),
              "balance_flags":int(d["BAL_FLAGS"]),
              "head_flags":int(d["HEAD_FLAGS"]),
              "rmax":f(d["RMAX"]),
              "rsum":f(d["RSUM"]),
              "representation_bound_cm":bound,
              "abs_total_residual_cm":f(d["ABS_TOTAL_RESIDUAL_CM"]),
              "fallback_cp_tol":f(d["FALLBACK_CP_TOL"]),
              "fallback_total_tol":f(d["FALLBACK_TOTAL_TOL"]),
              "expected_total_tol":expected,
              "failed_nl":int(d["FAILED_NL"]),
              "failed_backtracking":int(d["FAILED_BACKTRACK"]),
              "accept_nl":int(d["ACCEPT_NL"]),
              "accept_backtracking":int(d["ACCEPT_BACKTRACK"]),
            }
            item["admission_ok"]=(
              item["class"]=="RETRY_TOTAL_ONLY" and item["balance_flags"]==0 and item["head_flags"]==0
              and item["rmax"] <= TOL
              and item["abs_total_residual_cm"] <= bound
              and item["fallback_cp_tol"] == TOL
              and math.isclose(item["fallback_total_tol"],expected,rel_tol=0.0,abs_tol=max(1e-24,abs(expected)*1e-14))
              and item["failed_nl"]==16 and item["accept_nl"]<=16
            )
            fallbacks.append(item)
        elif line.startswith("LAREDYN0R_HISTORY_PASS|"):
            d=kv(line)
            histories.append({
              "fallbacks":int(d["FALLBACKS"]),
              "max_abs_mass":f(d["MAX_ABS_MASS"]),
              "final_revision":int(d["FINAL_REV"]),
              "final_time":f(d["FINAL_T"]),
            })
    complete="RNP04_REFERENCE_POLICY_COMPLETE=PASS" in raw
    hist=histories[-1] if histories else None
    return {
      "return_code":rc,
      "complete":complete,
      "history":hist,
      "fallback_count":len(fallbacks),
      "fallbacks":fallbacks,
      "sha256":hashlib.sha256(log.read_bytes()).hexdigest(),
      "qualified":(
        rc==0 and complete and hist is not None
        and hist["fallbacks"]==len(fallbacks)
        and hist["max_abs_mass"]<=1.0e-12
        and all(x["admission_ok"] for x in fallbacks)
      )
    }

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--dir",required=True,type=Path)
    ap.add_argument("--output",required=True,type=Path)
    args=ap.parse_args()
    cases={}
    for log in sorted(args.dir.glob("*.txt")):
        if log.name.endswith("_rc.txt"):
            continue
        stem=log.stem
        rc=args.dir/(stem+"_rc.txt")
        cases[stem]=parse(log,rc)
    missing=sorted((EXPECTED_O0|{b for p in SENTINELS for b in p})-set(cases))
    sentinel_results=[]
    for a,b in SENTINELS:
        present=a in cases and b in cases
        identical=present and cases[a]["sha256"]==cases[b]["sha256"]
        sentinel_results.append({"pair":[a,b],"present":present,"byte_identical":identical})
    full_o0=all(name in cases and cases[name]["qualified"] for name in EXPECTED_O0)
    clean=full_o0 and all(x["admission_ok"] for name in EXPECTED_O0 for x in cases[name]["fallbacks"])
    opt_identical=all(x["byte_identical"] for x in sentinel_results)
    result={
      "schema":"swap5.rom_root.rnp04.result.v1",
      "work_unit":"ROM-ROOT-RNP04",
      "status":"POLICY_QUALIFICATION_COMPLETE",
      "cases":cases,
      "missing_cases":missing,
      "optimization_sentinels":sentinel_results,
      "classifications":{
        "FULL_O0_MATRIX_QUALIFIED":full_o0,
        "POLICY_ADMISSION_CLEAN":clean,
        "O0_O2_SENTINELS_IDENTICAL":opt_identical,
        "ROOT_ACTIVE_REFERENCE_POLICY_QUALIFIED":full_o0 and clean and opt_identical
      },
      "policy_decision_authorized":True,
      "c6r_reopened":False,
      "reduced_candidate_response_generated":False,
      "production_source_changed":False
    }
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"status":result["status"],"classifications":result["classifications"],"missing":missing},sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
