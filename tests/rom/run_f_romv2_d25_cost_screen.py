#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib,statistics,subprocess,time

CANDIDATES=[1,2,4,8,16,32,64,128,256,512,1024]
PERMS=[
 ("FMC","R2","R16"),("FMC","R16","R2"),("R2","FMC","R16"),
 ("R2","R16","FMC"),("R16","FMC","R2"),("R16","R2","FMC")
]
N_CYCLES=5
WARMUPS=3

def run_one(exe,route,repeats):
    t0=time.perf_counter()
    cp=subprocess.run([exe,"bench",str(repeats)],check=True,text=True,capture_output=True)
    wall=time.perf_counter()-t0
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_ROMV2_D25_BENCH|")),None)
    if line is None: raise RuntimeError(f"missing benchmark line {route}: {cp.stdout[-1000:]}")
    f={}
    for p in line.split("|")[1:]:
        if "=" in p:
            k,v=p.split("=",1);f[k]=v
    if f.get("ROUTE")!=route: raise RuntimeError(f"route identity mismatch {route} {f}")
    if int(f["REPEATS"])!=repeats: raise RuntimeError("repeat identity mismatch")
    cpu=float(f["CPU_SECONDS"]);checksum=float(f["CHECKSUM"])
    if not(math.isfinite(cpu) and cpu>=0 and math.isfinite(checksum)): raise RuntimeError("nonfinite timing/checksum")
    return {"cpu_seconds":cpu,"wall_seconds":wall,"checksum":checksum}

def mean(xs): return sum(xs)/len(xs)
def sample_sd(xs):
    return statistics.stdev(xs) if len(xs)>1 else 0.0
def percentile(xs,p):
    s=sorted(xs)
    if not s:return None
    x=(len(s)-1)*p;lo=math.floor(x);hi=math.ceil(x)
    if lo==hi:return s[lo]
    return s[lo]*(hi-x)+s[hi]*(x-lo)

def route_stats(rows,route):
    cpu=[r["routes"][route]["cpu_seconds"]/r["repeats"] for r in rows]
    wall=[r["routes"][route]["wall_seconds"]/r["repeats"] for r in rows]
    return {
      "cpu_seconds_per_workload":{"mean":mean(cpu),"median":statistics.median(cpu),"p10":percentile(cpu,.10),"p90":percentile(cpu,.90),"sd":sample_sd(cpu)},
      "wall_seconds_per_workload":{"mean":mean(wall),"median":statistics.median(wall),"p10":percentile(wall,.10),"p90":percentile(wall,.90),"sd":sample_sd(wall)}
    }

