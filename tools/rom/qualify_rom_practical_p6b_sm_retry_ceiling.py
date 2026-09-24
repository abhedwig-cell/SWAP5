#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib
import numpy as np
HIST=("HR72","HR86")
def fields(s): return dict(x.split("=",1) for x in s.strip().split("|") if "=" in x)
def parse(path):
    txt=path.read_text(errors="replace")
    if "RNP03_ADAPTIVE_REFERENCE=PASS" not in txt or "LAREDYN0R_EXECUTION_COMPLETE=PASS" not in txt:
        raise RuntimeError("retry-ceiling reference incomplete")
    states={};prof={};days={}
    for line in txt.splitlines():
        if line.startswith("LAREDYN0R_STATE|"):
            r=fields(line);states[(r["CASE"],int(r["STEP"]))]=float(r["TOTAL_STORAGE"])
        elif line.startswith("LAREDYN0R_PROFILE|"):
            r=fields(line);prof.setdefault((r["CASE"],int(r["OBS_STEP"])),{})[int(r["BIN"])]=float(r["THETA"])
        elif line.startswith("RNP03_DAY|"):
            r=fields(line);days[(r["CASE"],int(r["DAY"]))]={"accepted_substeps":int(r["ACCEPTED_SUBSTEPS"]),"cum_retries":int(r["CUM_RETRIES"])}
    out={}
    for h in HIST:
        total=[];theta=[]
        for d in range(1,61):
            total.append(states[(h,d)]);bins=prof[(h,d)];theta.append([bins[i] for i in range(1,17)])
        th=np.asarray(theta)
        out[h]={"total":np.asarray(total),"theta":th,"surface":np.sum(th[:,:2]*10,axis=1),"root":np.sum(th[:,:4]*10,axis=1),"upper":np.sum(th[:,:8]*10,axis=1)}
    return out,days
def rmse(x): return float(np.sqrt(np.mean(np.square(np.asarray(x,float)))))
def metrics(a,b):
    pools={k:[] for k in ("surface","root","upper","theta","total")};timing=0;final=0.
    for h in HIST:
        for k in pools:pools[k].append((a[h][k]-b[h][k]).ravel())
        for k in ("root","upper"):
            timing=max(timing,abs(int(np.argmax(a[h][k]))-int(np.argmax(b[h][k]))),abs(int(np.argmin(a[h][k]))-int(np.argmin(b[h][k]))))
        final=max(final,abs(float(a[h]["total"][-1]-b[h]["total"][-1])))
    return {"surface_0_20_storage_rmse_cm":rmse(np.concatenate(pools["surface"])),"root_zone_0_40_storage_rmse_cm":rmse(np.concatenate(pools["root"])),"upper_0_80_storage_rmse_cm":rmse(np.concatenate(pools["upper"])),"mapped_10cm_theta_rmse":rmse(np.concatenate(pools["theta"])),"total_storage_rmse_cm":rmse(np.concatenate(pools["total"])),"final_total_storage_bias_cm":final,"daily_storage_extremum_timing_error_days":int(timing)}
def case(a):
    status={};parsed={};diag={}
    for p in ("R12","R16"):
        txt=(a.dir/f"{p}.txt").read_text(errors="replace")
        status[p]="COMPLETE" if "RNP03_ADAPTIVE_REFERENCE=PASS" in txt else "FAILED"
        if status[p]=="COMPLETE":
            parsed[p],days=parse(a.dir/f"{p}.txt")
            vals=list(days.values())
            diag[p]={"max_cumulative_retries":max(x["cum_retries"] for x in vals),
                     "max_accepted_substeps_per_day":max(x["accepted_substeps"] for x in vals),
                     "days_with_extra_substeps":sum(x["accepted_substeps"]>64 for x in vals)}
        else:
            reason="UNKNOWN"
            for token in ("RNP03 retry budget","RNP03 minimum step","RNP03 hard mass gate","RNP03 accepted history step"):
                if token in txt: reason=token
            diag[p]={"failure_reason":reason}
    delta=metrics(parsed["R12"],parsed["R16"]) if all(status[p]=="COMPLETE" for p in ("R12","R16")) else None
    out={"schema":"swap5.rom-practical.p6b-sm-rnp03.case.v1","material":a.material,"R12_status":status["R12"],"R16_status":status["R16"],"R12_vs_R16":delta,"diagnostics":diag}
    (a.dir/"result.json").write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
def aggregate(a):
    rows=[json.load(open(p)) for p in a.input_dir.rglob("result.json")]
    expected={"B02","B05","B06","B11","B12","B16"}
    if len(rows)!=6 or {x["material"] for x in rows}!=expected: raise RuntimeError("six cases required")
    r12=all(x["R12_status"]=="COMPLETE" for x in rows);r16=all(x["R16_status"]=="COMPLETE" for x in rows)
    selected="R12" if r12 else "R16" if r16 else None
    status="RETRY_CEILING_POLICY_QUALIFIED" if selected else "GENUINE_REFERENCE_SOLVER_FLOOR_REMAINS"
    out={"schema":"swap5.rom-practical.p6b-sm-rnp03.result.v1","work_unit":"ROM-PRACTICAL-P6B-SM-RNP03","status":status,"selected_policy":selected,"R12_all_materials_complete":r12,"R16_all_materials_complete":r16,"cases":rows,"candidate_evidence_used_for_selection":False}
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"status":status,"selected":selected},sort_keys=True))
def main():
    ap=argparse.ArgumentParser();sp=ap.add_subparsers(dest="mode",required=True)
    cp=sp.add_parser("case");cp.add_argument("--material",required=True);cp.add_argument("--dir",type=pathlib.Path,required=True)
    ag=sp.add_parser("aggregate");ag.add_argument("--input-dir",type=pathlib.Path,required=True);ag.add_argument("--output",type=pathlib.Path,required=True)
    a=ap.parse_args();case(a) if a.mode=="case" else aggregate(a)
if __name__=="__main__":main()
