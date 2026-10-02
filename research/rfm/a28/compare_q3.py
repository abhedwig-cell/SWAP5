#!/usr/bin/env python3
import csv,json,sys
from pathlib import Path

exact=Path(sys.argv[1]);approx=Path(sys.argv[2]);out=Path(sys.argv[3]);out.mkdir(parents=True,exist_ok=True)

def load(path):
    lines=[x for x in path.read_text().splitlines() if x.startswith("ABC,")]
    hdr=lines[0].split(",")[1:]
    rows={}
    for line in lines[1:]:
        d=dict(zip(hdr,line.split(",")[1:]))
        if int(d["arm"])!=3: continue
        key=(int(d["soil"]),int(d["geom"]),int(d["regime"]))
        rows[key]=d
    return rows

e,a=load(exact),load(approx)
rows=[];fail=[]
for key in sorted(set(e)&set(a)):
    x,y=e[key],a[key]
    xc=int(x["completed"]);yc=int(y["completed"])
    rec={"soil":key[0],"geom":key[1],"regime":key[2],"exact_completed":xc,"approx_completed":yc}
    if xc and yc:
        storage=abs(float(y["total_storage_cm"])-float(x["total_storage_cm"]))
        drainage=abs((float(y["bottom_out_cm"])+float(y["fast_external_out_cm"]))-(float(x["bottom_out_cm"])+float(x["fast_external_out_cm"])))
        theta=max(abs(float(y[k])-float(x[k])) for k in ("theta1","theta5","theta10"))
        mass=float(y["max_mass_resid_cm"])
        solver_same=all(y[k]==x[k] for k in ("nonlinear","retries","backtracks"))
        ok=storage<=.02 and drainage<=.02 and theta<=.01 and mass<=1e-6
        rec.update(storage_diff_cm=storage,drainage_diff_cm=drainage,max_sampled_theta_diff=theta,approx_mass_resid_cm=mass,
                   nonlinear_delta=int(y["nonlinear"])-int(x["nonlinear"]),retry_delta=int(y["retries"])-int(x["retries"]),
                   backtrack_delta=int(y["backtracks"])-int(x["backtracks"]),solver_counts_identical=solver_same,gate_pass=ok)
        if not ok: fail.append(key)
    else:
        rec["gate_pass"]= (not xc) or yc
        if xc and not yc: fail.append(key)
    rows.append(rec)
if len(rows)!=32: raise SystemExit(f"expected 32 common cases, got {len(rows)}")
fields=[]
for r in rows:
    for k in r:
        if k not in fields:fields.append(k)
with (out/"a28_q3_comparison.csv").open("w",newline="") as f:
    w=csv.DictWriter(f,fieldnames=fields);w.writeheader();w.writerows(rows)
summary={"common_cases":len(rows),"joint_completed":sum(r["exact_completed"] and r["approx_completed"] for r in rows),
         "exact_completed":sum(r["exact_completed"] for r in rows),"approx_completed":sum(r["approx_completed"] for r in rows),
         "failed_gate_keys":[list(k) for k in fail],"gate_pass":not fail}
(out/"a28_q3_summary.json").write_text(json.dumps(summary,indent=2)+"\n")
print(json.dumps(summary,indent=2))
if fail: raise SystemExit("A28 Q3 trajectory gate failed")
