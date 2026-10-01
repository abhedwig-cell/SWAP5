#!/usr/bin/env python3
import json,math,statistics,subprocess,sys,time

exe=sys.argv[1]
workloads=["EQUILIBRIUM","MILD_DYNAMIC"]
variants=["LEGACY","MANAGER"]

def run_case(variant,workload,emit=True):
    t0=time.perf_counter()
    cp=subprocess.run([exe,variant,workload],text=True,capture_output=True)
    wall=time.perf_counter()-t0
    if emit:
        print(cp.stdout,end="")
    if cp.returncode:
        if emit: print(cp.stderr,file=sys.stderr)
        return {"execution_invalid":True,"wall":wall,"stdout":cp.stdout,"stderr":cp.stderr}
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_MIQUAL07_RESULT|")),None)
    hv=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_MIQUAL07_H=")),None)
    tv=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_MIQUAL07_TH=")),None)
    if not line or not hv or not tv:
        return {"execution_invalid":True,"wall":wall,"stdout":cp.stdout,"stderr":"missing result vector"}
    d={k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
    row={
      "variant":variant,"workload":workload,"wall":wall,
      "complete":int(d["COMPLETE"])==1,"last_accepted":int(d["LAST_ACCEPTED"]),"fail_reason":d["FAIL_REASON"],
      "cpu":float(d["CPU"]),"attempts":int(d["ATTEMPTS"]),"retries":int(d["RETRIES"]),
      "nl":int(d["NL"]),"jac":int(d["JAC"]),"lin":int(d["LIN"]),"back":int(d["BACK"]),
      "work":int(d["WORK"]),"reduced":int(d["REDUCED"]),"fallback":int(d["FALLBACK"]),"bypass":int(d["BYPASS"]),
      "max_mass":float(d["MAX_MASS"]),"storage":float(d["STORAGE"]),"pond":float(d["POND"]),
      "tail":int(d["TAIL"]),"last_reason":d["LAST_REASON"],
      "h":[float(x) for x in hv.split("=",1)[1].split(",")],
      "theta":[float(x) for x in tv.split("=",1)[1].split(",")],
    }
    return row

def compare(a,b):
    return {
      "max_hdiff":max(abs(x-y) for x,y in zip(a["h"],b["h"])),
      "max_tdiff":max(abs(x-y) for x,y in zip(a["theta"],b["theta"])),
      "storage_diff":abs(a["storage"]-b["storage"]),
      "tail_diff":abs(a["tail"]-b["tail"]),
    }

pre={}
execution_invalid=False
for w in workloads:
    for v in variants:
        r=run_case(v,w)
        pre[(w,v)]=r
        if r.get("execution_invalid"): execution_invalid=True

if execution_invalid:
    out={"aggregate":"MIQUAL07_EXECUTION_INVALID","preflight":list(pre.values())}
    print("F_PE_MIQUAL07_SUMMARY="+json.dumps(out,separators=(",",":"),sort_keys=True))
    print("F_PE_MIQUAL07_GATE=PASS")
    raise SystemExit

dynamic_blocked=not pre[("MILD_DYNAMIC","LEGACY")]["complete"]
physical_fail=False
route_fail=False
precomp={}
for w in workloads:
    L=pre[(w,"LEGACY")]; M=pre[(w,"MANAGER")]
    cmp=compare(L,M); precomp[w]=cmp
    for r in (L,M):
        if not r["complete"] or r["last_accepted"]!=4000 or r["max_mass"]>1e-8:
            physical_fail=True
    if cmp["max_hdiff"]>5e-3 or cmp["max_tdiff"]>5e-6 or cmp["storage_diff"]>1e-5 or cmp["tail_diff"]>1:
        physical_fail=True
    if M["reduced"]/4000.0<0.95 or (M["fallback"]+M["bypass"])/4000.0>0.05:
        route_fail=True

if dynamic_blocked:
    agg="MIQUAL07_DYNAMIC_REFERENCE_BLOCKED"
elif physical_fail:
    agg="MIQUAL07_PHYSICAL_MISMATCH"
elif route_fail:
    agg="MIQUAL07_MANAGER_ROUTE_FAILURE"
else:
    # one untimed warmup per workload and variant
    for w in workloads:
        for v in variants:
            r=run_case(v,w,emit=False)
            if r.get("execution_invalid") or not r["complete"]:
                execution_invalid=True
    pairs={w:[] for w in workloads}
    if not execution_invalid:
        for w in workloads:
            for p in range(1,8):
                order=["LEGACY","MANAGER"] if p%2 else ["MANAGER","LEGACY"]
                rr={}
                for v in order:
                    rr[v]=run_case(v,w,emit=False)
                if any(x.get("execution_invalid") or not x["complete"] for x in rr.values()):
                    execution_invalid=True
                    break
                cmp=compare(rr["LEGACY"],rr["MANAGER"])
                if cmp["max_hdiff"]>5e-3 or cmp["max_tdiff"]>5e-6 or cmp["storage_diff"]>1e-5 or cmp["tail_diff"]>1:
                    physical_fail=True
                    break
                pairs[w].append({
                  "pair":p,
                  "legacy_wall":rr["LEGACY"]["wall"],"manager_wall":rr["MANAGER"]["wall"],
                  "wall_ratio":rr["MANAGER"]["wall"]/rr["LEGACY"]["wall"],
                  "legacy_cpu":rr["LEGACY"]["cpu"],"manager_cpu":rr["MANAGER"]["cpu"],
                  "cpu_ratio":rr["MANAGER"]["cpu"]/rr["LEGACY"]["cpu"],
                  "legacy_work":rr["LEGACY"]["work"],"manager_work":rr["MANAGER"]["work"],
                  "work_ratio":rr["MANAGER"]["work"]/rr["LEGACY"]["work"],
                  "manager_reduced":rr["MANAGER"]["reduced"],
                  "manager_fallback":rr["MANAGER"]["fallback"],
                  "manager_bypass":rr["MANAGER"]["bypass"],
                })
            if execution_invalid or physical_fail: break

    if execution_invalid:
        agg="MIQUAL07_EXECUTION_INVALID"
    elif physical_fail:
        agg="MIQUAL07_PHYSICAL_MISMATCH"
    else:
        stats={}
        for w in workloads:
            ps=pairs[w]
            stats[w]={
              "median_wall_ratio":statistics.median(x["wall_ratio"] for x in ps),
              "geomean_wall_ratio":math.exp(sum(math.log(x["wall_ratio"]) for x in ps)/len(ps)),
              "median_cpu_ratio":statistics.median(x["cpu_ratio"] for x in ps),
              "geomean_work_ratio":math.exp(sum(math.log(x["work_ratio"]) for x in ps)/len(ps)),
              "wall_ratios":[x["wall_ratio"] for x in ps],
            }
        overall_median_geom=math.sqrt(stats["EQUILIBRIUM"]["median_wall_ratio"]*stats["MILD_DYNAMIC"]["median_wall_ratio"])
        overall_work_geom=math.sqrt(stats["EQUILIBRIUM"]["geomean_work_ratio"]*stats["MILD_DYNAMIC"]["geomean_work_ratio"])
        wall_ok=(overall_median_geom<0.99 and
                 all(stats[w]["median_wall_ratio"]<=1.03 for w in workloads) and
                 any(stats[w]["median_wall_ratio"]<0.98 for w in workloads))
        work_ok=overall_work_geom<0.90
        agg="QUALIFIED_MIQUAL07_PRODUCTION_RUNTIME_PERFORMANCE_CANDIDATE" if wall_ok and work_ok else "MIQUAL07_PERFORMANCE_NOT_READY"

out={"aggregate":agg,
     "preflight":[pre[(w,v)] for w in workloads for v in variants],
     "preflight_comparison":precomp}
if 'pairs' in locals():
    out["pairs"]=pairs
if 'stats' in locals():
    out["stats"]=stats
    out["overall_median_wall_geomean"]=overall_median_geom
    out["overall_work_geomean"]=overall_work_geom
print("F_PE_MIQUAL07_SUMMARY="+json.dumps(out,separators=(",",":"),sort_keys=True))
print("F_PE_MIQUAL07_GATE=PASS")
