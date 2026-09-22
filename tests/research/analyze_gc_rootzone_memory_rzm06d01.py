#!/usr/bin/env python3
from __future__ import annotations

import argparse, json, math, pathlib, re, struct

EXPECTED_ARTIFACT_SHA256="2b04e188b7ce1593e073031fc43580550513e857dfb74b9993844a3230a1a67f"
EXPECTED_STATES=768
EXPECTED_DISCOVERY_STRICT=475
NODES=16
DZ_CM=10.0
Z_CM=[-5.0-10.0*i for i in range(NODES)]
W_TOL_CM=1.0e-4
M1_MIN_CM=1.0e-2

STATE_KEYS=("SPLIT","HISTORY","STEP","T","FALLBACK")
NODE_KEYS=("SPLIT","HISTORY","STEP","NODE","H","THETA")

def field(line: str, key: str) -> str:
    m=re.search(r"(?:^|\|)"+re.escape(key)+r"=([^|\r\n]*)", line)
    if not m:
        raise ValueError(f"missing {key}")
    return m.group(1)

def parse_state(line: str):
    return {k:field(line,k) for k in STATE_KEYS}

def parse_node(line: str):
    return {k:field(line,k) for k in NODE_KEYS}

def f64_bits(value: float) -> str:
    return struct.pack(">d",value).hex()

