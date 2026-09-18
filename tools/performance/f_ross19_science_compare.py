from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path

A_CASE=re.compile(
    r"^F_ROSS19_CASE\|CASE=(?P<case>\d+)\|ISE=(?P<ise>\d+)\|M=(?P<material>[^|]+)\|F=(?P<forcing>[^|]+)"
    r"\|CLASS=(?P<classification>[^|]+)\|LIN=(?P<lin>-?\d+)\|RETRY=(?P<retry>-?\d+)\|ALT=(?P<alt>-?\d+)"
    r"\|FALLBACK=(?P<fallback>-?\d+)\|MASS=(?P<mass>[^|]+)\|TEMP=(?P<temp>[^|]+)"
    r"\|HINF=(?P<h_inf>[^|]+)\|HRMS=(?P<h_rms>[^|]+)"
    r"\|TINF=(?P<t_inf>[^|]+)\|TRMS=(?P<t_rms>[^|]+)\|STORAGE=(?P<storage>[^|]+)$"
)
A_H=re.compile(r"^F_ROSS19_H\|CASE=(?P<case>\d+)\|(?P<values>.*)$")
A_T=re.compile(r"^F_ROSS19_T\|CASE=(?P<case>\d+)\|(?P<values>.*)$")
K4_CASE=re.compile(
    r"^F_ROSS18_CASE\|CASE=(?P<case>\d+)\|ISE=(?P<ise>\d+)\|M=(?P<material>[^|]+)\|F=(?P<forcing>[^|]+)"
    r"\|CLASS=(?P<classification>[^|]+)\|LIN=(?P<lin>-?\d+)\|RETRY=(?P<retry>-?\d+)\|ALT=(?P<alt>-?\d+)"
    r"\|MASS=(?P<mass>[^|]+)\|TEMP=(?P<temp>[^|]+)"
    r"\|HINF=(?P<h_inf>[^|]+)\|HRMS=(?P<h_rms>[^|]+)"
    r"\|TINF=(?P<t_inf>[^|]+)\|TRMS=(?P<t_rms>[^|]+)\|STORAGE=(?P<storage>[^|]+)$"
)
K4_H=re.compile(r"^F_ROSS18_H\|CASE=(?P<case>\d+)\|(?P<values>.*)$")
K4_T=re.compile(r"^F_ROSS18_T\|CASE=(?P<case>\d+)\|(?P<values>.*)$")

def fnum(x):
    try: return float(x)
    except ValueError: return math.nan

