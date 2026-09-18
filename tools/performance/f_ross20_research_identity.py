from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path

CASE_RE=re.compile(
    r"^F_ROSS19_CASE\|CASE=(?P<case>\d+)\|ISE=(?P<ise>\d+)\|M=(?P<material>[^|]+)\|F=(?P<forcing>[^|]+)"
    r"\|CLASS=(?P<classification>[^|]+)\|LIN=(?P<lin>-?\d+)\|RETRY=(?P<retry>-?\d+)\|ALT=(?P<alt>-?\d+)"
    r"\|FALLBACK=(?P<fallback>-?\d+)\|MASS=(?P<mass>[^|]+)\|TEMP=(?P<temp>[^|]+)"
    r"\|HINF=(?P<h_inf>[^|]+)\|HRMS=(?P<h_rms>[^|]+)"
    r"\|TINF=(?P<t_inf>[^|]+)\|TRMS=(?P<t_rms>[^|]+)\|STORAGE=(?P<storage>[^|]+)$"
)
H_RE=re.compile(r"^F_ROSS19_H\|CASE=(?P<case>\d+)\|(?P<values>.*)$")
T_RE=re.compile(r"^F_ROSS19_T\|CASE=(?P<case>\d+)\|(?P<values>.*)$")

def fnum(x:str)->float:
    try:return float(x)
    except ValueError:return math.nan

def parse(path:Path)->dict[int,dict]:
    rows={}
    for raw in path.read_text(encoding="utf-8",errors="replace").splitlines():
        line=raw.strip()
        m=CASE_RE.match(line)
        if m:
            d=m.groupdict(); c=int(d["case"])
            rows[c]={
                "case":c,"ise":int(d["ise"]),"material":d["material"].strip(),"forcing":d["forcing"].strip(),
                "classification":d["classification"].strip(),"linear_solves":int(d["lin"]),
                "internal_retries":int(d["retry"]),"alternative_solver_calls":int(d["alt"]),
                "fallback":int(d["fallback"]),"mass_residual_cm":fnum(d["mass"]),
                "temporal_indicator":fnum(d["temp"]),"head_inf_vs_reference":fnum(d["h_inf"]),
                "head_rms_vs_reference":fnum(d["h_rms"]),"theta_inf_vs_reference":fnum(d["t_inf"]),
                "theta_rms_vs_reference":fnum(d["t_rms"]),"storage_abs_vs_reference_cm":fnum(d["storage"]),
            }
            continue
        m=H_RE.match(line)
        if m: rows.setdefault(int(m.group("case")),{})["h"]=[float(x) for x in m.group("values").split()]
        m=T_RE.match(line)
        if m: rows.setdefault(int(m.group("case")),{})["theta"]=[float(x) for x in m.group("values").split()]
    if sorted(rows)!=list(range(1,37)):
        raise RuntimeError(f"{path}: expected cases 1..36")
    for c,r in rows.items():
        if len(r.get("h",[]))!=16 or len(r.get("theta",[]))!=16:
            raise RuntimeError(f"{path}: case {c} missing 16-node state")
    return rows

def same_float(a:float,b:float)->bool:
    if math.isnan(a) or math.isnan(b): return math.isnan(a) and math.isnan(b)
    return a==b

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--production",type=Path,required=True)
    ap.add_argument("--research",type=Path,required=True)
    ap.add_argument("--output",type=Path,required=True)
    args=ap.parse_args()
    p=parse(args.production); r=parse(args.research)
    records=[]; passed=True
    max_h=max_t=max_temp=max_mass=0.0
    for c in range(1,37):
        a=p[c]; b=r[c]
        identity_fields=("ise","material","forcing","classification","linear_solves","internal_retries","alternative_solver_calls","fallback")
        field_drift=[k for k in identity_fields if a[k]!=b[k]]
        dh=max(abs(x-y) for x,y in zip(a["h"],b["h"]))
        dt=max(abs(x-y) for x,y in zip(a["theta"],b["theta"]))
        dtemp=abs(a["temporal_indicator"]-b["temporal_indicator"])
        dmass=abs(a["mass_residual_cm"]-b["mass_residual_cm"])
        numeric_fields=("head_inf_vs_reference","head_rms_vs_reference","theta_inf_vs_reference","theta_rms_vs_reference","storage_abs_vs_reference_cm")
        numeric_drift=[k for k in numeric_fields if not same_float(a[k],b[k])]
        case_pass=not field_drift and not numeric_drift and dh==0.0 and dt==0.0 and dtemp==0.0 and dmass==0.0
        passed=passed and case_pass
        max_h=max(max_h,dh); max_t=max(max_t,dt); max_temp=max(max_temp,dtemp); max_mass=max(max_mass,dmass)
        records.append({"case":c,"pass":case_pass,"field_drift":field_drift,"numeric_field_drift":numeric_drift,
                        "head_inf_production_vs_research":dh,"theta_inf_production_vs_research":dt,
                        "temporal_indicator_abs_delta":dtemp,"mass_residual_abs_delta_cm":dmass})
    out={
        "schema":"swap5.f-ross20.production-research-identity.v1",
        "case_count":36,"all_cases_exact":passed,
        "max_head_inf":max_h,"max_theta_inf":max_t,
        "max_temporal_indicator_abs_delta":max_temp,"max_mass_residual_abs_delta_cm":max_mass,
        "records":records,"gate":"PASS" if passed else "FAIL"
    }
    args.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print(json.dumps(out,indent=2,sort_keys=True))
    print(f"F_ROSS20_PRODUCTION_RESEARCH_IDENTITY={out['gate']}")
    return 0 if passed else 2

if __name__=="__main__":
    raise SystemExit(main())
