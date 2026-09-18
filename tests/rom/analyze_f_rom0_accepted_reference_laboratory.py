#!/usr/bin/env python3
"""Adjudicate preregistered ROM-0 accepted trajectories and numerical floors."""

from __future__ import annotations
import argparse, json, math
from pathlib import Path

def scalar(v:str):
    s=v.strip()
    if s in ("T","true","True"): return True
    if s in ("F","false","False"): return False
    try:
        if any(c in s for c in ".EeDd"):
            return float(s.replace("D","E").replace("d","e"))
        return int(s)
    except ValueError:
        return s

def record(line:str):
    parts=line.strip().split("|")
    d={"record":parts[0]}
    for p in parts[1:]:
        if "=" in p:
            k,v=p.split("=",1)
            d[k]=scalar(v)
    return d

def parse_case(path:Path):
    header=None; accepted=[]; nodes=[]; passed=None
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("F_ROM0_CASE|"): header=record(line)
        elif line.startswith("F_ROM0_ACCEPTED|"): accepted.append(record(line))
        elif line.startswith("F_ROM0_NODE|"): nodes.append(record(line))
        elif line.startswith("F_ROM0_CASE_PASS|"): passed=record(line)
    if header is None or passed is None or not accepted:
        raise SystemExit(f"incomplete successful case {path.name}")
    n=int(header["N"])
    expected=int(header["INTERVALS"])
    if len(accepted)!=expected:
        raise SystemExit(f"{path.name}: accepted count {len(accepted)} != {expected}")
    if len(nodes)!=expected*n:
        raise SystemExit(f"{path.name}: node observation count {len(nodes)} != {expected*n}")
    revs=[int(r["REV"]) for r in accepted]
    if revs!=list(range(1,expected+1)):
        raise SystemExit(f"{path.name}: revision sequence is not one commit per observation")
    if any(abs(float(r["MASS_RES"]))>1e-12 for r in accepted):
        raise SystemExit(f"{path.name}: hard mass residual exceeded")
    return {"path":path.name,"header":header,"accepted":accepted,"nodes":nodes,"pass":passed}

def key(case):
    h=case["header"]
    return (str(h["MATERIAL"]),str(h["EXPERIMENT"]),int(h["N"]),float(h["DZ_CM"]),float(h["DT_DAY"]))

def at_times(case):
    return {round(float(r["T"]),12):r for r in case["accepted"]}

def floor_compare(a,b,label):
    aa=at_times(a); bb=at_times(b)
    times=sorted(set(aa)&set(bb))
    if not times:
        raise SystemExit(f"{label}: no common times")
    fields=["S_TOTAL","S_UPPER","S_LOWER","TERMINAL_QBOT"]
    maxima={f:0.0 for f in fields}
    cumulative_a=0.0; cumulative_b=0.0
    cumdiff=0.0
    # Build cumulative bottom exchange independently and sample at common times.
    cumb_a={}
    for r in a["accepted"]:
        cumulative_a += float(r["BOTTOM_EXCHANGE"])
        cumb_a[round(float(r["T"]),12)]=cumulative_a
    cumb_b={}
    for r in b["accepted"]:
        cumulative_b += float(r["BOTTOM_EXCHANGE"])
        cumb_b[round(float(r["T"]),12)]=cumulative_b
    for t in times:
        for f in fields:
            maxima[f]=max(maxima[f],abs(float(aa[t][f])-float(bb[t][f])))
        cumdiff=max(cumdiff,abs(cumb_a[t]-cumb_b[t]))
    return {
        "label":label,
        "common_observation_count":len(times),
        "max_abs_difference":{
            "total_storage_cm":maxima["S_TOTAL"],
            "upper_0_40_storage_cm":maxima["S_UPPER"],
            "lower_40_160_storage_cm":maxima["S_LOWER"],
            "terminal_bottom_flux_cm_per_day":maxima["TERMINAL_QBOT"],
            "cumulative_bottom_outward_exchange_cm":cumdiff,
        },
    }

