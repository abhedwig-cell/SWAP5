#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib,statistics,subprocess,time

CANDIDATES=[1,2,4,8,16,32,64,128]
WARMUPS=2
ROUNDS=20

def mean(x): return sum(x)/len(x)
def sd(x): return statistics.stdev(x) if len(x)>1 else 0.0
def pct(x,p):
    s=sorted(x);z=(len(s)-1)*p;lo=math.floor(z);hi=math.ceil(z)
    return s[lo] if lo==hi else s[lo]*(hi-z)+s[hi]*(z-lo)

def parse_bench(stdout,expected,repeats):
    prefixes=("LAYER_ROM_COST1_BENCH|","LARE_BC2_C4T_BENCH|")
    line=next((x for x in stdout.splitlines() if x.startswith(prefixes)),None)
    if line is None: raise RuntimeError(f"missing bench record for {expected}: {stdout[-1000:]}")
    f={}
    for p in line.split("|")[1:]:
        if "=" in p:
            k,v=p.split("=",1);f[k]=v
    if f.get("ROUTE")!=expected: raise RuntimeError(f"route identity {f.get('ROUTE')} != {expected}")
    if int(f["REPEATS"])!=repeats: raise RuntimeError("repeat identity")
    cpu=float(f["CPU_SECONDS"]);checksum=float(f["CHECKSUM"])
    if not math.isfinite(cpu) or cpu<0 or not math.isfinite(checksum): raise RuntimeError("invalid timing/checksum")
    return cpu,checksum

def run_one(route,spec,repeats):
    cmd=[str(x).replace("{repeats}",str(repeats)) for x in spec["command"]]
    t0=time.perf_counter()
    cp=subprocess.run(cmd,check=True,text=True,capture_output=True)
    wall=time.perf_counter()-t0
    cpu,checksum=parse_bench(cp.stdout,spec["emitted_route"],repeats)
    return {"cpu_seconds":cpu,"wall_seconds":wall,"checksum":checksum}

def route_stats(rows,route,repeats):
    cpu=[r["routes"][route]["cpu_seconds"]/repeats for r in rows]
    wall=[r["routes"][route]["wall_seconds"]/repeats for r in rows]
    return {
      "cpu_seconds_per_workload":{"mean":mean(cpu),"median":statistics.median(cpu),"p10":pct(cpu,.1),"p90":pct(cpu,.9),"sample_sd":sd(cpu)},
      "wall_seconds_per_workload":{"mean":mean(wall),"median":statistics.median(wall),"p10":pct(wall,.1),"p90":pct(wall,.9),"sample_sd":sd(wall)}
    }

def pair_stats(rows,a,b,repeats):
    ds=[(r["routes"][a]["cpu_seconds"]-r["routes"][b]["cpu_seconds"])/repeats for r in rows]
    m=mean(ds);s=sd(ds);se=s/math.sqrt(len(ds));lo=m-2*se;hi=m+2*se
    status="A_RESOLVED_CHEAPER" if hi<0 else "A_RESOLVED_MORE_EXPENSIVE" if lo>0 else "UNRESOLVED"
    return {"mean_A_minus_B_seconds":m,"sd":s,"se":se,"lower_two_se":lo,"upper_two_se":hi,"status":status}

