#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, math, pathlib, resource, statistics, subprocess, time
import numpy as np

HIST=("HR72","HR86")
BOUNDS=[0.,20.,40.,80.,160.]
DZ=np.diff(BOUNDS)

def fields(line):
    return dict(x.split("=",1) for x in line.strip().split("|") if "=" in x)

def invoke(cmd,path):
    before=resource.getrusage(resource.RUSAGE_CHILDREN); t0=time.perf_counter()
    with path.open("w") as f:
        p=subprocess.run([str(x) for x in cmd],stdout=f,stderr=subprocess.STDOUT,timeout=180)
    after=resource.getrusage(resource.RUSAGE_CHILDREN)
    return {"exit_status":p.returncode,"wall_s":time.perf_counter()-t0,
            "cpu_s":(after.ru_utime-before.ru_utime)+(after.ru_stime-before.ru_stime)}

def summary(samples):
    return {k:{"min":min(x[k] for x in samples),"median":statistics.median(x[k] for x in samples),"max":max(x[k] for x in samples)} for k in ("wall_s","cpu_s")}

def mapped(theta):
    out=[]
    for j in range(16):
        lo=10*j; hi=lo+10.; w=0.
        z=0.
        for t,d in zip(theta,DZ):
            w+=t*max(0.,min(hi,z+d)-max(lo,z)); z+=d
        out.append(w/10.)
    return np.asarray(out)

def parse_candidate(path):
    txt=path.read_text(errors="replace")
    if "P4_EXECUTION_COMPLETE=PASS" not in txt: raise RuntimeError("candidate incomplete")
    st={}; ly={}; led={}
    for line in txt.splitlines():
        if line.startswith("P4_STATE|"):
            r=fields(line); st[(r["HISTORY"],int(r["DAY"]))]=r
        elif line.startswith("P4_LAYER|"):
            r=fields(line); ly[(r["HISTORY"],int(r["DAY"]),int(r["LAYER"]))]=float(r["THETA"])
        elif line.startswith("P4_HISTORY_PASS|"):
            r=fields(line); led[r["HISTORY"]]=float(r["MAX_LEDGER"])
    if len(st)!=120 or len(ly)!=480 or set(led)!=set(HIST): raise RuntimeError("candidate cardinality")
    out={}
    for h in HIST:
        total=[]; surf=[]; root=[]; upper=[]; theta=[]
        for day in range(1,61):
            r=st[(h,day)]; th=np.asarray([ly[(h,day,j)] for j in range(1,5)])
            total.append(float(r["TOTAL"])); surf.append(float(r["S20"])); root.append(float(r["S40"])); upper.append(float(r["S80"])); theta.append(mapped(th))
        out[h]={"total":np.asarray(total),"surface":np.asarray(surf),"root":np.asarray(root),"upper":np.asarray(upper),"theta":np.asarray(theta)}
    return out,max(led.values())