def case_summary(c):
    acc=c["accepted"]
    return {
        "file":c["path"],
        "material":c["header"]["MATERIAL"],
        "experiment":c["header"]["EXPERIMENT"],
        "nodes":c["header"]["N"],
        "dz_cm":c["header"]["DZ_CM"],
        "dt_day":c["header"]["DT_DAY"],
        "accepted_intervals":len(acc),
        "final_revision":c["pass"]["FINAL_REV"],
        "final_time_day":c["pass"]["FINAL_T"],
        "max_abs_mass_residual_cm":max(abs(float(x["MASS_RES"])) for x in acc),
        "total_attempts":sum(int(x["ATTEMPTS"]) for x in acc),
        "total_retries":sum(int(x["RETRIES"]) for x in acc),
        "total_rollbacks":sum(int(x["ROLLBACKS"]) for x in acc),
        "solver_rejections":sum(int(x["SOLVER_REJ"]) for x in acc),
        "temporal_rejections":sum(int(x["TEMP_REJ"]) for x in acc),
        "mass_rejections":sum(int(x["MASS_REJ"]) for x in acc),
        "cumulative_top_exchange_cm":sum(float(x["TOP_EXCHANGE"]) for x in acc),
        "cumulative_bottom_outward_exchange_cm":sum(float(x["BOTTOM_EXCHANGE"]) for x in acc),
        "final_terminal_qbot_cm_per_day":float(acc[-1]["TERMINAL_QBOT"]),
        "final_total_storage_cm":float(acc[-1]["S_TOTAL"]),
        "final_upper_0_40_storage_cm":float(acc[-1]["S_UPPER"]),
        "final_lower_40_160_storage_cm":float(acc[-1]["S_LOWER"]),
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--cases",required=True)
    ap.add_argument("--prereg",required=True)
    ap.add_argument("--output",required=True)
    args=ap.parse_args()
    prereg=json.loads(Path(args.prereg).read_text())
    cases=[parse_case(p) for p in sorted(Path(args.cases).glob("*.txt"))]
    by={key(c):c for c in cases}
    if len(by)!=18:
        raise SystemExit(f"expected 18 unique preregistered cases, got {len(by)}")

    floors=[]
    for mat in ("B01","B14"):
        for exp in ("E1_NOMINAL_FLUX","E2_DRYING_FLUX"):
            a=by[(mat,exp,16,10.0,0.0016)]
            b=by[(mat,exp,16,10.0,0.0008)]
            floors.append(floor_compare(a,b,f"{mat}:{exp}:dt_0.0016_vs_0.0008"))
    floors.append(floor_compare(
        by[("B01","E1_NOMINAL_FLUX",16,10.0,0.0016)],
        by[("B01","E1_NOMINAL_FLUX",32,5.0,0.0016)],
        "B01:E1_NOMINAL_FLUX:16x10_vs_32x5"))
    floors.append(floor_compare(
        by[("B14","E2_DRYING_FLUX",16,10.0,0.0016)],
        by[("B14","E2_DRYING_FLUX",32,5.0,0.0016)],
        "B14:E2_DRYING_FLUX:16x10_vs_32x5"))

    direction={}
    bidirectional=True
    for mat in ("B01","B14"):
        rise=by[(mat,"E3_BOTTOM_HEAD_RISE",16,10.0,0.0016)]["accepted"][-1]
        fall=by[(mat,"E4_BOTTOM_HEAD_FALL",16,10.0,0.0016)]["accepted"][-1]
        qr=float(rise["TERMINAL_QBOT"]); qf=float(fall["TERMINAL_QBOT"])
        ok=(qr>0.0 and qf<0.0)
        direction[mat]={"rise_final_qbot":qr,"fall_final_qbot":qf,"opposite_expected_directions":ok}
        bidirectional &= ok

    finite_floor=all(
        all(math.isfinite(float(v)) for v in x["max_abs_difference"].values())
        for x in floors
    )
    result={
        "schema":"swap5.f-rom0.accepted-reference-result.v1",
        "workstream":"F-ROM",
        "work_unit":"ROM-0",
        "preregistration":args.prereg,
        "case_count":len(cases),
        "all_preregistered_cases_committed":True,
        "exact_replay_required_by_runner":True,
        "production_or_reference_mutation":False,
        "cases":[case_summary(c) for c in cases],
        "bidirectional_reachability":direction,
        "bidirectional_reachability_pass":bidirectional,
        "reference_floor_measurements":floors,
        "reference_floor_finite":finite_floor,
        "threshold_adjudication":"MEASURE_ONLY_NO_ROM_THRESHOLD_SET",
        "rom1_state_claim":"NONE",
        "decision":"PROCEED_TO_ROM1A" if bidirectional and finite_floor else "EXPAND_ACCEPTED_TRAJECTORY_DOMAIN",
    }
    Path(args.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    if not bidirectional:
        raise SystemExit("ROM-0 bidirectional reachability gate failed under frozen probes")
    if not finite_floor:
        raise SystemExit("ROM-0 numerical floor contained non-finite result")
    print("F_ROM0_REFERENCE_FLOOR_MEASURED=PASS")
    print("F_ROM0_BIDIRECTIONAL_REACHABILITY=PASS")
    print("F_ROM0_DECISION=PROCEED_TO_ROM1A")

if __name__=="__main__":
    main()