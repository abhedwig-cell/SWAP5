#!/usr/bin/env python3
import math,sys

def parse(line):
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" in p:
            k,v=p.split("=",1); d[k]=v
    return d

lines=open(sys.argv[1],encoding="utf-8").read().splitlines()
post=[parse(x) for x in lines if x.startswith("ELASTIC67_POST|")]
oracle=[parse(x) for x in lines if x.startswith("ELASTIC60_ORACLE|")]

if len(post)!=6: raise SystemExit(f"F_PE_ELASTIC67_FAIL post count={len(post)}")
if len(oracle)!=12: raise SystemExit(f"F_PE_ELASTIC67_FAIL oracle count={len(oracle)}")

n2=[r for r in oracle if int(r["oracle_n"])==2]
n4=[r for r in oracle if int(r["oracle_n"])==4]
if len(n2)!=6 or len(n4)!=6: raise SystemExit("F_PE_ELASTIC67_FAIL oracle split")
if any(r["oracle_complete"]!="T" or r["oracle_mass_ok"]!="T" for r in n2):
    raise SystemExit("F_PE_ELASTIC67_FAIL N2 control")
if any(r["oracle_complete"]!="F" or int(r["failure_step"])!=1 or int(r["failure_status"])!=2 for r in n4):
    raise SystemExit("F_PE_ELASTIC67_FAIL N4 pattern")

for r in post:
    vals=[float(r[k]) for k in ("max_residual","sum_residual","l2_residual","h_min","h_max")]
    if not all(math.isfinite(v) for v in vals): raise SystemExit("F_PE_ELASTIC67_FAIL nonfinite")
    if int(r["oracle_n"])!=4 or int(r["step"])!=1 or int(r["status"])!=2 or int(r["nonlinear"])!=16:
        raise SystemExit("F_PE_ELASTIC67_FAIL post pattern")
    print("ELASTIC67_TARGET|oracle_n="+r["oracle_n"]+"|max_residual="+r["max_residual"]+
          "|max_node="+r["max_residual_node"]+"|sum_residual="+r["sum_residual"]+
          "|l2="+r["l2_residual"]+"|backtracking="+r["backtracking"]+
          "|alternative="+r["alternative"]+"|internal_retries="+r["internal_retries"])

maxcomp=max(float(r["max_residual"]) for r in post)
mincomp=min(float(r["max_residual"]) for r in post)
mintotal=min(abs(float(r["sum_residual"])) for r in post)
maxtotal=max(abs(float(r["sum_residual"])) for r in post)
print(f"ELASTIC67_TOTAL|cases=6|min_compartment={mincomp:.17e}|max_compartment={maxcomp:.17e}|min_abs_total={mintotal:.17e}|max_abs_total={maxtotal:.17e}")
print("F_PE_ELASTIC67_A1_CASES=PASS")
print("F_PE_ELASTIC67_A2_PATTERN=PASS")
print("F_PE_ELASTIC67_A3_O0_O2=PASS")
print("F_PE_ELASTIC67_A4_FINITE=PASS")
