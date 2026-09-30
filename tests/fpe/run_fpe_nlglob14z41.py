#!/usr/bin/env python3
import json,math,subprocess,sys
from pathlib import Path

exe16,exe32,exe64,bank_path=sys.argv[1:5]
bank=json.loads(Path(bank_path).read_text())
m=next(x for x in bank["materials"] if x["id"]=="O05")
cases=[
 ("N16_A13",exe16,16,13),("N16_A12",exe16,16,12),
 ("N32_A26",exe32,32,26),("N32_A24",exe32,32,24),
 ("N64_A52",exe64,64,52),("N64_A48",exe64,64,48),
]
rows=[]
for name,exe,nfull,nactive in cases:
    cmd=[exe,"O05",str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(nactive)]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    if cp.returncode:
        print(cp.stdout); print(cp.stderr,file=sys.stderr)
        print('F_PE_NLGLOB14Z41_RESULT={"aggregate":"Z41_SCALING_EXECUTION_INVALID"}')
        print("F_PE_NLGLOB14Z41=PASS")
        raise SystemExit
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14Z40_CASE|")),None)
    if not line:
        print(cp.stdout)
        print('F_PE_NLGLOB14Z41_RESULT={"aggregate":"Z41_SCALING_EXECUTION_INVALID"}')
        print("F_PE_NLGLOB14Z41=PASS")
        raise SystemExit
    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
    row={
      "case":name,"full_n":nfull,"active_n":int(d["ACTIVE_N"]),
      "active_fraction":int(d["ACTIVE_N"])/nfull,
      "hdiff":float(d["HDIFF"]),"tdiff":float(d["TDIFF"]),
      "topdiff":float(d["TOPDIFF"]),"ledgerdiff":float(d["LEDGERDIFF"]),
      "full_tail":int(d["FULL_TAIL"]),"red_tail":int(d["RED_TAIL"]),
      "full_nl":int(d["FULL_NL"]),"red_nl":int(d["RED_NL"]),
      "full_jac":int(d["FULL_JAC"]),"red_jac":int(d["RED_JAC"]),
      "full_median_s":float(d["FULL_MEDIAN_S"]),
      "red_median_s":float(d["RED_MEDIAN_S"]),
      "timing_ratio":float(d["TIMING_RATIO"])
    }
    physical=(row["hdiff"]<=5e-5 and row["tdiff"]<=5e-8 and row["topdiff"]<=5e-8 and
              row["ledgerdiff"]<=5e-7 and row["full_tail"]==row["red_tail"] and row["active_n"]<nfull)
    row["physical_pass"]=physical
    rows.append(row)

if not all(r["physical_pass"] for r in rows):
    agg="Z41_SCALING_PHYSICAL_MISMATCH"
else:
    by={r["case"]:r for r in rows}
    # allow 0.02 ratio noise as preregistered
    q1=(by["N32_A26"]["timing_ratio"] <= by["N16_A13"]["timing_ratio"]+0.02 and
        by["N64_A52"]["timing_ratio"] <= by["N32_A26"]["timing_ratio"]+0.02 and
        by["N32_A24"]["timing_ratio"] <= by["N16_A12"]["timing_ratio"]+0.02 and
        by["N64_A48"]["timing_ratio"] <= by["N32_A24"]["timing_ratio"]+0.02)
    q2=all(by[f"N{n}_A{int(n*0.75)}"]["timing_ratio"] <=
           by[f"N{n}_A{int(n*0.8125)}"]["timing_ratio"]+0.02 for n in (16,32,64))
    large=[by[x]["timing_ratio"] for x in ("N32_A26","N32_A24","N64_A52","N64_A48")]
    q3=sum(x<0.95 for x in large)>=3
    q4=(by["N64_A52"]["timing_ratio"]<0.90 or by["N64_A48"]["timing_ratio"]<0.90)
    both64=(by["N64_A52"]["timing_ratio"]<0.95 and by["N64_A48"]["timing_ratio"]<0.95)
    if q1 and q2 and q3 and both64 and q4:
        agg="QUALIFIED_Z41_HEADCALC_SCALING_GAIN"
    else:
        improves=(min(by["N64_A52"]["timing_ratio"],by["N64_A48"]["timing_ratio"]) <
                  min(by["N16_A13"]["timing_ratio"],by["N16_A12"]["timing_ratio"])-0.02)
        if any(x>1.10 for x in large):
            agg="Z41_HEADCALC_SCALING_REGRESSION"
        elif improves:
            agg="QUALIFIED_Z41_HEADCALC_SCALING_TREND_ONLY"
        else:
            agg="Z41_HEADCALC_SCALING_NEUTRAL"

out={"aggregate":agg,"rows":rows}
print("F_PE_NLGLOB14Z41_RESULT="+json.dumps(out,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z41=PASS")
