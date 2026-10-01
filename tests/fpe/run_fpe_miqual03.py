#!/usr/bin/env python3
import json,math,subprocess,sys
from pathlib import Path

pre32,pre64,hold32,hold64,bank_path=sys.argv[1:6]
bank=json.loads(Path(bank_path).read_text())
mats={x["id"]:x for x in bank["materials"]}

base_cases=[
 ("B01_N64_T49",pre64,hold64,"B01",49),
 ("B12_N64_T49",pre64,hold64,"B12",49),
 ("O05_N64_T49",pre64,hold64,"O05",49),
 ("B12_N32_T25",pre32,hold32,"B12",25),
 ("O05_N32_T25",pre32,hold32,"O05",25),
]
forcings=[
 ("DRYING",0.02),
 ("NEUTRAL",0.0),
 ("BASE",-0.01),
 ("INFILTRATION",-0.10),
 ("STRONG_INFILTRATION",-1.00),
]

cases=[]
for bid,preexe,holdexe,mid,tail in base_cases:
    for fid,flux in forcings:
        cases.append((f"{bid}_{fid}",preexe,holdexe,mid,tail,fid,flux))

def args_for(cid,mid,tail,flux):
    m=mats[mid]
    return [cid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
            str(m["ksat"]),str(m["lambda"]),str(tail),str(flux)]

