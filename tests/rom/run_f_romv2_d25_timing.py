#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, math, pathlib, re, statistics, subprocess, time

CANDIDATES=[1,2,4,8,16,32,64,128,256,512,1024]
PERMS=[
 ("FMC","R2","R16"),
 ("FMC","R16","R2"),
 ("R2","FMC","R16"),
 ("R2","R16","FMC"),
 ("R16","FMC","R2"),
 ("R16","R2","FMC"),
]
WARMUPS=3
CYCLES=5
CHECKSUM_TOL=1e-9

def fields(line):
    out={}
    for p in line.split("|"):
        if "=" in p:
            k,v=p.split("=",1); out[k]=v
    return out

def parse_fmc_validate(path):
    for line in pathlib.Path(path).read_text().splitlines():
        if line.startswith("F_ROMV2_D25_FMC_VALIDATE_COMPLETE=PASS"):
            f=fields(line)
            return float(f["CHECKSUM"])
    raise RuntimeError("missing FMC validation checksum")

def parse_reference_terms(path):
    final={}
    for line in pathlib.Path(path).read_text().splitlines():
        if line.startswith("F_ROMV2_D24_REF_STATE|"):
            f=fields(line)
            if int(f["STEP"])==16:
                final[f["HISTORY"]]=(
                    float(f["TOTAL_STORAGE"])+float(f["SURFACE_STORE_CM"])+float(f["CUM_RUNOFF_CM"])+
                    float(f["BOTTOM_OUTWARD_EXCHANGE"])+float(f["BOTTOM_FLUX"])
                )
    if set(final)!= {"RG05","RG20","RG40"}:
        raise RuntimeError(f"reference final state mismatch {path}: {sorted(final)}")
    return [final[h] for h in ("RG05","RG20","RG40")]

def expected_checksum(route,repeats,fmc_single,ref_terms):
    x=0.0
    if route=="FMC":
        for _ in range(repeats): x += fmc_single
    else:
        terms=ref_terms[route]
        for _ in range(repeats):
            for v in terms: x += v
    return x

def run_bench(exe,repeats,route):
    t0=time.perf_counter()
    p=subprocess.run([exe,"bench",str(repeats)],text=True,capture_output=True,check=True)
    elapsed=time.perf_counter()-t0
    rows=[line for line in p.stdout.splitlines() if line.startswith("F_ROMV2_D25_BENCH|")]
    if len(rows)!=1:
        raise RuntimeError(f"{route} benchmark record count {len(rows)}")
    f=fields(rows[0])
    if f.get("ROUTE")!=route:
        raise RuntimeError(f"route label mismatch expected={route} got={f.get('ROUTE')}")
    if int(f["REPEATS"])!=repeats:
        raise RuntimeError("repeat label mismatch")
    return {"route":route,"repeats":repeats,"cpu_seconds":float(f["CPU_SECONDS"]),
            "checksum":float(f["CHECKSUM"]),"elapsed_seconds":elapsed}

def quantile(vals,p):
    s=sorted(vals)
    if len(s)==1:return s[0]
    x=p*(len(s)-1); lo=math.floor(x); hi=math.ceil(x)
    if lo==hi:return s[lo]
    return s[lo]+(s[hi]-s[lo])*(x-lo)

