#!/usr/bin/env python3
import json,statistics,subprocess,sys

pairs=sys.argv[1:]
if len(pairs)!=7:
    raise SystemExit("expected seven N=exe arguments")
exes={}
for item in pairs:
    n_s,exe=item.split("=",1)
    exes[int(n_s)]=exe
dims=[8,10,11,12,13,14,16]
if sorted(exes)!=dims:
    raise SystemExit(f"unexpected dimensions {sorted(exes)}")

samples={n:[] for n in dims}
diag={n:None for n in dims}
for rep in range(1,6):
    order=dims if rep%2 else list(reversed(dims))
    for n in order:
        cp=subprocess.run([exes[n]],text=True,capture_output=True)
        if cp.returncode:
            print(cp.stdout,end=""); print(cp.stderr,file=sys.stderr)
            print('F_PE_MIQUAL13_RESULT={"aggregate":"MIQUAL13_EXECUTION_INVALID"}')
            print("F_PE_MIQUAL13_GATE=PASS")
            raise SystemExit
        line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_MIQUAL13_SAMPLE|")),None)
        if line is None:
            print('F_PE_MIQUAL13_RESULT={"aggregate":"MIQUAL13_EXECUTION_INVALID"}')
            print("F_PE_MIQUAL13_GATE=PASS")
            raise SystemExit
        d={k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
        row={"rep":rep,"ns_per":float(d["NS_PER"]),"cpu_per":float(d["CPU_PER"]),
             "nl":int(d["NL"]),"jac":int(d["JAC"]),"lin":int(d["LIN"]),"back":int(d["BACK"]),
             "nrun":int(d["NRUN"])}
        samples[n].append(row)
        this=(row["nl"]//row["nrun"],row["jac"]//row["nrun"],row["lin"]//row["nrun"],row["back"]//row["nrun"])
        if diag[n] is None: diag[n]=this
        elif diag[n]!=this:
            print('F_PE_MIQUAL13_RESULT={"aggregate":"MIQUAL13_SOLVER_BEHAVIOR_NOT_COMPARABLE"}')
            print("F_PE_MIQUAL13_GATE=PASS")
            raise SystemExit

med_ns={n:statistics.median(x["ns_per"] for x in samples[n]) for n in dims}
med_cpu={n:statistics.median(x["cpu_per"] for x in samples[n]) for n in dims}
common_diag=set(diag.values())
comparable=len(common_diag)==1
ratios={n:med_ns[n]/med_ns[16] for n in dims}
cpu_ratios={n:med_cpu[n]/med_cpu[16] for n in dims}
r13=ratios[13]

x=[float(n) for n in dims]
y=[med_ns[n] for n in dims]
xm=sum(x)/len(x); ym=sum(y)/len(y)
den=sum((v-xm)**2 for v in x)
b=sum((xx-xm)*(yy-ym) for xx,yy in zip(x,y))/den
a=ym-b*xm
fit16=a+b*16.0
fit13=a+b*13.0
fixed_fraction=a/fit16 if fit16!=0 else float("nan")
fit_ratio=fit13/fit16 if fit16!=0 else float("nan")

if not comparable:
    agg="MIQUAL13_SOLVER_BEHAVIOR_NOT_COMPARABLE"
elif r13>=0.95:
    agg="QUALIFIED_MIQUAL13_FIXED_OVERHEAD_DOMINANT"
elif r13>0.85:
    agg="QUALIFIED_MIQUAL13_PARTIAL_DIMENSION_SCALING"
else:
    agg="QUALIFIED_MIQUAL13_EFFECTIVE_DIMENSION_SCALING"

out={"aggregate":agg,"dimensions":dims,"samples":samples,"diagnostics_per_solve":{str(k):diag[k] for k in dims},
     "median_ns_per_solve":med_ns,"median_cpu_per_solve":med_cpu,
     "time_ratios_vs_n16":ratios,"cpu_ratios_vs_n16":cpu_ratios,"r13":r13,
     "deterministic_r13":13/16,
     "ols_intercept_ns":a,"ols_slope_ns_per_node":b,
     "ols_fixed_fraction_at_n16":fixed_fraction,"ols_fitted_r13":fit_ratio}
print("F_PE_MIQUAL13_RESULT="+json.dumps(out,separators=(",",":"),sort_keys=True))
print("F_PE_MIQUAL13_GATE=PASS")
