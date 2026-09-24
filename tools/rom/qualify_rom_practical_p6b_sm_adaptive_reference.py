#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib
import numpy as np
HIST=("HR72","HR86")
def fields(s): return dict(x.split("=",1) for x in s.strip().split("|") if "=" in x)
def parse(path):
    txt=path.read_text(errors="replace")
    if "RNP02_ADAPTIVE_REFERENCE=PASS" not in txt or "LAREDYN0R_EXECUTION_COMPLETE=PASS" not in txt:
        raise RuntimeError("adaptive reference incomplete")
    states={}; prof={}; retries={}
    for line in txt.splitlines():
        if line.startswith("LAREDYN0R_STATE|"):
            r=fields(line); states[(r["CASE"],int(r["STEP"]))]=float(r["TOTAL_STORAGE"])
        elif line.startswith("LAREDYN0R_PROFILE|"):
            r=fields(line); prof.setdefault((r["CASE"],int(r["OBS_STEP"])),{})[int(r["BIN"])]=float(r["THETA"])
        elif line.startswith("RNP02_DAY|"):
            r=fields(line); retries[(r["CASE"],int(r["DAY"]))]=int(r["CUM_RETRIES"])
    out={}
    for h in HIST:
        total=[];theta=[]
        for d in range(1,61):
            total.append(states[(h,d)]); bins=prof[(h,d)];theta.append([bins[i] for i in range(1,17)])
        th=np.asarray(theta)
        out[h]={"total":np.asarray(total),"theta":th,
                "surface":np.sum(th[:,:2]*10,axis=1),"root":np.sum(th[:,:4]*10,axis=1),"upper":np.sum(th[:,:8]*10,axis=1)}
    return out,retries
def rmse(x): return float(np.sqrt(np.mean(np.square(np.asarray(x,float)))))
def metrics(a,b):
    pools={k:[] for k in ("surface","root","upper","theta","total")};timing=0;final=0.
    for h in HIST:
        for k in pools:pools[k].append((a[h][k]-b[h][k]).ravel())
        for k in ("root","upper"):
            timing=max(timing,abs(int(np.argmax(a[h][k]))-int(np.argmax(b[h][k]))),abs(int(np.argmin(a[h][k]))-int(np.argmin(b[h][k]))))
        final=max(final,abs(float(a[h]["total"][-1]-b[h]["total"][-1])))
    return {"surface_0_20_storage_rmse_cm":rmse(np.concatenate(pools["surface"])),
            "root_zone_0_40_storage_rmse_cm":rmse(np.concatenate(pools["root"])),
            "upper_0_80_storage_rmse_cm":rmse(np.concatenate(pools["upper"])),
            "mapped_10cm_theta_rmse":rmse(np.concatenate(pools["theta"])),
            "total_storage_rmse_cm":rmse(np.concatenate(pools["total"])),
            "final_total_storage_bias_cm":final,
            "daily_storage_extremum_timing_error_days":int(timing)}
def case(a):
    status={};parsed={};retry_summary={}
    for p in ("A32","A64"):
        path=a.dir/f"{p}.txt";txt=path.read_text(errors="replace")
        status[p]="COMPLETE" if "RNP02_ADAPTIVE_REFERENCE=PASS" in txt else "FAILED"
        if status[p]=="COMPLETE":
            parsed[p],rr=parse(path)
            retry_summary[p]={"max_cumulative_retries":max(rr.values()) if rr else 0,
                              "days_with_retry":sum(v>0 for v in rr.values())}
    delta=metrics(parsed["A32"],parsed["A64"]) if all(status[p]=="COMPLETE" for p in ("A32","A64")) else None
    out={"schema":"swap5.rom-practical.p6b-sm-rnp02.case.v1","material":a.material,
         "A32_status":status["A32"],"A64_status":status["A64"],"A32_vs_A64":delta,"retry_summary":retry_summary}
    (a.dir/"result.json").write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
def aggregate(a):
    rows=[json.load(open(p)) for p in a.input_dir.rglob("result.json")]
    expected={"B02","B05","B06","B11","B12","B16"}
    if len(rows)!=6 or {x["material"] for x in rows}!=expected: raise RuntimeError("six cases required")
    a32=all(x["A32_status"]=="COMPLETE" for x in rows);a64=all(x["A64_status"]=="COMPLETE" for x in rows)
    selected="A32" if a32 and a64 else None
    out={"schema":"swap5.rom-practical.p6b-sm-rnp02.result.v1","work_unit":"ROM-PRACTICAL-P6B-SM-RNP02",
         "status":"ADAPTIVE_REFERENCE_POLICY_QUALIFIED" if selected else "ADAPTIVE_REFERENCE_POLICY_BLOCKED",
         "selected_policy":selected,"A32_all_materials_complete":a32,"A64_all_materials_complete":a64,
         "cases":rows,"candidate_evidence_used_for_selection":False}
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"status":out["status"],"selected":selected},sort_keys=True))
def main():
    ap=argparse.ArgumentParser();sp=ap.add_subparsers(dest="mode",required=True)
    cp=sp.add_parser("case");cp.add_argument("--material",required=True);cp.add_argument("--dir",type=pathlib.Path,required=True)
    ag=sp.add_parser("aggregate");ag.add_argument("--input-dir",type=pathlib.Path,required=True);ag.add_argument("--output",type=pathlib.Path,required=True)
    a=ap.parse_args();case(a) if a.mode=="case" else aggregate(a)
if __name__=="__main__":main()
