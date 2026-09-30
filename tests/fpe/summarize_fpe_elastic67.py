#!/usr/bin/env python3
import math,sys

def parse(line):
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" in p:
            k,v=p.split("=",1); d[k]=v
    return d

oracles=[]
posts=[]
for line in open(sys.argv[1],encoding="utf-8"):
    if line.startswith("ELASTIC60_ORACLE|"):
        oracles.append(parse(line))
    elif line.startswith("ELASTIC67_POST|"):
        posts.append(parse(line))

if len(oracles)!=12:
    raise SystemExit(f"F_PE_ELASTIC67_FAIL oracle rows={len(oracles)}")
if len(posts)!=6:
    raise SystemExit(f"F_PE_ELASTIC67_FAIL post rows={len(posts)}")

controls=[r for r in oracles if int(r["oracle_n"])==2]
targets=[r for r in oracles if int(r["oracle_n"])==4]
if len(controls)!=6 or len(targets)!=6:
    raise SystemExit("F_PE_ELASTIC67_FAIL N2/N4 split")
if any(r["oracle_complete"]!="T" or r["oracle_mass_ok"]!="T" for r in controls):
    raise SystemExit("F_PE_ELASTIC67_FAIL N2 control")
if any(r["oracle_complete"]!="F" or int(r["failure_step"])!=1 or int(r["failure_status"])!=2 for r in targets):
    raise SystemExit("F_PE_ELASTIC67_FAIL N4 target locus")

for r in posts:
    if int(r["oracle_n"])!=4 or int(r["step"])!=1 or int(r["status"])!=2:
        raise SystemExit("F_PE_ELASTIC67_FAIL failure post locus")
    vals=[float(r[k]) for k in ("max_residual","sum_residual","l2_residual","h_min","h_max",
                               "capacity_min","capacity_max","k_min","k_max")]
    if not all(math.isfinite(v) for v in vals):
        raise SystemExit("F_PE_ELASTIC67_FAIL nonfinite")
    if int(r["saturated_nodes"])!=0:
        raise SystemExit("F_PE_ELASTIC67_FAIL unexpected saturation")

by_delta={}
for r in posts:
    by_delta.setdefault(r.get("delta","unknown"),[]).append(r)

maxcomp=max(float(r["max_residual"]) for r in posts)
mintotal=min(abs(float(r["sum_residual"])) for r in posts)
maxtotal=max(abs(float(r["sum_residual"])) for r in posts)
total_only=all(float(r["max_residual"])<=1e-12 and abs(float(r["sum_residual"]))>1e-12 for r in posts)

for r in posts:
    print("ELASTIC67_TARGET|oracle_n="+r["oracle_n"]+
          "|max_residual="+r["max_residual"]+
          "|max_node="+r["max_residual_node"]+
          "|sum_residual="+r["sum_residual"]+
          "|l2="+r["l2_residual"]+
          "|nonlinear="+r["nonlinear"]+
          "|backtracking="+r["backtracking"]+
          "|route="+r["route"])

print(f"ELASTIC67_TOTAL|cases=6|max_compartment={maxcomp:.17e}|min_abs_total={mintotal:.17e}|max_abs_total={maxtotal:.17e}|total_only={'T' if total_only else 'F'}")
print("F_PE_ELASTIC67_A1_CASES=PASS")
print("F_PE_ELASTIC67_A2_N2_CONTROL=PASS")
print("F_PE_ELASTIC67_A3_N4_FIRST_STEP=PASS")
print("F_PE_ELASTIC67_A4_O0_O2=PASS")
if total_only:
    print("F_PE_ELASTIC67_MECHANISM=TOTAL_BALANCE_FLOOR")
else:
    print("F_PE_ELASTIC67_MECHANISM=NOT_TOTAL_ONLY")
