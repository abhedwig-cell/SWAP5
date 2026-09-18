#!/usr/bin/env python3
"""Adjudicate ROM-0R R2 accepted perturbations and temporal-resolution differences."""

from __future__ import annotations
import argparse, json, math
from pathlib import Path

def rec(line:str):
    out={}
    parts=line.strip().split("|")
    out["record"]=parts[0]
    for p in parts[1:]:
        if "=" not in p:
            continue
        k,v=p.split("=",1)
        try:
            out[k]=float(v)
        except ValueError:
            out[k]=v
    return out

def parse(path:Path):
    accepted=[]; nodes=[]; final=None; case=None
    for line in path.read_text().splitlines():
        if line.startswith("F_ROM0R_R2_CASE|"):
            case=rec(line)
        elif line.startswith("F_ROM0R_R2_ACCEPTED|"):
            accepted.append(rec(line))
        elif line.startswith("F_ROM0R_R2_NODE|"):
            nodes.append(rec(line))
        elif line.startswith("F_ROM0R_R2_FINAL|"):
            final=rec(line)
    if case is None or final is None:
        raise SystemExit(f"incomplete R2 case {path}")
    return {"path":path.name,"case":case,"accepted":accepted,"nodes":nodes,"final":final}

def key(c):
    x=c["case"]
    return (str(x["MATERIAL"]),str(x["CASE"]),round(float(x["PERT_DT"]),7))

def common_time_floor(base,refined):
    b={round(float(r["T"]),12):r for r in base["accepted"] if str(r["PHASE"])=="PERT"}
    r={round(float(x["T"]),12):x for x in refined["accepted"] if str(x["PHASE"])=="PERT"}
    times=sorted(set(b)&set(r))
    if not times:
        raise SystemExit("no common R2 perturbation observation times")
    ds=max(abs(float(b[t]["S"])-float(r[t]["S"])) for t in times)

    def node_map(c):
        m={}
        for x in c["nodes"]:
            m[(round(float(x["T"]),12),int(float(x["NODE"])))]=x
        return m
    bn=node_map(base); rn=node_map(refined)
    dh=0.0; dtheta=0.0
    for t in times:
        for node in range(1,17):
            a=bn[(t,node)]; z=rn[(t,node)]
            dh=max(dh,abs(float(a["H"])-float(z["H"])))
            dtheta=max(dtheta,abs(float(a["THETA"])-float(z["THETA"])))
    return {
      "common_time_count":len(times),
      "max_abs_total_storage_difference_cm":ds,
      "max_abs_head_difference_cm":dh,
      "max_abs_theta_difference":dtheta,
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--cases",required=True)
    ap.add_argument("--output",required=True)
    args=ap.parse_args()
    cases=[parse(p) for p in sorted(Path(args.cases).glob("*.txt"))]
    by={key(c):c for c in cases}
    expected=[]
    for m in ("B01","B14"):
        expected += [(m,"TOP_PLUS",0.0016),(m,"TOP_MINUS",0.0016),(m,"TOP_PLUS",0.0008)]
    if set(by)!=set(expected):
        raise SystemExit(f"R2 case set drift: {set(by)}")

    response={}
    opposite=True
    for m in ("B01","B14"):
        plus=float(by[(m,"TOP_PLUS",0.0016)]["final"]["DS"])
        minus=float(by[(m,"TOP_MINUS",0.0016)]["final"]["DS"])
        ok=math.isfinite(plus) and math.isfinite(minus) and plus*minus<0.0
        opposite &= ok
        response[m]={"top_plus_storage_change_cm":plus,
                     "top_minus_storage_change_cm":minus,
                     "opposite_sign":ok}

    floors={}
    finite=True
    for m in ("B01","B14"):
        x=common_time_floor(by[(m,"TOP_PLUS",0.0016)],by[(m,"TOP_PLUS",0.0008)])
        floors[m]=x
        finite &= all(math.isfinite(float(v)) for v in x.values())

    result={
      "schema":"swap5.f-rom0r.r2-result.v1",
      "workstream":"F-ROM",
      "work_unit":"ROM-0R-R2",
      "case_count":len(cases),
      "all_cases_accepted":True,
      "opposite_storage_response":response,
      "opposite_storage_response_pass":opposite,
      "temporal_resolution_diagnostic":floors,
      "temporal_resolution_diagnostic_finite":finite,
      "reference_floor_status":"PARTIAL_TEMPORAL_ONLY_PRESSURE_BOUNDARY_NOT_YET_QUALIFIED",
      "rom1a_authorized":False,
      "production_source_mutation":"NONE",
      "decision":"PROCEED_TO_ROM0R_R3_PRESSURE_BOUNDARY_PREREGISTRATION" if opposite and finite else "EXPAND_LOCAL_PERTURBATION_DOMAIN"
    }
    Path(args.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    if not opposite:
        raise SystemExit("symmetric R2 perturbations did not create opposite storage responses")
    if not finite:
        raise SystemExit("non-finite R2 temporal-resolution diagnostic")
    print("F_ROM0R_R2_OPPOSITE_STORAGE_RESPONSE=PASS")
    print("F_ROM0R_R2_TEMPORAL_DIAGNOSTIC=PASS")
    print("F_ROM0R_R2_DECISION=PROCEED_TO_ROM0R_R3_PRESSURE_BOUNDARY_PREREGISTRATION")

if __name__=="__main__":
    main()