def order_for_round(base,idx):
    n=len(base)
    if idx<n:
        source=base;k=idx
    else:
        source=list(reversed(base));k=idx-n
    return source[k:]+source[:k]

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--routes-json",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    spec=json.loads(a.routes_json.read_text())
    base=spec["base_order"];routes=spec["routes"]
    if len(base)!=10 or len(set(base))!=10 or set(base)!=set(routes): raise SystemExit("COST1 route-set drift")
    if base[-1]!="R16": raise SystemExit("R16 calibration route/order drift")

    calibration=[];repeats=None;previous=None;calibration_mode=None
    for n in CANDIDATES:
        x=run_one("R16",routes["R16"],n)
        calibration.append({"repeats":n,**x})
        if x["cpu_seconds"]>=0.3:
            if x["cpu_seconds"]<=4.0:
                repeats=n;calibration_mode="TARGET_WINDOW"
            elif previous is not None and previous["cpu_seconds"]>=0.15:
                repeats=previous["repeats"];calibration_mode="PREVIOUS_BELOW_MAX"
            elif n==1:
                # The frozen complete four-history workload is indivisible.  If
                # one atomic R16 workload already exceeds the operational
                # calibration window, preserve that workload and time with
                # repeats=1 rather than changing the scientific workload.
                repeats=1;calibration_mode="ATOMIC_WORKLOAD_OVER_TARGET"
            break
        previous={"repeats":n,**x}
    if repeats is None:
        out={"schema":"swap5.layer-rom.cost1.timing.v1","decision":"COST1_TIMING_CALIBRATION_UNRESOLVED",
             "R16_only_calibration":calibration,"screening_only":True,"formal_performance_claim":False}
        a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n");print(json.dumps(out,sort_keys=True));return

    checksums={};warmups=[]
    for route in base:
        for i in range(WARMUPS):
            x=run_one(route,routes[route],repeats);warmups.append({"route":route,"warmup":i+1,**x})
            if route not in checksums: checksums[route]=x["checksum"]
            elif x["checksum"]!=checksums[route]: raise RuntimeError(f"warmup checksum drift {route}")

    rows=[]
    for idx in range(ROUNDS):
        order=order_for_round(base,idx)
        rec={"round":idx+1,"order":order,"repeats":repeats,"routes":{}}
        for route in order:
            x=run_one(route,routes[route],repeats)
            if x["checksum"]!=checksums[route]: raise RuntimeError(f"checksum drift {route} round {idx+1}")
            rec["routes"][route]=x
        rows.append(rec)

    positions={r:[0]*len(base) for r in base}
    for row in rows:
        for pos,r in enumerate(row["order"]): positions[r][pos]+=1
    if any(any(v!=2 for v in counts) for counts in positions.values()): raise RuntimeError("position balance failure")

    pairs={aa:{bb:pair_stats(rows,aa,bb,repeats) for bb in base if bb!=aa} for aa in base}
    stats={r:route_stats(rows,r,repeats) for r in base}
    means={r:stats[r]["cpu_seconds_per_workload"]["mean"] for r in base}
    ratios={}
    for dim in (4,6,8):
        ratios[str(dim)]={
          "BASE_over_R16":means[f"LR{dim}_BASE"]/means["R16"],
          "FINE_over_R16":means[f"LR{dim}_FINE"]/means["R16"],
          "BASE_over_CoRichards":means[f"LR{dim}_BASE"]/means[f"COR{dim}"],
          "FINE_over_CoRichards":means[f"LR{dim}_FINE"]/means[f"COR{dim}"],
          "FINE_over_BASE":means[f"LR{dim}_FINE"]/means[f"LR{dim}_BASE"],
          "BASE_resolved_cheaper_than_R16":pairs[f"LR{dim}_BASE"]["R16"]["status"]=="A_RESOLVED_CHEAPER",
          "FINE_resolved_cheaper_than_R16":pairs[f"LR{dim}_FINE"]["R16"]["status"]=="A_RESOLVED_CHEAPER",
          "BASE_resolved_cheaper_than_CoRichards":pairs[f"LR{dim}_BASE"][f"COR{dim}"]["status"]=="A_RESOLVED_CHEAPER",
          "FINE_resolved_cheaper_than_CoRichards":pairs[f"LR{dim}_FINE"][f"COR{dim}"]["status"]=="A_RESOLVED_CHEAPER"
        }

    out={
      "schema":"swap5.layer-rom.cost1.timing.v1","workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-COST1",
      "decision":"COST1_MATERIAL_SHARED_HOST_TIMING_COMPLETE","screening_only":True,
      "formal_performance_claim":False,"host_admitted_for_cpu_baseline":False,
      "internal_repetitions":repeats,"calibration_mode":calibration_mode,"R16_only_calibration":calibration,
      "warmups_per_route":WARMUPS,"measured_rounds":ROUNDS,
      "position_counts":positions,"scientific_checksums":checksums,
      "route_stats":stats,"pairwise_cpu":pairs,"cost_ratios":ratios,"samples":rows,
      "speed_claim_authorized":False,"production_rom_authorized":False
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":out["decision"],"internal_repetitions":repeats,
      "cpu_means":means,"cost_ratios":ratios},sort_keys=True))
if __name__=="__main__":
    raise SystemExit(main())
