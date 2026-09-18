#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib

def fields(s):
    out={}
    for p in s.split("|"):
        if "=" in p:
            k,v=p.split("=",1); out[k]=v
    return out

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True)
    ap.add_argument("--repeat",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    text=pathlib.Path(a.input).read_text()
    repeat=pathlib.Path(a.repeat).read_text()
    rows=[]
    for line in text.splitlines():
        if "F_ROM0R_R3D1_CLASS|" in line:
            rows.append(fields(line.split("F_ROM0R_R3D1_CLASS|",1)[1]))
    expected={"BOTTOM_HEAD_RISE","BOTTOM_HEAD_FALL"}
    got={r.get("CASE") for r in rows}
    repeat_identity=text==repeat
    classes=[r.get("CLASS","") for r in rows]
    valid_classes={"RETRY_LOCAL_BALANCE","RETRY_HEAD","RETRY_TOTAL_ONLY","RETRY_MIXED","RETRY_OTHER"}
    if len(rows)!=2 or got!=expected or any(c not in valid_classes for c in classes):
        decision="B01_RETRY_CAUSE_DIAGNOSTIC_BLOCKED"
    elif classes[0]!=classes[1]:
        decision="B01_RETRY_CAUSE_NONUNIFORM"
    else:
        decision={
          "RETRY_LOCAL_BALANCE":"B01_RETRY_LOCAL_BALANCE_CLASSIFIED",
          "RETRY_HEAD":"B01_RETRY_HEAD_CLASSIFIED",
          "RETRY_TOTAL_ONLY":"B01_RETRY_TOTAL_ONLY_CLASSIFIED",
          "RETRY_MIXED":"B01_RETRY_MIXED_CLASSIFIED",
          "RETRY_OTHER":"B01_RETRY_OTHER_CLASSIFIED",
        }[classes[0]]
    result={
      "schema":"swap5.f-rom0r.r3d1-result.v1",
      "work_unit":"ROM-0R-R3D1",
      "decision":decision,
      "repeat_stdout_bitwise_identity":repeat_identity,
      "rows":[{
        "case":r["CASE"],
        "classification":r["CLASS"],
        "local_balance_flag_count":int(r["BAL_FLAGS"]),
        "head_flag_count":int(r["HEAD_FLAGS"]),
        "max_abs_local_residual":float(r["RMAX"]),
        "total_residual":float(r["RSUM"]),
        "max_residual_node":int(r["IMAX"]),
        "compartment_tolerance":float(r["CP_TOL"]),
        "total_tolerance":float(r["TOT_TOL"]),
        "nonlinear_iterations":int(r["NL"]),
        "backtracking_attempts":int(r["BACKTRACK"]),
        "fmr_backtracking_attempts":int(r["FMR_BACKTRACK"]),
      } for r in rows],
      "production_or_reference_source_mutated":False,
      "controls_changed":False,
      "p2e21_policy_imported":False,
      "rom1a_authorized":False,
    }
    pathlib.Path(a.output).write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(result,sort_keys=True))
    if decision=="B01_RETRY_CAUSE_DIAGNOSTIC_BLOCKED" or not repeat_identity:
        return 2
    return 0

if __name__=="__main__":
    raise SystemExit(main())
