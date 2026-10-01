#!/usr/bin/env python3
import json,subprocess,sys
exe=sys.argv[1]
cp=subprocess.run([exe,"MANAGER","EQUILIBRIUM"],text=True,capture_output=True)
print(cp.stdout,end="")
if cp.returncode:
    print(cp.stderr,file=sys.stderr)
    print('F_PE_MIQUAL12_RESULT={"aggregate":"MIQUAL12_EXECUTION_INVALID"}')
    print("F_PE_MIQUAL12=PASS")
    raise SystemExit
line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_MIQUAL07_RESULT|")),None)
if line is None:
    print('F_PE_MIQUAL12_RESULT={"aggregate":"MIQUAL12_EXECUTION_INVALID"}')
    print("F_PE_MIQUAL12=PASS")
    raise SystemExit
d={k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
complete=int(d["COMPLETE"])==1
calls=int(d["MI_CALLS"]); total=int(d["MI_TOTAL_TICKS"]); solve=int(d["MI_SOLVE_TICKS"]); rate=int(d["MI_CLOCK_RATE"])
valid=(complete and int(d["LAST_ACCEPTED"])==40000 and int(d["REDUCED"])==40000 and
       int(d["FALLBACK"])==0 and int(d["BYPASS"])==0 and float(d["MAX_MASS"])<=1e-8 and
       rate>0 and calls>0 and total>0 and total>=solve>=0)
if not valid:
    agg="MIQUAL12_EXECUTION_INVALID"
    nonsolve=-1; solve_share=-1; nonsolve_share=-1
else:
    nonsolve=total-solve
    solve_share=solve/total
    nonsolve_share=nonsolve/total
    if nonsolve_share>=0.5:
        agg="MIQUAL12_ADAPTER_NON_SOLVE_DOMINANT"
    elif solve_share>0.5:
        agg="MIQUAL12_REDUCED_SOLVE_DOMINANT"
    else:
        agg="MIQUAL12_MIXED_COMPONENT_COST"
out={"aggregate":agg,"clock_rate":rate,"calls":calls,"adapter_total_ticks":total,
     "reduced_solve_ticks":solve,"adapter_non_solve_ticks":nonsolve,
     "reduced_solve_share":solve_share,"adapter_non_solve_share":nonsolve_share,
     "deterministic_work":int(d["WORK"]),"cpu":float(d["CPU"])}
print("F_PE_MIQUAL12_RESULT="+json.dumps(out,separators=(",",":"),sort_keys=True))
print("F_PE_MIQUAL12=PASS")