def stats(vals):
    return {"n":len(vals),"mean":statistics.fmean(vals),"median":statistics.median(vals),
            "p10":quantile(vals,.10),"p90":quantile(vals,.90),"min":min(vals),"max":max(vals)}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--fmc",required=True); ap.add_argument("--r2",required=True); ap.add_argument("--r16",required=True)
    ap.add_argument("--fmc-validate",required=True); ap.add_argument("--r2-validate",required=True); ap.add_argument("--r16-validate",required=True)
    ap.add_argument("--calibration-output",required=True); ap.add_argument("--output",required=True)
    a=ap.parse_args()
    exes={"FMC":a.fmc,"R2":a.r2,"R16":a.r16}
    fmc_single=parse_fmc_validate(a.fmc_validate)
    ref_terms={"R2":parse_reference_terms(a.r2_validate),"R16":parse_reference_terms(a.r16_validate)}

    calibration=[]
    repeats=None
    previous=None
    for n in CANDIDATES:
        row=run_bench(a.r16,n,"R16"); calibration.append(row)
        if row["cpu_seconds"]>=0.5:
            if row["cpu_seconds"]<=8.0:
                repeats=n
            elif previous is not None and previous["cpu_seconds"]>=0.25:
                repeats=previous["repeats"]
            break
        previous=row
    cal_decision="D25_R16_ONLY_TIMING_CALIBRATION_PASS" if repeats is not None else "D25_R16_ONLY_TIMING_CALIBRATION_UNRESOLVED"
    cal={"schema":"swap5.f-romv2-d25.timing-calibration.v1","decision":cal_decision,
         "route_used":"R16_ONLY","candidates":calibration,"selected_repetitions":repeats,
         "FMC_R2_timing_exposed_during_calibration":False}
    pathlib.Path(a.calibration_output).write_text(json.dumps(cal,indent=2,sort_keys=True)+"\n")
    if repeats is None:
        out={"schema":"swap5.f-romv2-d25.cost-screen.v1","decision":"FMC_SHARED_HOST_COST_ADVANTAGE_UNRESOLVED",
             "reason":"R16_ONLY_TIMING_CALIBRATION_UNRESOLVED","calibration":cal,"formal_performance_claim":False,
             "production_rom_authorized":False}
        pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
        print(json.dumps(out,sort_keys=True)); return 0

    expected={
      "FMC":expected_checksum("FMC",repeats,fmc_single,ref_terms),
      "R2":expected_checksum("R2",repeats,fmc_single,ref_terms),
      "R16":expected_checksum("R16",repeats,fmc_single,ref_terms),
    }
    warmups=[]
    for route in ("FMC","R2","R16"):
        for i in range(WARMUPS):
            row=run_bench(exes[route],repeats,route)
            row["warmup_index"]=i+1
            if abs(row["checksum"]-expected[route])>CHECKSUM_TOL:
                raise RuntimeError(f"{route} warmup checksum drift got={row['checksum']} expected={expected[route]}")
            warmups.append(row)

    samples=[]; triads=[]
    triad_index=0
    for cyc in range(CYCLES):
        for perm_index,perm in enumerate(PERMS,1):
            triad_index+=1; triad={}
            for order_index,route in enumerate(perm,1):
                row=run_bench(exes[route],repeats,route)
                row.update({"cycle":cyc+1,"permutation_index":perm_index,"triad":triad_index,"order_index":order_index})
                if abs(row["checksum"]-expected[route])>CHECKSUM_TOL:
                    raise RuntimeError(f"{route} sample checksum drift got={row['checksum']} expected={expected[route]}")
                samples.append(row); triad[route]=row
            triads.append(triad)

    route_cpu={r:[x["cpu_seconds"] for x in samples if x["route"]==r] for r in exes}
    route_elapsed={r:[x["elapsed_seconds"] for x in samples if x["route"]==r] for r in exes}
    cpu_stats={r:stats(v) for r,v in route_cpu.items()}
    elapsed_stats={r:stats(v) for r,v in route_elapsed.items()}
    deltas=[t["FMC"]["cpu_seconds"]-t["R16"]["cpu_seconds"] for t in triads]
    dmean=statistics.fmean(deltas)
    dsd=statistics.stdev(deltas) if len(deltas)>1 else 0.0
    dse=dsd/math.sqrt(len(deltas))
    upper=dmean+2*dse
    mean_ratio=cpu_stats["FMC"]["mean"]/cpu_stats["R16"]["mean"]
    median_ratio=cpu_stats["FMC"]["median"]/cpu_stats["R16"]["median"]
    mean_sign=mean_ratio<1.0; median_sign=median_ratio<1.0
    if dmean<0.0 and upper<0.0 and mean_sign and median_sign:
        decision="FMC_SHARED_HOST_COST_ADVANTAGE_RESOLVED_RELATIVE_TO_R16"
    elif mean_ratio>=1.0 and median_ratio>=1.0:
        decision="FMC_SHARED_HOST_NO_COST_ADVANTAGE_RELATIVE_TO_R16"
    else:
        decision="FMC_SHARED_HOST_COST_ADVANTAGE_UNRESOLVED"

    ratios={
      "FMC_over_R16_mean":mean_ratio,
      "FMC_over_R16_median":median_ratio,
      "R2_over_R16_mean":cpu_stats["R2"]["mean"]/cpu_stats["R16"]["mean"],
      "R2_over_R16_median":cpu_stats["R2"]["median"]/cpu_stats["R16"]["median"],
      "FMC_over_R2_mean":cpu_stats["FMC"]["mean"]/cpu_stats["R2"]["mean"],
      "FMC_over_R2_median":cpu_stats["FMC"]["median"]/cpu_stats["R2"]["median"],
    }
    out={"schema":"swap5.f-romv2-d25.cost-screen.v1","workstream":"F-ROM","work_unit":"F-ROMV2-D25",
         "decision":decision,"host_classification":"SHARED_GITHUB_RUNNER_SCREENING_ONLY",
         "selected_repetitions":repeats,"warmups":warmups,"samples":samples,
         "cpu_seconds":cpu_stats,"elapsed_seconds":elapsed_stats,"ratios":ratios,
         "paired_FMC_minus_R16":{"n":len(deltas),"mean":dmean,"sample_sd":dsd,"standard_error":dse,
                                "mean_plus_2SE":upper,"values":deltas},
         "scientific_checksum_expected":expected,
         "all_sample_checksums_pass":True,
         "no_posthoc_timing_outlier_deletion":True,
         "formal_performance_claim":False,"cpu_baseline_established":False,
         "application_acceptance":False,"production_rom_authorized":False}
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({k:v for k,v in out.items() if k not in ("samples","warmups")},sort_keys=True))
    return 0

if __name__=="__main__": raise SystemExit(main())
