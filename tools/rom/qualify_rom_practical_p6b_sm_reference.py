#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib
import numpy as np
HIST=("HR72","HR86")
def fields(s): return dict(x.split("=",1) for x in s.strip().split("|") if "=" in x)
def parse(path,factor):
    states={}; prof={}
    txt=path.read_text(errors="replace")
    if "LAREDYN0R_EXECUTION_COMPLETE=PASS" not in txt: raise RuntimeError("reference incomplete")
    for line in txt.splitlines():
        if line.startswith("LAREDYN0R_STATE|"):
            r=fields(line); step=int(r["STEP"])
            if step%factor==0: states[(r["CASE"],step//factor)]=float(r["TOTAL_STORAGE"])
        elif line.startswith("LAREDYN0R_PROFILE|"):
            r=fields(line); prof.setdefault((r["CASE"],int(r["OBS_STEP"])),{})[int(r["BIN"])]=float(r["THETA"])
    out={}
    for h in HIST:
        total=[]; theta=[]
        for d in range(1,61):
            total.append(states[(h,d)]); bins=prof[(h,d)]; theta.append([bins[i] for i in range(1,17)])
        th=np.asarray(theta)
        out[h]={"total":np.asarray(total),"theta":th,"surface":np.sum(th[:,:2]*10,axis=1),"root":np.sum(th[:,:4]*10,axis=1),"upper":np.sum(th[:,:8]*10,axis=1)}
    return out
def rmse(x): return float(np.sqrt(np.mean(np.square(np.asarray(x,float)))))
def metrics(a,b):
    p={k:[] for k in ("surface","root","upper","theta","total")}; timing=0; final=0.
    for h in HIST:
        for k in p:p[k].append((a[h][k]-b[h][k]).ravel())
        for k in ("root","upper"):
            timing=max(timing,abs(int(np.argmax(a[h][k]))-int(np.argmax(b[h][k]))),abs(int(np.argmin(a[h][k]))-int(np.argmin(b[h][k]))))
        final=max(final,abs(float(a[h]["total"][-1]-b[h]["total"][-1])))
    return {"surface_0_20_storage_rmse_cm":rmse(np.concatenate(p["surface"])),"root_zone_0_40_storage_rmse_cm":rmse(np.concatenate(p["root"])),"upper_0_80_storage_rmse_cm":rmse(np.concatenate(p["upper"])),"mapped_10cm_theta_rmse":rmse(np.concatenate(p["theta"])),"total_storage_rmse_cm":rmse(np.concatenate(p["total"])),"final_total_storage_bias_cm":final,"daily_storage_extremum_timing_error_days":int(timing)}
def case(a):
    status={}
    for f in (64,128):
        p=a.dir/f"T{f}.txt"; txt=p.read_text(errors="replace")
        status[f]="COMPLETE" if "LAREDYN0R_EXECUTION_COMPLETE=PASS" in txt else "FAILED"
    m=None
    if status[64]=="COMPLETE" and status[128]=="COMPLETE": m=metrics(parse(a.dir/"T64.txt",64),parse(a.dir/"T128.txt",128))
    out={"schema":"swap5.rom-practical.p6b-sm-rnp.case.v1","material":a.material,"T64_status":status[64],"T128_status":status[128],"T64_vs_T128":m}
    (a.dir/"result.json").write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
def aggregate(a):
    rows=[json.load(open(p)) for p in a.input_dir.rglob("result.json")]
    expected={"B02","B05","B06","B11","B12","B16"}
    if len(rows)!=6 or {x["material"] for x in rows}!=expected: raise RuntimeError("six cases required")
    all64=all(x["T64_status"]=="COMPLETE" for x in rows); all128=all(x["T128_status"]=="COMPLETE" for x in rows)
    selected="T64" if all64 else "T128" if all128 else None
    out={"schema":"swap5.rom-practical.p6b-sm-rnp.result.v1","work_unit":"ROM-PRACTICAL-P6B-SM-RNP01","status":"REFERENCE_TEMPORAL_POLICY_QUALIFIED" if selected else "REFERENCE_TEMPORAL_POLICY_BLOCKED","selected_policy":selected,"T64_all_materials_complete":all64,"T128_all_materials_complete":all128,"cases":rows,"candidate_evidence_used_for_selection":False}
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n");print(json.dumps({"status":out["status"],"selected":selected},sort_keys=True))
def main():
    ap=argparse.ArgumentParser();sp=ap.add_subparsers(dest="mode",required=True)
    cp=sp.add_parser("case");cp.add_argument("--material",required=True);cp.add_argument("--dir",type=pathlib.Path,required=True)
    ag=sp.add_parser("aggregate");ag.add_argument("--input-dir",type=pathlib.Path,required=True);ag.add_argument("--output",type=pathlib.Path,required=True)
    a=ap.parse_args();case(a) if a.mode=="case" else aggregate(a)
if __name__=="__main__":main()
