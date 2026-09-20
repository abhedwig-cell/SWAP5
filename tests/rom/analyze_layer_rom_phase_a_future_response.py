#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
from collections import defaultdict

HISTORY_INDEX={"F00":1,"F01":2,"F02":3,"H00":4,"H01":5,"H02":6}
PROBES=("P_FX_ZERO","P_FX_OPPOSED","P_HD_WETTER","P_HD_DRIER","P_HD_SWITCH","P_TOP_SWITCH")
HORIZONS=(8,64,256)
NODES=16
DZ=10.0
HARD_MASS_GATE=1.0e-12


def fields(line: str) -> dict[str,str]:
    out={}
    for part in line.rstrip().split("|")[1:]:
        if "=" in part:
            k,v=part.split("=",1); out[k]=v
    return out


def parse_pair(key: str):
    a,b=key.split("|")
    ah,ast=a.split(":"); bh,bst=b.split(":")
    return (ah,int(ast)),(bh,int(bst))


def zsum(profile, lo, hi):
    return sum(profile[lo:hi])*DZ


def sign(x: float) -> int:
    return 1 if x>0.0 else (-1 if x<0.0 else 0)


def reversals(values):
    out=[]; previous=0
    for step,value in enumerate(values,1):
        current=sign(value)
        if current and previous and current!=previous:
            out.append(step)
        if current:
            previous=current
    return out


def maxabs(rows,key):
    return max((abs(float(r[key])) for r in rows),default=0.0)


