#!/usr/bin/env python3
import json,math,subprocess,sys
from pathlib import Path
exe16,exe32,exe64=map(Path,sys.argv[1:4])
bank=json.loads(Path(sys.argv[4]).read_text())
mats={x["id"]:x for x in bank["materials"]}
cases=[
 ("O05",16,12,exe16),("O05",16,8,exe16),
 ("O05",32,24,exe32),("O05",32,16,exe32),
 ("O05",64,48,exe64),("O05",64,32,exe64),
 ("B12",64,48,exe64),("B12",64,32,exe64),
]
rows=[]; physical_fail=False; execution_fail=False
for mid,N,n,exe in cases:
    m=mats[mid]
    cmd=[str(exe),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(n)]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    if cp.returncode:
        print(cp.stdout); print(cp.stderr,file=sys.stderr); execution_fail=True; break
    rline=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14Z40_RESULT=")),None)
    if rline and "PHYSICAL_MISMATCH" in rline:
        print(cp.stdout); physical_fail=True; break
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14Z40_CASE|")),None)
    if not line:
        print(cp.stdout); execution_fail=True; break
    d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
    rows.append({
      "material":mid,"N":N,"n":n,"active_fraction":n/N,
      "hdiff":float(d["HDIFF"]),"tdiff":float(d["TDIFF"]),"topdiff":float(d["TOPDIFF"]),
      "ledgerdiff":float(d["LEDGERDIFF"]),"full_tail":int(d["FULL_TAIL"]),"red_tail":int(d["RED_TAIL"]),
      "full_nl":int(d["FULL_NL"]),"red_nl":int(d["RED_NL"]),
      "full_jac":int(d["FULL_JAC"]),"red_jac":int(d["RED_JAC"]),
      "full_median_s":float(d["FULL_MEDIAN_S"]),"red_median_s":float(d["RED_MEDIAN_S"]),
      "timing_ratio":float(d["TIMING_RATIO"])
    })

def gm(vals):
    return math.exp(sum(math.log(x) for x in vals)/len(vals))

if execution_fail:
    agg="Z41_SCALING_EXECUTION_INVALID"; summary={}
elif physical_fail or len(rows)!=8:
    agg="Z41_SCALING_PHYSICAL_MISMATCH"; summary={}
else:
    allgm=gm([r["timing_ratio"] for r in rows])
    def pair(mid,N):
        vals=[r["timing_ratio"] for r in rows if r["material"]==mid and r["N"]==N]
        return gm(vals)
    g16=pair("O05",16); g32=pair("O05",32); g64=pair("O05",64); gb=pair("B12",64)
    monotonic=True
    for mid,N in [("O05",16),("O05",32),("O05",64),("B12",64)]:
        a={r["active_fraction"]:r["timing_ratio"] for r in rows if r["material"]==mid and r["N"]==N}
        monotonic &= a[0.5] <= a[0.75]+0.03
    summary={"geomean_all":allgm,"o05_n16":g16,"o05_n32":g32,"o05_n64":g64,
             "b12_n64":gb,"monotonic_fraction":bool(monotonic)}
    if allgm<0.95 and g32<0.95 and g64<0.90 and gb<0.95 and monotonic:
        agg="QUALIFIED_Z41_REAL_RICHARDS_SCALING_GAIN"
    elif allgm>1.05:
        agg="Z41_REAL_RICHARDS_SCALING_REGRESSION"
    else:
        agg="QUALIFIED_Z41_REAL_RICHARDS_SCALING_PHYSICAL_ONLY"

print("F_PE_NLGLOB14Z41_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z41_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z41_RESULT="+json.dumps({"aggregate":agg,**summary},separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z41=PASS")
