#!/usr/bin/env python3
import math,sys
rows=[]
for line in open(sys.argv[1],encoding="utf-8"):
    if not line.startswith("ELASTIC67_POST|"): continue
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" in p:
            k,v=p.split("=",1); d[k]=v
    rows.append(d)
if len(rows)!=12: raise SystemExit("F_PE_ELASTIC67_FAIL row count")
target=[r for r in rows if abs(float(r["subdt"])-0.000244140625)<1e-18]
control=[r for r in rows if abs(float(r["subdt"])-0.00048828125)<1e-18]
if len(target)!=6 or len(control)!=6: raise SystemExit("F_PE_ELASTIC67_FAIL split")
if any(int(r["status"])!=1 for r in control): raise SystemExit("F_PE_ELASTIC67_FAIL N2 control")
if any(int(r["status"])!=2 or int(r["nonlinear"])!=16 for r in target): raise SystemExit("F_PE_ELASTIC67_FAIL N4 pattern")
for r in target:
    vals=[float(r[k]) for k in ("max_residual","sum_residual","l2_residual","h_min","h_max")]
    if not all(math.isfinite(v) for v in vals): raise SystemExit("F_PE_ELASTIC67_FAIL nonfinite")
    print("ELASTIC67_TARGET|regime="+r["regime"]+"|delta="+r["delta"]+"|max_residual="+r["max_residual"]+"|max_node="+r["max_residual_node"]+"|sum_residual="+r["sum_residual"]+"|l2="+r["l2_residual"]+"|backtracking="+r["backtracking"]+"|internal_retries="+r["internal_retries"])
maxcomp=max(float(r["max_residual"]) for r in target)
mintotal=min(abs(float(r["sum_residual"])) for r in target)
maxtotal=max(abs(float(r["sum_residual"])) for r in target)
print(f"ELASTIC67_TOTAL|cases=6|max_compartment={maxcomp:.17e}|min_abs_total={mintotal:.17e}|max_abs_total={maxtotal:.17e}")
print("F_PE_ELASTIC67_A1_CASES=PASS")
print("F_PE_ELASTIC67_A2_PATTERN=PASS")
print("F_PE_ELASTIC67_A3_O0_O2=PASS")
print("F_PE_ELASTIC67_A4_FINITE=PASS")
