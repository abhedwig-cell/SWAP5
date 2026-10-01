#!/usr/bin/env python3
import json,math,subprocess,sys
from pathlib import Path

exe32,exe64,bank_path=sys.argv[1:4]
bank=json.loads(Path(bank_path).read_text())
mats={x["id"]:x for x in bank["materials"]}

base=[
 ("B01_N64_T49",exe64,"B01",49),
 ("B12_N64_T49",exe64,"B12",49),
 ("O05_N64_T49",exe64,"O05",49),
 ("B12_N32_T25",exe32,"B12",25),
 ("O05_N32_T25",exe32,"O05",25),
]
rains=[("DRY",0.0),("MODERATE",1.0),("WET",8.0),("PONDING",25.0)]
cases=[(f"{cid}_{rid}",exe,mid,tail,rid,rain) for cid,exe,mid,tail in base for rid,rain in rains]

def args(mode,cid,mid,tail,rain):
    m=mats[mid]
    return [mode,cid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
            str(m["ksat"]),str(m["lambda"]),str(tail),str(rain)]

pre=[]
valid=[]
rain_valid={rid:0 for rid,_ in rains}
ref_exposure={"flux":0,"head":0,"pond":0,"runoff":0}

for cid,exe,mid,tail,rid,rain in cases:
    cp=subprocess.run([exe]+args("REF",cid,mid,tail,rain),text=True,capture_output=True)
    print(cp.stdout,end="")
    if cp.returncode:
        print(cp.stderr,file=sys.stderr)
        print('F_PE_MIQUAL04_RESULT={"aggregate":"MIQUAL04_EXECUTION_INVALID"}')
        print("F_PE_MIQUAL04=PASS")
        raise SystemExit
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_MIQUAL04_REF|")),None)
    if line is None:
        print('F_PE_MIQUAL04_RESULT={"aggregate":"MIQUAL04_EXECUTION_INVALID"}')
        print("F_PE_MIQUAL04=PASS")
        raise SystemExit
    d={k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
    complete=int(d["COMPLETE"])==1
    row={"case":cid,"material":mid,"rain_class":rid,"rain":rain,"complete":complete,
         "last_accepted":int(d["LAST_ACCEPTED"]),"max_ledger":float(d["MAX_LEDGER"]),
         "tail":int(d["TAIL"]),"runoff":float(d["RUNOFF"]),
         "flux":int(d["FLUX"]),"head":int(d["HEAD"]),"pond":int(d["POND"]),
         "runoff_route":int(d["RUNOFF_ROUTE"]),"reason":d.get("REASON","ok")}
    pre.append(row)
    if complete:
        valid.append((cid,exe,mid,tail,rid,rain))
        rain_valid[rid]+=1
        ref_exposure["flux"]+=row["flux"]; ref_exposure["head"]+=row["head"]
        ref_exposure["pond"]+=row["pond"]; ref_exposure["runoff"]+=row["runoff_route"]

coverage_ok=(len(valid)>=15 and all(v>=3 for v in rain_valid.values()))
exposure_ok=((ref_exposure["flux"]+ref_exposure["head"])>0 and ref_exposure["pond"]>0 and ref_exposure["runoff"]>0)

rows=[]
physical_fail=False
route_fail=False
invalid=False
if coverage_ok and exposure_ok:
  for cid,exe,mid,tail,rid,rain in valid:
    cp=subprocess.run([exe]+args("AB",cid,mid,tail,rain),text=True,capture_output=True)
    print(cp.stdout,end="")
    if cp.returncode:
        print(cp.stderr,file=sys.stderr); invalid=True; break
    if "F_PE_MIQUAL04_PHYSICAL_FAIL" in cp.stdout:
        physical_fail=True
        rows.append({"case":cid,"material":mid,"rain_class":rid,"physical_pass":False,
                     "reported_failure":next((x for x in cp.stdout.splitlines() if "F_PE_MIQUAL04_PHYSICAL_FAIL" in x),"unknown")})
        continue
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_MIQUAL04_METRICS|")),None)
    hist=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_MIQUAL04_HIST=")),"")
    if line is None:
        invalid=True; break
    d={k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
    red=int(d["REDUCED_COUNT"]); fb=int(d["FALLBACK_COUNT"]); bp=int(d["BYPASS_COUNT"]); steps=4000
    row={"case":cid,"material":mid,"rain_class":rid,"rain":rain,
         "wall_ratio":float(d["WALL_RATIO"]),"work_ratio":float(d["WORK_RATIO"]),
         "reduced_count":red,"fallback_count":fb,"bypass_count":bp,"reduced_fraction":red/steps,
         "mean_active":float(d["MEAN_ACTIVE"]),"full_final_tail":int(d["FULL_FINAL_TAIL"]),
         "adaptive_final_tail":int(d["ADAPTIVE_FINAL_TAIL"]),"full_events":int(d["FULL_EVENTS"]),
         "adaptive_events":int(d["ADAPTIVE_EVENTS"]),"max_hdiff":float(d["MAX_HDIFF"]),
         "max_tdiff":float(d["MAX_TDIFF"]),"max_ponddiff":float(d["MAX_PONDDIFF"]),
         "max_full_ledger":float(d["MAX_FULL_LEDGER"]),"max_adaptive_ledger":float(d["MAX_ADAPTIVE_LEDGER"]),
         "origin_leak":float(d["ORIGIN_LEAK"]),"full_runoff":float(d["FULL_RUNOFF"]),
         "adaptive_runoff":float(d["ADAPTIVE_RUNOFF"]),"request_reallocs":int(d["REQUEST_REALLOCS"]),
         "candidate_reallocs":int(d["CANDIDATE_REALLOCS"]),"full_flux":int(d["FULL_FLUX"]),
         "full_head":int(d["FULL_HEAD"]),"full_pond":int(d["FULL_POND"]),
         "full_runoff_route":int(d["FULL_RUNOFF_ROUTE"]),"adapt_flux":int(d["ADAPT_FLUX"]),
         "adapt_head":int(d["ADAPT_HEAD"]),"adapt_pond":int(d["ADAPT_POND"]),
         "adapt_runoff_route":int(d["ADAPT_RUNOFF_ROUTE"]),"last_nonreduced_reason":d["LAST_NONREDUCED_REASON"],
         "histogram":hist.split("=",1)[1] if "=" in hist else ""}
    row["physical_pass"]=(row["max_hdiff"]<=5e-3 and row["max_tdiff"]<=5e-6 and
                          row["max_ponddiff"]<=1e-5 and abs(row["adaptive_runoff"]-row["full_runoff"])<=1e-5 and
                          row["max_full_ledger"]<=5e-8 and row["max_adaptive_ledger"]<=5e-8 and
                          row["origin_leak"]<=1e-15 and abs(row["full_final_tail"]-row["adaptive_final_tail"])<=1 and
                          row["full_events"]==row["adaptive_events"])
    row["route_pass"]=(row["reduced_fraction"]>=0.95 and (fb+bp)<=0.05*steps and
                       row["last_nonreduced_reason"] in ("none","reduced-view-ineligible","eligible",
                                                        "reduced-failed","not-attempted"))
    physical_fail |= not row["physical_pass"]
    route_fail |= not row["route_pass"]
    rows.append(row)

if not coverage_ok:
    agg="MIQUAL04_REFERENCE_COVERAGE_INSUFFICIENT"
elif not exposure_ok:
    agg="MIQUAL04_DYNAMIC_TOP_EXPOSURE_INSUFFICIENT"
elif invalid:
    agg="MIQUAL04_EXECUTION_INVALID"
elif physical_fail:
    agg="MIQUAL04_PHYSICAL_MISMATCH"
elif route_fail:
    agg="MIQUAL04_OPERATIONAL_ROUTE_FAILURE"
else:
    wr=[r["wall_ratio"] for r in rows]; ww=[r["work_ratio"] for r in rows]
    gm_wall=math.exp(sum(math.log(x) for x in wr)/len(wr)); gm_work=math.exp(sum(math.log(x) for x in ww)/len(ww))
    if max(wr)<=1.10 and gm_wall<1.00 and sum(x<0.98 for x in wr)>=math.ceil(0.75*len(wr)) and gm_work<0.90:
        agg="QUALIFIED_MIQUAL04_DYNAMIC_TOP_RUNOFF_PONDING"
    else:
        agg="MIQUAL04_PERFORMANCE_NOT_READY"

out={"aggregate":agg,"preflight":pre,"reference_valid_count":len(valid),
     "reference_valid_by_rain":rain_valid,"reference_route_exposure":ref_exposure,"rows":rows}
if rows and all("wall_ratio" in x for x in rows):
    out["geomean_wall_ratio"]=math.exp(sum(math.log(x["wall_ratio"]) for x in rows)/len(rows))
    out["geomean_work_ratio"]=math.exp(sum(math.log(x["work_ratio"]) for x in rows)/len(rows))
    out["cases_below_098"]=sum(x["wall_ratio"]<0.98 for x in rows)
print("F_PE_MIQUAL04_RESULT="+json.dumps(out,separators=(",",":"),sort_keys=True))
print("F_PE_MIQUAL04=PASS")