def main() -> int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True,type=pathlib.Path)
    ap.add_argument("--repeat",required=True,type=pathlib.Path)
    ap.add_argument("--base-reference",required=True,type=pathlib.Path)
    ap.add_argument("--authority",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    raw=args.input.read_bytes()
    if raw!=args.repeat.read_bytes():
        raise SystemExit("future-response O0/O2 stdout drift")
    authority=json.loads(args.authority.read_text())
    prereg=json.loads(args.prereg.read_text())
    if authority["decision"]!="INDEPENDENT_STATE_INFORMATION_SCREEN_AND_PAIR_FREEZE_QUALIFIED":
        raise SystemExit("wrong state authority")
    if prereg["phase"]!="PREREGISTERED_BEFORE_INDEPENDENT_REFERENCE_RESULT_EXPOSURE":
        raise SystemExit("wrong response preregistration")
    if tuple(prereg["common_future_probe_bank"]["horizons_steps"])!=HORIZONS:
        raise SystemExit("future horizon drift")

    expected_starts=set()
    for keys in authority["pair_freeze"]["representation_pairs"].values():
        for key in keys:
            a,b=parse_pair(key); expected_starts.add(a); expected_starts.add(b)
    if len(expected_starts)!=30:
        raise SystemExit("frozen start count drift")

    base_nodes=defaultdict(lambda:[None]*NODES)
    for line in args.base_reference.open(errors="replace"):
        if line.startswith("LAYERR1_NODE|"):
            r=fields(line)
            key=(r["HISTORY"],int(r["STEP"]))
            base_nodes[key][int(r["NODE"])-1]=(float(r["H"]),float(r["THETA"]))

    start_nodes=defaultdict(lambda:[None]*NODES)
    steps=defaultdict(dict)
    endpoints={}
    endpoint_nodes=defaultdict(lambda:[None]*NODES)
    max_mass=0.0
    fallback_count=0
    completion=False
    unique_start_marker=None

    for line in args.input.open(errors="replace"):
        if line.startswith("LAYERR2_START_NODE|"):
            r=fields(line); key=(r["HISTORY"],int(r["STEP"]))
            start_nodes[key][int(r["NODE"])-1]=(float(r["H"]),float(r["THETA"]))
        elif line.startswith("LAYERR2_STEP|"):
            r=fields(line)
            key=(r["HISTORY"],int(r["START_STEP"]),r["PROBE"])
            step=int(r["STEP"])
            row={
                "bottom_flux":float(r["BOTTOM_FLUX"]),
                "cum_bottom":float(r["CUM_BOTTOM_OUTWARD_EXCHANGE"]),
                "mass":float(r["MASS"]),
                "fallback":r["FALLBACK"].strip().upper() in ("T","TRUE",".TRUE."),
            }
            steps[key][step]=row
            max_mass=max(max_mass,abs(row["mass"]))
            fallback_count += int(row["fallback"])
        elif line.startswith("LAYERR2_PROBE|"):
            r=fields(line)
            key=(r["HISTORY"],int(r["START_STEP"]),r["PROBE"],int(r["HORIZON_STEP"]))
            endpoints[key]={
                "d_total":float(r["D_TOTAL_STORAGE"]),
                "cum_bottom":float(r["CUM_BOTTOM_OUTWARD_EXCHANGE"]),
                "terminal_bottom_flux":float(r["TERMINAL_BOTTOM_FLUX"]),
                "max_abs_mass":float(r["MAX_ABS_MASS"]),
            }
        elif line.startswith("LAYERR2_PROBE_NODE|"):
            r=fields(line)
            key=(r["HISTORY"],int(r["START_STEP"]),r["PROBE"],int(r["HORIZON_STEP"]))
            endpoint_nodes[key][int(r["NODE"])-1]=(float(r["H"]),float(r["THETA"]))
        elif line.startswith("LAYERR2_UNIQUE_START_COUNT="):
            unique_start_marker=int(line.strip().split("=",1)[1])
        elif line.strip()=="LAYERR2_EXECUTION_COMPLETE=PASS":
            completion=True

    if set(start_nodes)!=expected_starts:
        raise SystemExit("future start identity set mismatch")
    if unique_start_marker!=len(expected_starts):
        raise SystemExit("future unique start marker mismatch")
    if not completion:
        raise SystemExit("future completion marker missing")
    if max_mass>HARD_MASS_GATE:
        raise SystemExit("future hard mass gate failed")

    start_identity_failures=[]
    start_theta={}
    for key in sorted(expected_starts):
        got=start_nodes[key]; expected=base_nodes.get(key)
        if expected is None or any(v is None for v in got) or any(v is None for v in expected):
            start_identity_failures.append({"state":f"{key[0]}:{key[1]}","reason":"missing profile"})
            continue
        if got!=expected:
            start_identity_failures.append({"state":f"{key[0]}:{key[1]}","reason":"profile mismatch"})
        start_theta[key]=[v[1] for v in got]
    if start_identity_failures:
        raise SystemExit("future reconstructed start differs from qualified base Reference")

    expected_step_keys={(h,s,p) for h,s in expected_starts for p in PROBES}
    if set(steps)!=expected_step_keys or any(set(v)!={*range(1,257)} for v in steps.values()):
        raise SystemExit("future step coverage mismatch")
    expected_endpoints={(h,s,p,z) for h,s in expected_starts for p in PROBES for z in HORIZONS}
    if set(endpoints)!=expected_endpoints or set(endpoint_nodes)!=expected_endpoints:
        raise SystemExit("future endpoint coverage mismatch")
    if any(any(v is None for v in endpoint_nodes[k]) for k in expected_endpoints):
        raise SystemExit("future endpoint profile incomplete")

    representation_results={}
    detail=[]
    for rid,pair_keys in authority["pair_freeze"]["representation_pairs"].items():
        rows=[]
        rev_rows=[]
        for pair_index,pair_key in enumerate(pair_keys,1):
            a,b=parse_pair(pair_key)
            for probe in PROBES:
                qa=[steps[(a[0],a[1],probe)][i]["bottom_flux"] for i in range(1,257)]
                qb=[steps[(b[0],b[1],probe)][i]["bottom_flux"] for i in range(1,257)]
                ra,rb=reversals(qa),reversals(qb)
                same=len(ra)==len(rb)
                delta=max((abs(x-y) for x,y in zip(ra,rb)),default=0) if same else None
                rev_rows.append({
                    "pair":pair_key,"probe":probe,
                    "a_reversals":ra,"b_reversals":rb,
                    "sequence_match":same,
                    "max_step_delta_when_match":delta,
                })
                for horizon in HORIZONS:
                    ea=endpoints[(a[0],a[1],probe,horizon)]
                    eb=endpoints[(b[0],b[1],probe,horizon)]
                    pa=[x[1] for x in endpoint_nodes[(a[0],a[1],probe,horizon)]]
                    pb=[x[1] for x in endpoint_nodes[(b[0],b[1],probe,horizon)]]
                    sa,sb=start_theta[a],start_theta[b]
                    da=[x-y for x,y in zip(pa,sa)]
                    db=[x-y for x,y in zip(pb,sb)]
                    row={
                        "representation":rid,
                        "pair_index":pair_index,
                        "pair":pair_key,
                        "probe":probe,
                        "horizon_step":horizon,
                        "cum_bottom":ea["cum_bottom"]-eb["cum_bottom"],
                        "d_total":ea["d_total"]-eb["d_total"],
                        "d_zone_0_40":(zsum(pa,0,4)-zsum(sa,0,4))-(zsum(pb,0,4)-zsum(sb,0,4)),
                        "d_zone_40_120":(zsum(pa,4,12)-zsum(sa,4,12))-(zsum(pb,4,12)-zsum(sb,4,12)),
                        "d_zone_120_160":(zsum(pa,12,16)-zsum(sa,12,16))-(zsum(pb,12,16)-zsum(sb,12,16)),
                        "terminal_bottom_flux":ea["terminal_bottom_flux"]-eb["terminal_bottom_flux"],
                        "terminal_sign_mismatch":sign(ea["terminal_bottom_flux"])!=sign(eb["terminal_bottom_flux"]),
                        "response_theta_linf":max(abs(x-y) for x,y in zip(da,db)),
                        "endpoint_theta_linf":max(abs(x-y) for x,y in zip(pa,pb)),
                    }
                    rows.append(row); detail.append(row)
        representation_results[rid]={
            "pair_count":len(pair_keys),
            "pair_set_sha256":hashlib.sha256("\n".join(pair_keys).encode()).hexdigest(),
            "metrics":{
                "max_abs_cumulative_bottom_exchange_difference_cm":maxabs(rows,"cum_bottom"),
                "max_abs_total_storage_response_difference_cm":maxabs(rows,"d_total"),
                "max_abs_zone_0_40_response_difference_cm":maxabs(rows,"d_zone_0_40"),
                "max_abs_zone_40_120_response_difference_cm":maxabs(rows,"d_zone_40_120"),
                "max_abs_zone_120_160_response_difference_cm":maxabs(rows,"d_zone_120_160"),
                "max_abs_terminal_bottom_flux_difference_cm_per_day":maxabs(rows,"terminal_bottom_flux"),
                "terminal_bottom_flux_sign_mismatch_count":sum(int(r["terminal_sign_mismatch"]) for r in rows),
                "max_response_theta_linf":max((r["response_theta_linf"] for r in rows),default=0.0),
                "max_endpoint_theta_linf":max((r["endpoint_theta_linf"] for r in rows),default=0.0),
                "reversal_sequence_mismatch_count":sum(int(not r["sequence_match"]) for r in rev_rows),
                "max_reversal_step_difference_when_sequence_matches":max(
                    (int(r["max_step_delta_when_match"]) for r in rev_rows if r["max_step_delta_when_match"] is not None),
                    default=0
                ),
            },
            "reversal_details":rev_rows,
        }

    smart=("L2","L3","L4","L6")
    smart_pair_sets_identical=len({
        representation_results[x]["pair_set_sha256"] for x in smart
    })==1
    smart_metric_vectors_identical=all(
        representation_results[x]["metrics"]==representation_results["L2"]["metrics"]
        for x in smart[1:]
    )

    result={
        "schema":"swap5.layer-rom.phase-a.future-response-result.v1",
        "workstream":"F-ROM-LAYER",
        "work_unit":"LAYER-ROM-PHASE-A-STATE2",
        "decision":"INDEPENDENT_FUTURE_RESPONSE_AMBIGUITY_MAPPED",
        "evidence_complete":True,
        "input":{
            "future_stdout_sha256":hashlib.sha256(raw).hexdigest(),
            "repeat_stdout_bitwise_identity":True,
            "base_reference_stdout_sha256":hashlib.sha256(args.base_reference.read_bytes()).hexdigest(),
            "unique_start_count":len(expected_starts),
            "probe_count":len(PROBES),
            "horizons_steps":list(HORIZONS),
            "step_record_count":sum(len(x) for x in steps.values()),
            "endpoint_record_count":len(endpoints),
            "endpoint_node_record_count":len(endpoint_nodes)*NODES,
            "max_abs_transaction_mass_residual_cm":max_mass,
            "fallback_step_count":fallback_count,
            "start_state_bitwise_numeric_identity_with_base_reference":True,
        },
        "representations":representation_results,
        "smart_pair_sets_identical":smart_pair_sets_identical,
        "smart_metric_vectors_identical":smart_metric_vectors_identical,
        "scientific_interpretation":{
            "state_information_test":"Reference future responses only; no Layer-ROM closure or reduced propagation executed.",
            "smart_pair_caveat":"The frozen L2-L6 smart pair set is identical and its selected state distances equal the fine-profile L-infinity distances. These are proximity challenges, not evidence of hidden profile information loss.",
            "uniform_control_role":"Uniform controls contain genuine reduction-induced state compression and therefore test whether omitted vertical information can become future-response-relevant.",
            "dimension_inference":"Identical L2-L6 future metrics cannot by themselves prove two-layer sufficiency because identical physical pair sets make the response experiment non-discriminating across those four representations.",
            "application_acceptance":"NOT_ADJUDICATED"
        },
        "detail":detail,
        "closure_executed":False,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":result["decision"],
        "max_mass":max_mass,
        "fallback_step_count":fallback_count,
        "smart_pair_sets_identical":smart_pair_sets_identical,
        "smart_metric_vectors_identical":smart_metric_vectors_identical,
        "metrics":{k:v["metrics"] for k,v in representation_results.items()},
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
