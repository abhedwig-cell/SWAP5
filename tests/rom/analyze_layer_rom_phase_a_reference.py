#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
from collections import defaultdict

EXPECTED = ("F00","F01","F02","H00","H01","H02")
NSTEPS = 1024
NODES = 16
DZ_CM = 10.0
HARD_MASS_GATE_CM = 1.0e-12


def fields(line: str) -> dict[str,str]:
    out={}
    for part in line.split("|")[1:]:
        if "=" in part:
            k,v=part.split("=",1); out[k]=v
    return out


def sign(x: float) -> int:
    return 1 if x>0.0 else (-1 if x<0.0 else 0)


def main() -> int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True,type=pathlib.Path)
    ap.add_argument("--repeat",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    prereg=json.loads(args.prereg.read_text())
    if prereg["phase"]!="PREREGISTERED_BEFORE_FIRST_INDEPENDENT_REFERENCE_EXECUTION":
        raise SystemExit("wrong Layer-ROM Reference preregistration phase")
    if args.input.read_bytes()!=args.repeat.read_bytes():
        raise SystemExit("O0/O2 Reference stdout drift")

    states={}
    nodes=defaultdict(lambda:[None]*NODES)
    fallbacks=0
    for line in args.input.open(errors="replace"):
        if line.startswith("LAYERR1_STATE|"):
            r=fields(line)
            key=(r["HISTORY"],int(r["STEP"]))
            states[key]={
                "split":r["SPLIT"].strip(),
                "bottom_mode":int(r["BOTTOM_MODE"]),
                "total":float(r["TOTAL_STORAGE"]),
                "bottom_exchange":float(r["BOTTOM_OUTWARD_EXCHANGE"]),
                "bottom_flux":float(r["BOTTOM_FLUX"]),
                "mass":float(r["MASS"]),
                "fallback":r["FALLBACK"].strip().upper() in ("T","TRUE",".TRUE."),
            }
            fallbacks += int(states[key]["fallback"])
        elif line.startswith("LAYERR1_NODE|"):
            r=fields(line)
            key=(r["HISTORY"],int(r["STEP"]))
            nodes[key][int(r["NODE"])-1]={
                "h":float(r["H"]),
                "theta":float(r["THETA"]),
            }

    expected={(h,s) for h in EXPECTED for s in range(1,NSTEPS+1)}
    if set(states)!=expected or set(nodes)!=expected:
        raise SystemExit("incomplete Layer-ROM Reference library")
    if any(any(v is None for v in nodes[k]) for k in expected):
        raise SystemExit("incomplete Layer-ROM node profiles")

    max_mass=max(abs(states[k]["mass"]) for k in expected)
    if max_mass>HARD_MASS_GATE_CM:
        raise SystemExit("Layer-ROM Reference hard mass gate failed")

    theta_vals=[v["theta"] for k in expected for v in nodes[k]]
    h_vals=[v["h"] for k in expected for v in nodes[k]]
    histories={}
    for h in EXPECTED:
        seq=[states[(h,s)] for s in range(1,NSTEPS+1)]
        modes=sorted({row["bottom_mode"] for row in seq})
        expected_mode=2 if h.startswith("F") else 5
        if modes != [expected_mode]:
            raise SystemExit(f"bottom mode drift for {h}: {modes}")
        rev=[]
        prev=0
        for step,row in enumerate(seq,1):
            cur=sign(row["bottom_flux"])
            if cur and prev and cur!=prev:
                rev.append(step)
            if cur:
                prev=cur
        z0_40=[]; z40_120=[]; z120_160=[]
        for s in range(1,NSTEPS+1):
            profile=[v["theta"] for v in nodes[(h,s)]]
            z0_40.append(sum(profile[0:4])*DZ_CM)
            z40_120.append(sum(profile[4:12])*DZ_CM)
            z120_160.append(sum(profile[12:16])*DZ_CM)
        histories[h]={
            "regime":"FLUX_LAB" if h.startswith("F") else "HEAD_LAB",
            "bottom_mode":expected_mode,
            "bottom_flux_range_cm_per_day":[min(r["bottom_flux"] for r in seq),max(r["bottom_flux"] for r in seq)],
            "total_storage_range_cm":[min(r["total"] for r in seq),max(r["total"] for r in seq)],
            "zone_0_40_storage_range_cm":[min(z0_40),max(z0_40)],
            "zone_40_120_storage_range_cm":[min(z40_120),max(z40_120)],
            "zone_120_160_storage_range_cm":[min(z120_160),max(z120_160)],
            "bottom_flux_reversal_steps":rev,
            "fallback_count":sum(int(r["fallback"]) for r in seq),
        }

    result={
        "schema":"swap5.layer-rom.phase-a.reference-result.v1",
        "workstream":"F-ROM-LAYER",
        "work_unit":"LAYER-ROM-PHASE-A-REF1",
        "decision":"INDEPENDENT_REFERENCE_LIBRARY_QUALIFIED",
        "input":{
            "stdout_sha256":hashlib.sha256(args.input.read_bytes()).hexdigest(),
            "repeat_stdout_bitwise_identity":True,
            "state_count":len(states),
            "node_record_count":len(nodes)*NODES,
        },
        "integrity":{
            "hard_mass_gate_cm":HARD_MASS_GATE_CM,
            "max_abs_transaction_mass_residual_cm":max_mass,
            "fallback_count":fallbacks,
            "theta_range":[min(theta_vals),max(theta_vals)],
            "pressure_head_range_cm":[min(h_vals),max(h_vals)],
        },
        "histories":histories,
        "scientific_disposition":{
            "reference_reachability":"QUALIFIED",
            "representation_sufficiency":"NOT_YET_ADJUDICATED",
            "future_response_sufficiency":"NOT_YET_ADJUDICATED",
            "closure_sufficiency":"NOT_EXECUTED",
            "application_acceptance":"NOT_ADJUDICATED",
        },
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":result["decision"],
        "max_mass":max_mass,
        "fallback_count":fallbacks,
        "histories":{h:{"reversals":histories[h]["bottom_flux_reversal_steps"],"q_range":histories[h]["bottom_flux_range_cm_per_day"]} for h in EXPECTED},
    },sort_keys=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