def parse_reference(path):
    states={}; profiles={}
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("LAREDYN0R_STATE|"):
            r=fields(line); step=int(r["STEP"])
            if step%32==0: states[(r["CASE"],step//32)]=float(r["TOTAL_STORAGE"])
        elif line.startswith("LAREDYN0R_PROFILE|"):
            r=fields(line); profiles.setdefault((r["CASE"],int(r["OBS_STEP"])),{})[int(r["BIN"])]=float(r["THETA"])
    out={}
    for h in HIST:
        total=[]; theta=[]
        for d in range(1,61):
            total.append(states[(h,d)]); bins=profiles[(h,d)]; theta.append([bins[i] for i in range(1,17)])
        th=np.asarray(theta)
        out[h]={"total":np.asarray(total),"theta":th,"surface":np.sum(th[:,:2]*10,axis=1),"root":np.sum(th[:,:4]*10,axis=1),"upper":np.sum(th[:,:8]*10,axis=1)}
    return out

def rmse(x): return float(np.sqrt(np.mean(np.square(np.asarray(x,float)))))

def metrics(c,r):
    pools={k:[] for k in ("surface","root","upper","theta","total")}; timing=0; final=0.
    for h in HIST:
        for k in pools: pools[k].append((c[h][k]-r[h][k]).ravel())
        for k in ("root","upper"):
            timing=max(timing,abs(int(np.argmax(c[h][k]))-int(np.argmax(r[h][k]))),abs(int(np.argmin(c[h][k]))-int(np.argmin(r[h][k]))))
        final=max(final,abs(float(c[h]["total"][-1]-r[h]["total"][-1])))
    return {"surface_0_20_storage_rmse_cm":rmse(np.concatenate(pools["surface"])),
            "root_zone_0_40_storage_rmse_cm":rmse(np.concatenate(pools["root"])),
            "upper_0_80_storage_rmse_cm":rmse(np.concatenate(pools["upper"])),
            "mapped_10cm_theta_rmse":rmse(np.concatenate(pools["theta"])),
            "total_storage_rmse_cm":rmse(np.concatenate(pools["total"])),
            "final_total_storage_bias_cm":final,
            "daily_storage_extremum_timing_error_days":int(timing)}

def case(a):
    mats=json.loads(a.materials.read_text())["materials"]; mat=mats[a.material]
    nml=a.outdir/"material.nml"; a.outdir.mkdir(parents=True,exist_ok=True)
    nml.write_text("&material_parameters\n"+",\n".join([
      f"tr={mat['theta_r']:.17g}",f"ts={mat['theta_s']:.17g}",f"alpha={mat['alpha_per_cm']:.17g}",f"nvg={mat['n']:.17g}",f"ks={mat['Ksat_cm_per_day']:.17g}",f"lambda={mat['lambda']:.17g}"])+"\n/\n")
    cmds={"candidate":[a.exe,"SURF_P",a.material,nml,"0.005"],"R128":[a.reference128],"R64":[a.reference64]}
    samples={k:[] for k in cmds}
    for i in range(6):
        for k in (list(cmds) if i%2==0 else list(reversed(cmds))):
            res=invoke(cmds[k],a.outdir/(k+".txt"))
            if res["exit_status"]!=0: raise RuntimeError(f"{k} failed")
            if i: samples[k].append(res)
    c,ledger=parse_candidate(a.outdir/"candidate.txt"); r=parse_reference(a.outdir/"R128.txt"); r64=parse_reference(a.outdir/"R64.txt")
    m=metrics(c,r); comp=metrics(r64,r)
    observable=not (m["daily_storage_extremum_timing_error_days"]>0 and comp["daily_storage_extremum_timing_error_days"]>=m["daily_storage_extremum_timing_error_days"])
    cls="REALISTIC_DAILY_TIMING_SENSITIVE" if observable and m["daily_storage_extremum_timing_error_days"]>0 else "REALISTIC_DAILY_APPROXIMATE"
    cs=summary(samples["candidate"]); rs=summary(samples["R128"])
    out={"schema":"swap5.rom-practical.p6b-sm.case-result.v1","material":a.material,"status":"QUALIFIED","classification":cls,
         "candidate_metrics":m,"reference_comparator":comp,"reference_observable_for_timing":observable,
         "max_water_ledger_cm":ledger,"candidate_timing":cs,"R128_timing":rs,
         "wall_ratio_vs_R128":cs["wall_s"]["median"]/rs["wall_s"]["median"],
         "forcing_authority":"ROM_PRACTICAL_P6B_SM_HUPSEL_WORKLOAD.json",
         "production_rom_authorized":False,"application_acceptance_adjudicated":False}
    (a.outdir/"result.json").write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"material":a.material,"classification":cls,"wall_ratio":out["wall_ratio_vs_R128"]},sort_keys=True))

def aggregate(a):
    rows=[json.load(open(p)) for p in a.input_dir.rglob("result.json")]
    expected={"B02","B05","B06","B11","B12","B16"}
    if len(rows)!=6 or {x["material"] for x in rows}!=expected: raise RuntimeError("six unique materials required")
    out={"schema":"swap5.rom-practical.p6b-sm.result.v1","workstream":"ROM-PRACTICAL","work_unit":"ROM-PRACTICAL-P6B-SM",
         "status":"P6B_SM_REALISTIC_DAILY_WORKLOAD_COMPLETE","completed_cases":6,"total_cases":6,
         "classification_by_material":{x["material"]:x["classification"] for x in rows},
         "wall_ratio_vs_R128":{x["material"]:x["wall_ratio_vs_R128"] for x in rows},
         "speed_all_cases":all(x["wall_ratio_vs_R128"]<1 for x in rows),
         "cases":rows,
         "interpretation":["Authentic Hupsel daily Rain and ETref values drive an explicit net-atmospheric top-boundary proxy.","This is not whole-Hupsel equivalence and includes no root uptake."],
         "production_rom_authorized":False,"application_acceptance_adjudicated":False,"P_ROM_ET_opened":False}
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"status":out["status"],"classifications":out["classification_by_material"],"speed_all_cases":out["speed_all_cases"]},sort_keys=True))

def main():
    ap=argparse.ArgumentParser(); sp=ap.add_subparsers(dest="mode",required=True)
    cp=sp.add_parser("case"); cp.add_argument("--material",required=True); cp.add_argument("--materials",type=pathlib.Path,required=True); cp.add_argument("--exe",type=pathlib.Path,required=True); cp.add_argument("--reference64",type=pathlib.Path,required=True); cp.add_argument("--reference128",type=pathlib.Path,required=True); cp.add_argument("--outdir",type=pathlib.Path,required=True)
    ag=sp.add_parser("aggregate"); ag.add_argument("--input-dir",type=pathlib.Path,required=True); ag.add_argument("--output",type=pathlib.Path,required=True)
    a=ap.parse_args(); case(a) if a.mode=="case" else aggregate(a)
if __name__=="__main__": main()