preflight=[]
valid=[]
for cid,preexe,holdexe,mid,tail,fid,flux in cases:
    cp=subprocess.run([preexe]+args_for(cid,mid,tail,flux),text=True,capture_output=True)
    print(cp.stdout,end="")
    if cp.returncode:
        print(cp.stderr,file=sys.stderr)
        print('F_PE_MIQUAL03_RESULT={"aggregate":"MIQUAL03_EXECUTION_INVALID"}')
        print("F_PE_MIQUAL03=PASS")
        raise SystemExit
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14Z43A_CASE|")),None)
    if line is None:
        print('F_PE_MIQUAL03_RESULT={"aggregate":"MIQUAL03_EXECUTION_INVALID"}')
        print("F_PE_MIQUAL03=PASS")
        raise SystemExit
    d={k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
    row={
      "case":cid,"material":mid,"forcing":fid,"top_flux":flux,
      "geometry":"N64_T49" if tail==49 else "N32_T25",
      "complete":int(d["COMPLETE"])==1,"fail_step":int(d["FAIL_STEP"]),
      "last_accepted":int(d["LAST_ACCEPTED"]),"status":int(d["STATUS"]),
      "retry":int(d["RETRY"]),"nonlinear_iterations":int(d["NL"]),
      "jacobian_builds":int(d["JAC"]),"linear_solves":int(d["LINEAR"]),
      "backtracking_attempts":int(d["BACKTRACK"]),"internal_retries":int(d["INTERNAL_RETRIES"]),
      "route":d["ROUTE"],"max_ledger":float(d["MAX_LEDGER"]),"tail":int(d["TAIL"])
    }
    preflight.append(row)
    if row["complete"]:
        valid.append((cid,preexe,holdexe,mid,tail,fid,flux))

forcing_valid={fid:0 for fid,_ in forcings}
for x in valid:
    forcing_valid[x[5]]+=1
coverage_ok=(len(valid)>=20 and all(v>=3 for v in forcing_valid.values()))

rows=[]
physical_fail=False
route_fail=False
invalid=False
if coverage_ok:
  for cid,preexe,holdexe,mid,tail,fid,flux in valid:
    cp=subprocess.run([holdexe]+args_for(cid,mid,tail,flux),text=True,capture_output=True)
    print(cp.stdout,end="")
    if cp.returncode:
        print(cp.stderr,file=sys.stderr); invalid=True; break
    if "Z43_TRAJECTORY_PHYSICAL_MISMATCH" in cp.stdout:
        physical_fail=True
        rows.append({"case":cid,"material":mid,"forcing":fid,"top_flux":flux,
                     "physical_pass":False,"reported_failure":"Z43_TRAJECTORY_PHYSICAL_MISMATCH"})
        continue
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14Z43_METRICS|")),None)
    hist=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14Z43_HIST=")),"")
    if line is None:
        invalid=True; break
    d={k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
    steps=4000
    red=int(d["REDUCED_COUNT"]); fb=int(d["FALLBACK_COUNT"]); bp=int(d["BYPASS_COUNT"])
    row={
      "case":cid,"material":mid,"forcing":fid,"top_flux":flux,
      "wall_ratio":float(d["WALL_RATIO"]),"work_ratio":float(d["WORK_RATIO"]),
      "reduced_count":red,"fallback_count":fb,"bypass_count":bp,"reduced_fraction":red/steps,
      "mean_active":float(d["MEAN_ACTIVE"]),"full_final_tail":int(d["FULL_FINAL_TAIL"]),
      "adaptive_final_tail":int(d["ADAPTIVE_FINAL_TAIL"]),"full_events":int(d["FULL_EVENTS"]),
      "adaptive_events":int(d["ADAPTIVE_EVENTS"]),"max_hdiff":float(d["MAX_HDIFF"]),
      "max_tdiff":float(d["MAX_TDIFF"]),"max_full_ledger":float(d["MAX_FULL_LEDGER"]),
      "max_adaptive_ledger":float(d["MAX_ADAPTIVE_LEDGER"]),"origin_leak":float(d["ORIGIN_LEAK"]),
      "request_reallocs":int(d["REQUEST_REALLOCS"]),"candidate_reallocs":int(d["CANDIDATE_REALLOCS"]),
      "last_nonreduced_reason":d["LAST_NONREDUCED_REASON"],
      "histogram":hist.split("=",1)[1] if "=" in hist else ""
    }
    row["physical_pass"]=(row["max_hdiff"]<=5e-3 and row["max_tdiff"]<=5e-6 and
                          row["max_full_ledger"]<=5e-8 and row["max_adaptive_ledger"]<=5e-8 and
                          row["origin_leak"]<=1e-15 and
                          abs(row["full_final_tail"]-row["adaptive_final_tail"])<=1 and
                          row["full_events"]==row["adaptive_events"])
    row["route_pass"]=(row["reduced_fraction"]>=0.95 and
                       (fb+bp)<=0.05*steps and
                       row["last_nonreduced_reason"] in ("none","reduced-view-ineligible","eligible",
                                                        "reduced-failed","not-attempted"))
    physical_fail |= not row["physical_pass"]
    route_fail |= not row["route_pass"]
    rows.append(row)

if not coverage_ok:
    agg="MIQUAL03_REFERENCE_COVERAGE_INSUFFICIENT"
elif invalid:
    agg="MIQUAL03_EXECUTION_INVALID"
elif physical_fail:
    agg="MIQUAL03_PHYSICAL_MISMATCH"
elif route_fail:
    agg="MIQUAL03_OPERATIONAL_ROUTE_FAILURE"
else:
    wr=[r["wall_ratio"] for r in rows]
    ww=[r["work_ratio"] for r in rows]
    gm_wall=math.exp(sum(math.log(x) for x in wr)/len(wr))
    gm_work=math.exp(sum(math.log(x) for x in ww)/len(ww))
    if max(wr)<=1.10 and gm_wall<1.00 and sum(x<0.98 for x in wr)>=math.ceil(0.75*len(wr)) and gm_work<0.90:
        agg="QUALIFIED_MIQUAL03_FIXED_FLUX_FORCING_DIVERSITY"
    else:
        agg="MIQUAL03_PERFORMANCE_NOT_READY"

out={"aggregate":agg,"preflight":preflight,"reference_valid_count":len(valid),
     "reference_valid_by_forcing":forcing_valid,"rows":rows}
if rows and all("wall_ratio" in r for r in rows):
    out["geomean_wall_ratio"]=math.exp(sum(math.log(r["wall_ratio"]) for r in rows)/len(rows))
    out["geomean_work_ratio"]=math.exp(sum(math.log(r["work_ratio"]) for r in rows)/len(rows))
    out["cases_below_098"]=sum(r["wall_ratio"]<0.98 for r in rows)
print("F_PE_MIQUAL03_RESULT="+json.dumps(out,separators=(",",":"),sort_keys=True))
print("F_PE_MIQUAL03=PASS")