def reconstruct(node_rows):
    rows=sorted(node_rows,key=lambda r:int(r["NODE"]))
    if len(rows)!=NODES or [int(r["NODE"]) for r in rows] != list(range(1,NODES+1)):
        raise ValueError("node structure")
    h=[float(r["H"]) for r in rows]
    theta=[float(r["THETA"]) for r in rows]
    if not all(math.isfinite(x) for x in h+theta):
        raise ValueError("nonfinite node")
    w=sum(t*DZ_CM for t in theta)
    m1=sum(t*DZ_CM*z for t,z in zip(theta,Z_CM))/w
    root=sum(theta[i]*DZ_CM for i in range(3))
    return {"pressure_head_cm":h,"theta":theta,"W_profile_cm":w,
            "M1_cm":m1,"upper_30cm_water_cm":root}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True)
    ap.add_argument("--artifact-sha256",required=True)
    ap.add_argument("--output",required=True)
    args=ap.parse_args()

    if args.artifact_sha256.lower()!=EXPECTED_ARTIFACT_SHA256:
        raise SystemExit("artifact digest mismatch")

    states={}
    nodes={}
    all_state_count=0
    heldout_state_lines=0
    with open(args.input,"r",encoding="utf-8") as fh:
        for raw in fh:
            if raw.startswith("ROM1AR2_STATE|"):
                all_state_count += 1
                split=field(raw,"SPLIT")
                if split!="DISCOVERY":
                    heldout_state_lines += 1
                    continue
                s=parse_state(raw)
                key=(s["HISTORY"],int(s["STEP"]))
                states[key]=s
            elif raw.startswith("ROM1AR2_NODE|"):
                split=field(raw,"SPLIT")
                if split!="DISCOVERY":
                    continue
                n=parse_node(raw)
                key=(n["HISTORY"],int(n["STEP"]))
                nodes.setdefault(key,[]).append(n)

    if all_state_count!=EXPECTED_STATES:
        raise SystemExit(f"state count {all_state_count}")
    eligible=[]
    excluded_fallback=0
    for key,s in states.items():
        if s["FALLBACK"]!="F":
            excluded_fallback += 1
            continue
        if key not in nodes:
            raise SystemExit(f"missing nodes {key}")
        obs=reconstruct(nodes[key])
        t=float(s["T"])
        eligible.append({
            "history":s["HISTORY"],"step":int(s["STEP"]),
            "t_text":s["T"],"t_day":t,"t_bits":f64_bits(t),
            **obs
        })
    if len(eligible)!=EXPECTED_DISCOVERY_STRICT:
        raise SystemExit(f"strict discovery count {len(eligible)}")

    eligible.sort(key=lambda x:(x["history"],x["step"]))
    candidate_count=0
    water_match_count=0
    qualifying=[]
    best_water_matched=None
    best_same_time=None

    for i,a in enumerate(eligible):
        for b in eligible[i+1:]:
            if a["history"]==b["history"]:
                continue
            if a["t_text"]!=b["t_text"] or a["t_bits"]!=b["t_bits"]:
                continue
            candidate_count += 1
            dw=abs(b["W_profile_cm"]-a["W_profile_cm"])
            dm=abs(b["M1_cm"]-a["M1_cm"])
            rec={
                "A":(a["history"],a["step"]),
                "B":(b["history"],b["step"]),
                "t_text":a["t_text"],
                "abs_delta_W_profile_cm":dw,
                "abs_delta_M1_cm":dm,
            }
            if best_same_time is None or (dm,-dw)> (best_same_time["abs_delta_M1_cm"],-best_same_time["abs_delta_W_profile_cm"]):
                best_same_time=rec
            if dw<=W_TOL_CM:
                water_match_count += 1
                if best_water_matched is None or (dm,-dw,tuple(rec["A"]+rec["B"])) > (
                    best_water_matched["abs_delta_M1_cm"],-best_water_matched["abs_delta_W_profile_cm"],
                    tuple(best_water_matched["A"]+best_water_matched["B"])):
                    best_water_matched=rec
                if dm>=M1_MIN_CM:
                    qualifying.append((rec,a,b))

    qualifying.sort(key=lambda x:(-x[0]["abs_delta_M1_cm"],x[0]["abs_delta_W_profile_cm"],
                                  x[1]["history"],x[1]["step"],x[2]["history"],x[2]["step"]))
    selected=None
    if qualifying:
        rec,a,b=qualifying[0]
        selected={
            **rec,
            "A_origin":a,
            "B_origin":b,
        }
        disposition="PAIR_SELECTED"
    else:
        disposition="NO_MATCH"

    evidence={
        "schema":"swap5.gc_rootzone_memory.rzm06d01.rom_library_h2_origin_selection.v1",
        "preregistration_commit":"2af534f0455ceb121f9a7965d1fe9f92895b3e4d",
        "production_changes":False,
        "artifact_authority":{
            "workflow_run":35379176697,
            "artifact_id":10561841507,
            "artifact_sha256":args.artifact_sha256.lower(),
            "input_member":"o2.txt",
        },
        "firewall":{
            "all_state_lines_seen":all_state_count,
            "heldout_state_lines_excluded_before_metadata_parse":heldout_state_lines,
            "discovery_state_records":len(states),
            "strict_discovery_states":len(eligible),
            "fallback_discovery_states_excluded":excluded_fallback,
            "forbidden_response_fields_used":False,
        },
        "geometry":{"nodes":NODES,"dz_cm":DZ_CM,"z_cm":Z_CM},
        "frozen_gate":{
            "max_abs_profile_water_difference_cm":W_TOL_CM,
            "min_abs_distribution_moment_difference_cm":M1_MIN_CM,
            "same_time_required":True,
            "different_history_required":True,
        },
        "census":{
            "eligible_same_time_different_history_pair_count":candidate_count,
            "water_matched_pair_count":water_match_count,
            "qualifying_pair_count":len(qualifying),
            "best_same_time_pair_by_M1":best_same_time,
            "best_water_matched_pair_by_M1":best_water_matched,
        },
        "selected_pair":selected,
        "disposition":disposition,
        "nonclaims":[
            "D01 does not inspect or probe E_c.",
            "D01 does not use held-out or fallback states for selection.",
            "NO_MATCH is not an H2 falsification; it is a library-origin selection result."
        ],
    }
    pathlib.Path(args.output).write_text(json.dumps(evidence,indent=2,sort_keys=True)+"\n")
    print("RZM06D01_EXPERIMENT_JSON",json.dumps(evidence,sort_keys=True,separators=(",",":")))
    print("GC_RZM06D01_RESPONSE_BLIND_ORIGIN_SELECTION=PASS")
    return 0

if __name__=="__main__":
    raise SystemExit(main())