def parse(path:Path,case_re,h_re,t_re,adaptive:bool):
    rows={}
    for raw in path.read_text(encoding="utf-8",errors="replace").splitlines():
        line=raw.strip()
        m=case_re.match(line)
        if m:
            d=m.groupdict(); c=int(d["case"])
            rows[c]={
                "case":c,"ise":int(d["ise"]),"material":d["material"].strip(),"forcing":d["forcing"].strip(),
                "classification":d["classification"].strip(),"linear_solves":int(d["lin"]),
                "internal_retries":int(d["retry"]),"alternative_solver_calls":int(d["alt"]),
                "mass_residual_cm":fnum(d["mass"]),"temporal_indicator":fnum(d["temp"]),
                "head_inf_vs_reference":fnum(d["h_inf"]),"head_rms_vs_reference":fnum(d["h_rms"]),
                "theta_inf_vs_reference":fnum(d["t_inf"]),"theta_rms_vs_reference":fnum(d["t_rms"]),
                "storage_abs_vs_reference_cm":fnum(d["storage"]),
            }
            if adaptive: rows[c]["fallback"]=int(d["fallback"])
            continue
        m=h_re.match(line)
        if m: rows.setdefault(int(m.group("case")),{})["h"]=[float(x) for x in m.group("values").split()]
        m=t_re.match(line)
        if m: rows.setdefault(int(m.group("case")),{})["theta"]=[float(x) for x in m.group("values").split()]
    if sorted(rows)!=list(range(1,37)): raise RuntimeError(f"{path}: missing cases")
    return rows

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--adaptive",type=Path,required=True)
    ap.add_argument("--k4",type=Path,required=True)
    ap.add_argument("--output",type=Path,required=True)
    args=ap.parse_args()
    a=parse(args.adaptive,A_CASE,A_H,A_T,True)
    k4=parse(args.k4,K4_CASE,K4_H,K4_T,False)

    paired=[r for r in a.values() if r["classification"]=="PAIRED_VALID_ADMISSIBLE"]
    valid=[r for r in a.values() if r["classification"] not in {"ROSSFAST_ROUTE_INVALID","BOTH_ROUTES_INVALID"}]
    temporal=[r for r in valid if math.isfinite(r["temporal_indicator"]) and r["temporal_indicator"]<=1.0]
    fallback=[r for r in valid if r["fallback"]==1]
    fast=[r for r in valid if r["fallback"]==0]
    fallback_cases=sorted(r["case"] for r in fallback)
    expected_fallback=[17,18]

    k4_compare=[]
    max_h=max_t=max_temp_rel=0.0
    for c in fallback_cases:
        ar=a[c]; kr=k4[c]
        dh=max(abs(x-y) for x,y in zip(ar["h"],kr["h"]))
        dt=max(abs(x-y) for x,y in zip(ar["theta"],kr["theta"]))
        tr=abs(ar["temporal_indicator"]-kr["temporal_indicator"])/max(abs(kr["temporal_indicator"]),1e-30)
        max_h=max(max_h,dh); max_t=max(max_t,dt); max_temp_rel=max(max_temp_rel,tr)
        k4_compare.append({"case":c,"head_inf":dh,"theta_inf":dt,"temporal_indicator_relative":tr})

    work_ok=all((r["linear_solves"]==6 and r["fallback"]==0) or
                (r["linear_solves"]==18 and r["fallback"]==1) for r in valid)
    retry_ok=all(r["internal_retries"]==0 and r["alternative_solver_calls"]==0 for r in valid)
    fallback_matches=(fallback_cases==expected_fallback and max_h<=1e-12 and max_t<=1e-12 and max_temp_rel<=1e-12)
    science_pass=(len(paired)==36 and len(valid)==36 and len(temporal)==36 and
                  len(fast)==34 and len(fallback)==2 and work_ok and retry_ok and fallback_matches)
    result={
        "schema":"swap5.f-ross19.adaptive-science-result.v1",
        "case_count":36,
        "paired_valid_admissible":len(paired),
        "route_valid":len(valid),
        "temporal_indicator_le_1":len(temporal),
        "fast_accept_count":len(fast),
        "fallback_count":len(fallback),
        "fallback_cases":fallback_cases,
        "work_count_contract_pass":work_ok,
        "retry_contract_pass":retry_ok,
        "fallback_matches_standalone_k4":fallback_matches,
        "fallback_k4_comparison":{
            "max_head_inf":max_h,"max_theta_inf":max_t,
            "max_temporal_indicator_relative":max_temp_rel,"records":k4_compare
        },
        "worst":{
            "temporal_indicator":max(r["temporal_indicator"] for r in valid),
            "head_inf_vs_reference":max(r["head_inf_vs_reference"] for r in valid),
            "theta_inf_vs_reference":max(r["theta_inf_vs_reference"] for r in valid),
            "mass_residual_abs_cm":max(abs(r["mass_residual_cm"]) for r in valid),
        },
        "mean_candidate_steps":sum(r["linear_solves"] for r in valid)/36.0,
        "scientific_gate":"PASS" if science_pass else "FAIL",
        "production_candidate_under_frozen_research_rule":science_pass,
        "rows":list(a.values()),
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print(json.dumps(result,indent=2,sort_keys=True))
    print(f"F_ROSS19_FALLBACK_COUNT={len(fallback)}")
    print(f"F_ROSS19_MEAN_LINEAR_SOLVES={result['mean_candidate_steps']:.12g}")
    print(f"F_ROSS19_SCIENTIFIC_GATE={result['scientific_gate']}")
    return 0 if science_pass else 2

if __name__=="__main__":
    raise SystemExit(main())
