#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib,statistics,subprocess,time

CANDIDATES=[1,2,4,8,16,32,64,128,256,512,1024]
WARMUPS=3
ROUNDS=30

def mean(x):return sum(x)/len(x)
def sd(x):return statistics.stdev(x) if len(x)>1 else 0.0
def pct(x,p):
    s=sorted(x);z=(len(s)-1)*p;lo=math.floor(z);hi=math.ceil(z)
    return s[lo] if lo==hi else s[lo]*(hi-z)+s[hi]*(z-lo)

def run_one(route,template,repeats):
    cmd=[str(x).replace("{repeats}",str(repeats)) for x in template]
    t0=time.perf_counter()
    cp=subprocess.run(cmd,check=True,text=True,capture_output=True)
    wall=time.perf_counter()-t0
    line=next((x for x in cp.stdout.splitlines() if x.startswith("LARE_BC2_C4T_BENCH|")),None)
    if line is None:raise RuntimeError(f"missing C4T bench line {route}: {cp.stdout[-1200:]}")
    f={}
    for p in line.split("|")[1:]:
        if "=" in p:
            k,v=p.split("=",1);f[k]=v
    if f.get("ROUTE")!=route:raise RuntimeError(f"route identity {route} != {f.get('ROUTE')}")
    if int(f["REPEATS"])!=repeats:raise RuntimeError("repeat identity")
    cpu=float(f["CPU_SECONDS"]);checksum=float(f["CHECKSUM"])
    if not(math.isfinite(cpu) and cpu>=0.0 and math.isfinite(checksum)):raise RuntimeError("nonfinite timing")
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
    source=base if idx<15 else list(reversed(base))
    k=idx if idx<15 else idx-15
    return source[k:]+source[:k]

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--routes-json",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    spec=json.loads(a.routes_json.read_text())
    base=spec["base_order"];cmds=spec["commands"]
    if len(base)!=15 or set(base)!=set(cmds):raise SystemExit("C4T route-set mismatch")
    if base[-1]!="R16":raise SystemExit("C4T frozen base order drift")

    calibration=[];repeats=None;previous=None
    for n in CANDIDATES:
        x=run_one("R16",cmds["R16"],n)
        calibration.append({"repeats":n,**x})
        if x["cpu_seconds"]>=0.5:
            if x["cpu_seconds"]<=8.0:repeats=n
            elif previous is not None and previous["cpu_seconds"]>=0.25:repeats=previous["repeats"]
            break
        previous={"repeats":n,**x}
    if repeats is None:
        out={"schema":"swap5.lare.bc2.c4t.timing.v1","decision":"C4T_TIMING_CALIBRATION_UNRESOLVED",
             "R16_only_calibration":calibration,"formal_performance_claim":False}
        a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n");print(json.dumps(out,sort_keys=True));return

    checksum={}
    warmups=[]
    for route in base:
        for i in range(WARMUPS):
            x=run_one(route,cmds[route],repeats)
            warmups.append({"route":route,"warmup":i+1,**x})
            if route not in checksum:checksum[route]=x["checksum"]
            elif x["checksum"]!=checksum[route]:raise RuntimeError(f"warmup checksum drift {route}")

    rows=[]
    for idx in range(ROUNDS):
        order=order_for_round(base,idx)
        rec={"round":idx+1,"order":order,"repeats":repeats,"routes":{}}
        for route in order:
            x=run_one(route,cmds[route],repeats)
            if x["checksum"]!=checksum[route]:raise RuntimeError(f"checksum drift {route} round {idx+1}")
            rec["routes"][route]=x
        rows.append(rec)

    # Verify exact position balance before adjudication.
    positions={r:[0]*len(base) for r in base}
    for row in rows:
        for pos,r in enumerate(row["order"]):positions[r][pos]+=1
    if any(any(v!=2 for v in counts) for counts in positions.values()):
        raise RuntimeError("position balance failure")

    pairs={}
    for aa in base:
        pairs[aa]={}
        for bb in base:
            if aa==bb:continue
            pairs[aa][bb]=pair_stats(rows,aa,bb,repeats)

    out={
      "schema":"swap5.lare.bc2.c4t.timing.v1","workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C4T",
      "decision":"C4T_SHARED_HOST_TIMING_COMPLETE","screening_only":True,
      "formal_performance_claim":False,"host_admitted_for_cpu_baseline":False,"cpu_baseline_established":False,
      "internal_repetitions":repeats,"R16_only_calibration":calibration,
      "warmups_per_route":WARMUPS,"measured_rounds":ROUNDS,
      "order_protocol":"15 cyclic rotations of frozen base plus 15 cyclic rotations of reversed base",
      "position_counts":positions,"scientific_checksums":checksum,
      "route_stats":{r:route_stats(rows,r,repeats) for r in base},
      "pairwise_cpu":pairs,"samples":rows,
      "speed_claim_authorized":False,"production_rom_authorized":False
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":out["decision"],"internal_repetitions":repeats,
                      "cpu_means":{r:out["route_stats"][r]["cpu_seconds_per_workload"]["mean"] for r in base},
                      "vs_R16":{r:pairs[r]["R16"] for r in base if r!="R16"}},sort_keys=True))
if __name__=="__main__":main()
