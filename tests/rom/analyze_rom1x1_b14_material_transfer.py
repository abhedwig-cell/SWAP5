#!/usr/bin/env python3
from __future__ import annotations
import argparse, collections, hashlib, json, math, pathlib

EPS=1.6414144244913942e-6
HIST={f"D{i:02d}" for i in range(1,9)}|{f"H{i:02d}" for i in range(1,5)}

def fields(s):
    out={}
    for part in s.split("|"):
        if "=" in part:
            k,v=part.split("=",1); out[k]=v
    return out

def as_bool(v):
    return str(v).strip().upper() in {"T","TRUE",".TRUE.","1"}

def linf(a,b):
    return max(abs(x-y) for x,y in zip(a,b))

def candidate_norm(a,b):
    d=0.0
    for i in range(7):
        ma=0.5*(a[2*i]+a[2*i+1])
        mb=0.5*(b[2*i]+b[2*i+1])
        d=max(d,abs(ma-mb))
    d=max(d,abs(a[14]-b[14]),abs(a[15]-b[15]))
    return d

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True)
    ap.add_argument("--repeat",required=True)
    ap.add_argument("--prereg",required=True)
    ap.add_argument("--output",required=True)
    args=ap.parse_args()

    raw=pathlib.Path(args.input).read_text()
    repeat=pathlib.Path(args.repeat).read_text()
    prereg=json.loads(pathlib.Path(args.prereg).read_text())
    repeat_identity=raw==repeat

    states=[]; nodes=[]; histories=[]; fallbacks=[]; summary={}
    current_history=None; current_step=0
    for line in raw.splitlines():
        if "ROM1X1_STATE|" in line:
            r=fields(line.split("ROM1X1_STATE|",1)[1]); states.append(r)
            current_history=r["HISTORY"]; current_step=int(r["STEP"])
        elif "ROM1X1_NODE|" in line:
            nodes.append(fields(line.split("ROM1X1_NODE|",1)[1]))
        elif "ROM1X1_HISTORY_PASS|" in line:
            histories.append(fields(line.split("ROM1X1_HISTORY_PASS|",1)[1]))
        elif "ROM1X1_FALLBACK|" in line:
            r=fields(line.split("ROM1X1_FALLBACK|",1)[1])
            r["_history_context"]=current_history
            r["_step_context"]=current_step+1
            fallbacks.append(r)
        elif line.startswith("ROM1X1_") and "=" in line and "|" not in line:
            k,v=line.split("=",1); summary[k]=v.strip()

    by_hist=collections.defaultdict(list)
    for s in states: by_hist[s.get("HISTORY","")].append(s)
    state_structure=(len(states)==768 and set(by_hist)==HIST and all(len(by_hist[h])==64 for h in HIST))
    history_structure=(len(histories)==12 and {h.get("HISTORY") for h in histories}==HIST)
    node_map=collections.defaultdict(dict)
    for n in nodes:
        node_map[(n["HISTORY"],int(n["STEP"]))][int(n["NODE"])]=(float(n["H"]),float(n["THETA"]))
    expected={(h,s) for h in HIST for s in range(1,65)}
    node_structure=(set(node_map)==expected and all(set(node_map[k])==set(range(1,17)) for k in expected))
    finite_nodes=all(math.isfinite(v) for row in node_map.values() for pair in row.values() for v in pair)
    max_mass=max((abs(float(s["MASS"])) for s in states),default=math.inf)

    progression=True
    for h,rows in by_hist.items():
        for i,r in enumerate(sorted(rows,key=lambda z:int(z["STEP"])),1):
            progression &= int(r["STEP"])==i and int(r["REV"])==2+i

    fallback_ok=True; total_only=0; local=0; classes=collections.Counter()
    for f in fallbacks:
        cls=f["CLASS"]; classes[cls]+=1
        bal=int(f["BAL_FLAGS"]); head=int(f["HEAD_FLAGS"])
        rmax=float(f["RMAX"]); rsum=float(f["RSUM"])
        rep=float(f["REP_BOUND_CM"]); total_int=float(f["ABS_TOTAL_RESIDUAL_CM"])
        local_int=float(f["LOCAL_INTEGRATED_CM"])
        cp=float(f["FALLBACK_CP_TOL"]); tot=float(f["FALLBACK_TOTAL_TOL"])
        t0=float(f["HISTORY_STEP_T0"]); t1=float(f["T1"]); dt=t1-t0
        common=(head==0 and rep>0.0 and total_int<=rep and tot>=1e-12)
        if cls=="RETRY_TOTAL_ONLY":
            ok=common and bal==0 and rmax<=1e-12 and abs(rsum)>1e-12 and cp==1e-12
            total_only+=1
        elif cls=="RETRY_LOCAL_BALANCE":
            expected_cp=max(1e-12,1.6e-15/dt)
            cp_ok=abs(cp-expected_cp)<=4.0*math.ulp(expected_cp)
            ok=common and bal>0 and local_int<=1.6e-15 and cp_ok
            local+=1
        else:
            ok=False
        fallback_ok &= ok

    state_fallback_count=sum(1 for s in states if as_bool(s["FALLBACK"]))
    summary_ok=(
      summary.get("ROM1X1_HISTORY_COUNT")=="12" and
      summary.get("ROM1X1_STATE_COUNT")=="768" and
      summary.get("ROM1X1_B14_MATERIAL_TRANSFER_GENERATED")=="TRUE" and
      summary.get("ROM1X1_EXECUTION_COMPLETE")=="PASS"
    )
    reference_qualified=all([
      repeat_identity,state_structure,history_structure,node_structure,finite_nodes,
      progression,max_mass<=1e-12,fallback_ok,state_fallback_count==len(fallbacks),summary_ok
    ])

    profiles={k:[node_map[k][i][1] for i in range(1,17)] for k in expected}
    keys=sorted(expected)
    pair_count=0; relevant=0; collisions=[]; min_q=math.inf; min_margin=math.inf; max_full=0.0
    if reference_qualified:
        for ia,ka in enumerate(keys):
            for kb in keys[ia+1:]:
                if ka[0]==kb[0]: continue
                pair_count+=1
                a=profiles[ka]; b=profiles[kb]
                full=linf(a,b); max_full=max(max_full,full)
                if full<=EPS: continue
                relevant+=1
                q=candidate_norm(a,b)
                min_q=min(min_q,q); min_margin=min(min_margin,q-EPS)
                if q<=EPS:
                    collisions.append({
                      "a":{"history":ka[0],"step":ka[1]},
                      "b":{"history":kb[0],"step":kb[1]},
                      "candidate_induced_theta_linf":q,
                      "full_theta_linf":full,
                      "hidden_excess_over_theta_floor":full-EPS
                    })
    collisions.sort(key=lambda r:(r["candidate_induced_theta_linf"],-r["full_theta_linf"],
                                  r["a"]["history"],r["a"]["step"],r["b"]["history"],r["b"]["step"]))
    collision_count=len(collisions)

    if not reference_qualified:
        decision="ROM1X1_B14_REFERENCE_LIBRARY_UNRESOLVED"
    elif collision_count==0:
        decision="ROM1X1_B14_MATERIAL_TRANSFER_STATE_SEPARATION_QUALIFIED"
    else:
        decision="ROM1X1_B14_MATERIAL_TRANSFER_STATE_SEPARATION_NO_GO"

    evidence_complete=(len(states)==768 and len(nodes)==768*16 and pair_count in (0,270336))
    result={
      "schema":"swap5.rom1x1.result.v1","workstream":"F-ROM","work_unit":"ROM-1X1",
      "decision":decision,"repeat_stdout_bitwise_identity":repeat_identity,
      "material":"B14","theta_floor":EPS,
      "reference_library":{
        "qualified":reference_qualified,"state_count":len(states),"node_record_count":len(nodes),
        "history_count":len(histories),"fallback_count":len(fallbacks),
        "total_only_fallback_count":total_only,"local_balance_fallback_count":local,
        "fallback_classes":dict(classes),"fallback_semantics_pass":fallback_ok,
        "state_fallback_count":state_fallback_count,
        "max_abs_step_mass_residual_cm":max_mass
      },
      "frozen_coordinate":{"id":"Z8_PLUS_G8","dimension":9,"material_adapted":False},
      "state_separation":{
        "cross_history_pair_count":pair_count,
        "expected_cross_history_pair_count":270336,
        "full_theta_distinguishable_pair_count":relevant,
        "collision_count":collision_count,
        "collision_manifest":collisions[:8],
        "minimum_candidate_induced_theta_linf_over_full_distinguishable_pairs":min_q,
        "minimum_separation_margin_over_theta_floor":min_margin,
        "maximum_full_theta_linf":max_full
      },
      "raw_library_sha256":hashlib.sha256(raw.encode()).hexdigest(),
      "history_or_forcing_retuned":False,"coordinate_retuned":False,"theta_floor_retuned":False,
      "closure_model_fit":False,"production_rom_authorized":False
    }
    pathlib.Path(args.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps(result,sort_keys=True))
    return 0 if evidence_complete else 2

if __name__=="__main__":
    raise SystemExit(main())