def ratio_stats(rows,a,b,field="cpu_seconds"):
    vals=[r["routes"][a][field]/r["routes"][b][field] for r in rows]
    return {"mean":mean(vals),"median":statistics.median(vals),"p10":percentile(vals,.10),"p90":percentile(vals,.90),"sd":sample_sd(vals)}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--fmc",required=True);ap.add_argument("--r2",required=True);ap.add_argument("--r16",required=True)
    ap.add_argument("--equivalence",required=True);ap.add_argument("--output",required=True)
    a=ap.parse_args()
    eq=json.loads(pathlib.Path(a.equivalence).read_text())
    if eq["decision"]!="D25_COMPILED_FMC_IMPLEMENTATION_EQUIVALENCE_PASS" or not eq["timing_authorized"]:
        raise SystemExit("implementation equivalence does not authorize timing")
    exes={"FMC":a.fmc,"R2":a.r2,"R16":a.r16}

    # Stage 2: R16-only internal repetition calibration. No FMC/R2 timing is observed here.
    calibration=[]
    repeats=None
    previous=None
    for n in CANDIDATES:
        x=run_one(a.r16,"R16",n)
        calibration.append({"repeats":n,**x})
        if x["cpu_seconds"]>=0.5:
            if x["cpu_seconds"]<=8.0:
                repeats=n
            else:
                if previous is not None and previous["cpu_seconds"]>=0.25:
                    repeats=previous["repeats"]
            break
        previous={"repeats":n,**x}
    if repeats is None:
        out={"schema":"swap5.f-romv2-d25.cost-screen.v1","workstream":"F-ROM","work_unit":"F-ROMV2-D25",
             "decision":"FMC_SHARED_HOST_COST_ADVANTAGE_UNRESOLVED","reason":"R16_ONLY_BATCH_CALIBRATION_UNRESOLVED",
             "R16_only_calibration":calibration,"formal_performance_claim":False,"production_rom_authorized":False}
        pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
        print(json.dumps(out,sort_keys=True));return 0

    # Warmups are discarded but must retain deterministic checksums route-wise.
    checksum_ref={}
    warmups=[]
    for route in ("FMC","R2","R16"):
        for i in range(WARMUPS):
            x=run_one(exes[route],route,repeats)
            warmups.append({"route":route,"warmup":i+1,**x})
            if route not in checksum_ref: checksum_ref[route]=x["checksum"]
            elif x["checksum"]!=checksum_ref[route]: raise RuntimeError(f"warmup checksum drift {route}")

    rows=[];sample=0
    for cyc in range(N_CYCLES):
        for perm in PERMS:
            sample+=1
            rec={"sample":sample,"cycle":cyc+1,"order":list(perm),"repeats":repeats,"routes":{}}
            for route in perm:
                x=run_one(exes[route],route,repeats)
                if x["checksum"]!=checksum_ref[route]: raise RuntimeError(f"measured checksum drift {route} sample {sample}")
                rec["routes"][route]=x
            rows.append(rec)

    fmc_cpu=[r["routes"]["FMC"]["cpu_seconds"]/repeats for r in rows]
    r16_cpu=[r["routes"]["R16"]["cpu_seconds"]/repeats for r in rows]
    deltas=[a-b for a,b in zip(fmc_cpu,r16_cpu)]
    dmean=mean(deltas); dsd=sample_sd(deltas); se=dsd/math.sqrt(len(deltas)); upper=dmean+2*se
    fr=ratio_stats(rows,"FMC","R16")
    rr=ratio_stats(rows,"R2","R16")
    f2=ratio_stats(rows,"FMC","R2")
    if dmean<0 and upper<0 and fr["mean"]<1 and fr["median"]<1:
        decision="FMC_SHARED_HOST_COST_ADVANTAGE_RESOLVED_RELATIVE_TO_R16"
    elif fr["mean"]>=1 and fr["median"]>=1:
        decision="FMC_SHARED_HOST_NO_COST_ADVANTAGE_RELATIVE_TO_R16"
    else:
        decision="FMC_SHARED_HOST_COST_ADVANTAGE_UNRESOLVED"

    out={
      "schema":"swap5.f-romv2-d25.cost-screen.v1","workstream":"F-ROM","work_unit":"F-ROMV2-D25",
      "decision":decision,
      "screening_only":True,
      "formal_performance_claim":False,
      "host_admitted_for_cpu_baseline":False,
      "cpu_baseline_established":False,
      "internal_repetitions":repeats,
      "R16_only_calibration":calibration,
      "warmups_per_route":WARMUPS,
      "measured_samples_per_route":len(rows),
      "sample_order_protocol":"six permutations repeated five times",
      "route_stats":{r:route_stats(rows,r) for r in ("FMC","R2","R16")},
      "ratios":{
        "FMC_over_R16_cpu":fr,
        "R2_over_R16_cpu":rr,
        "FMC_over_R2_cpu":f2,
        "FMC_over_R16_wall":ratio_stats(rows,"FMC","R16","wall_seconds"),
        "R2_over_R16_wall":ratio_stats(rows,"R2","R16","wall_seconds")
      },
      "paired_FMC_minus_R16_cpu_seconds_per_workload":{
        "mean":dmean,"sd":dsd,"se":se,"upper_two_se_bound":upper,
        "resolved_negative":dmean<0 and upper<0
      },
      "scientific_checksums":checksum_ref,
      "samples":rows,
      "interpretation":"Shared-host compiled same-language screening only. No portable or formal speedup may be inferred.",
      "production_rom_authorized":False
    }
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({k:out[k] for k in ("decision","internal_repetitions","route_stats","ratios","paired_FMC_minus_R16_cpu_seconds_per_workload")},sort_keys=True))
    return 0

if __name__=="__main__": raise SystemExit(main())
