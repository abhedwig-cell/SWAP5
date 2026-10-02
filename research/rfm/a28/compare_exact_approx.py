#!/usr/bin/env python3
import csv,sys,json
from pathlib import Path
exact,approx=map(Path,sys.argv[1:3])
def read(p):
    with p.open(newline="") as f:return list(csv.DictReader(f))
def crows(root):
    return {(r["soil"],r["geom"],r["regime"]):r for r in read(root/"abc_raw.csv") if r["arm"]=="3"}
e,a=crows(exact),crows(approx)
if set(e)!=set(a):raise SystemExit("C case keys differ")
joint=0;max_storage=max_drain=max_theta=max_mass=0.0;count_regression=0
for k in sorted(e):
    x,y=e[k],a[k]
    if y["completed"]=="1":max_mass=max(max_mass,abs(float(y["max_mass_resid_cm"])))
    if x["completed"]!="1" or y["completed"]!="1":continue
    joint+=1
    max_storage=max(max_storage,abs(float(y["total_storage_cm"])-float(x["total_storage_cm"])))
    max_drain=max(max_drain,abs(float(y["bottom_out_cm"])-float(x["bottom_out_cm"])))
    for q in ("theta1","theta5","theta10"):max_theta=max(max_theta,abs(float(y[q])-float(x[q])))
comp=read(approx/"abc_comparison.csv")
bad=[r for r in comp if r["B_completed"]=="1" and r["C_completed"]=="1" and r["classification"]!="E1"]
if bad:count_regression=len(bad)
summary={"joint_exact_approx_C":joint,"max_total_storage_diff_cm":max_storage,"max_bottom_out_diff_cm":max_drain,
"max_sampled_theta_diff":max_theta,"max_approx_mass_residual_cm":max_mass,"non_E1_joint_BC":count_regression}
print(json.dumps(summary,indent=2))
if max_mass>1e-6:raise SystemExit("mass gate")
if max_storage>0.02:raise SystemExit("storage gate")
if max_drain>0.02:raise SystemExit("drainage gate")
if max_theta>0.01:raise SystemExit("theta gate")
if count_regression:raise SystemExit("E1 regression")
if joint<29:raise SystemExit(f"insufficient exact/approx joint C cases: {joint}")
print("A28_APPROXIMATE_ABC_Q3=PASS")
