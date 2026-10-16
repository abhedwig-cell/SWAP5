#!/usr/bin/env python3
import json, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text())
mats={x["id"]:x for x in bank["materials"]}
dts=[0.00025,0.000125,0.0000625,0.00003125]
routes=("FLUX","HEAD","RUNOFF")
modes=("TG","KLAG")
horizon=0.001; dtop=10.0; pmax=0.05; rsro=0.05

def k_vg(m,h):
    mm=1.0-1.0/m["n"]
    se=(1.0+(abs(m["alpha"]*h))**m["n"])**(-mm)
    term=1.0-(1.0-se**(1.0/mm))**mm
    return m["ksat"]*(se**m["lambda"])*(term**2)

def fixture(m,route):
    if route=="FLUX":
        h=-50.0; p=0.0; kt=k_vg(m,h); kf=0.5*(m["ksat"]+kt); q=-kf*((p-h)/dtop+1.0); rain=0.25*(-q)
    elif route=="HEAD":
        h=-5.0; p=0.025; kt=k_vg(m,h); kf=0.5*(m["ksat"]+kt); q=-kf*((p-h)/dtop+1.0); rain=-q
    else:
        h=-5.0; p=0.100; kt=k_vg(m,h); kf=0.5*(m["ksat"]+kt); q=-kf*((p-h)/dtop+1.0); rain=-q+(p-pmax)/rsro
    return h,p,rain

def fields(line):
    return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}

def parse_logs(stdout):
    solves=[]; cur=None
    for line in stdout.splitlines():
        if line.startswith("F_PE_TIMEINT17E_INIT|"):
            if cur is not None: solves.append(cur)
            d=fields(line)
            cur={"init":{"sumold":float(d["SUMOLD"]),"fmax":float(d["FMAX"])},
                 "newton":[],"bt":[],"gate":[]}
        elif cur is not None and line.startswith("F_PE_TIMEINT17E_NEWTON|"):
            d=fields(line); cur["newton"].append({"iter":int(d["ITER"]),"sumold":float(d["SUMOLD"]),
                "fmax_old":float(d["FMAX_OLD"]),"max_dh":float(d["MAX_DH"]),"l2_dh":float(d["L2_DH"])})
        elif cur is not None and line.startswith("F_PE_TIMEINT17E_BT|"):
            d=fields(line); cur["bt"].append({"iter":int(d["ITER"]),"try":int(d["TRY"]),"factor":float(d["FACTOR"]),
                "sump":float(d["SUMP"]),"sumold":float(d["SUMOLD"]),"ratio":float(d["RATIO"]),
                "fmax":float(d["FMAX"]),"exit":int(d["EXIT"])})
        elif cur is not None and line.startswith("F_PE_TIMEINT17E_GATE|"):
            d=fields(line); cur["gate"].append({"iter":int(d["ITER"]),"bal":int(d["BAL_FAIL"]),"head":int(d["HEAD_FAIL"]),
                "pond":int(d["POND_FAIL"]),"total":int(d["TOTAL_FAIL"]),"converged":int(d["CONVERGED"]),
                "sump":float(d["SUMP"]),"fmax":float(d["FMAX"]),"max_head_change":float(d["MAX_HEAD_CHANGE"])})
    if cur is not None: solves.append(cur)
    return solves

def classify(sol):
    its=sorted({x["iter"] for x in sol["bt"]})
    if not its:
        return {"class":"NO_ITERATION_LOG","iterations":0}
    exhausted=0; stagnant=0; strong=0; contracted=0; full_accept=0; reduced_recovery=0
    gate_counts={"COMPARTMENT_BALANCE":0,"HEAD_CHANGE":0,"PONDING_BALANCE":0,"TOTAL_BALANCE":0}
    iter_metrics=[]
    for it in its:
        bs=[x for x in sol["bt"] if x["iter"]==it]
        exits=[x for x in bs if x["exit"]==1]
        best=min(x["ratio"] for x in bs)
        ex=(len(bs)>=8 and not exits)
        if ex: exhausted+=1
        if best>=0.99: stagnant+=1
        if best<=0.5: strong+=1
        if best<1.0 or any(x["exit"] and x["fmax"]<1e-12 for x in bs): contracted+=1
        if bs and bs[0]["factor"]==1.0 and bs[0]["exit"]==1: full_accept+=1
        if bs and bs[0]["factor"]==1.0 and bs[0]["exit"]==0 and any(x["factor"]<1.0 and x["exit"]==1 for x in bs): reduced_recovery+=1
        iter_metrics.append({"iter":it,"tries":len(bs),"best_ratio":best,"exhausted":ex,
                             "full_accept":bool(bs and bs[0]["factor"]==1.0 and bs[0]["exit"]==1)})
    for g in sol["gate"]:
        if g["bal"]: gate_counts["COMPARTMENT_BALANCE"]+=1
        if g["head"]: gate_counts["HEAD_CHANGE"]+=1
        if g["pond"]: gate_counts["PONDING_BALANCE"]+=1
        if g["total"]: gate_counts["TOTAL_BALANCE"]+=1
    n=len(its); contraction_frac=contracted/n; stagnant_frac=stagnant/n
    reduced_recovery_frac=reduced_recovery/n
    if exhausted>0:
        cls="BACKTRACK_NONDECREASE"
    elif stagnant_frac>=0.5:
        cls="STAGNATION"
    elif contraction_frac>=0.75 and any(gate_counts.values()):
        cls="POSTSTEP_GATE"
    elif reduced_recovery_frac>=0.5:
        cls="NEWTON_OVERSHOOT_WITH_RECOVERY"
    else:
        cls="MIXED"
    mx=max(gate_counts.values()) if gate_counts else 0
    dom=[k for k,v in gate_counts.items() if v==mx and v>0]
    dominant_gate=dom[0] if len(dom)==1 else ("MIXED" if dom else "NONE")
    return {"class":cls,"iterations":n,"exhausted_iterations":exhausted,"stagnant_fraction":stagnant_frac,
            "strong_contraction_fraction":strong/n,"contraction_fraction":contraction_frac,
            "full_accept_fraction":full_accept/n,"reduced_recovery_fraction":reduced_recovery_frac,
            "dominant_gate":dominant_gate,"gate_counts":gate_counts,"iteration_metrics":iter_metrics}

rows=[]
for mid in ("B01","B12","O05","O14"):
  m=mats[mid]
  for route in routes:
    h0,p0,rain=fixture(m,route)
    for dt in dts:
      for mode in modes:
        cmd=[str(exe),mid,mode,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
             str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)]
        cp=subprocess.run(cmd,text=True,capture_output=True)
        line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
        row={"material":mid,"route":route,"dt":dt,"mode":mode,"process_ok":cp.returncode==0}
        if line:
            d=fields(line); row["terminal_reason"]=d["TERMINAL_REASON"]; row["solver_status"]=int(d["SOLVER_STATUS"])
        else:
            row["terminal_reason"]="MISSING_RESULT"; row["solver_status"]=-999
        solves=parse_logs(cp.stdout)
        if row["terminal_reason"]=="ENDPOINT_SOLVE_FAILURE" and solves:
            row.update(classify(solves[-1]))
        else:
            row.update({"class":"NON_ENDPOINT_TERMINAL","iterations":0})
        if cp.returncode!=0: row["stderr"]=cp.stderr[-1000:]
        rows.append(row)

fails=[x for x in rows if x["terminal_reason"]=="ENDPOINT_SOLVE_FAILURE"]
tg=[x for x in fails if x["mode"]=="TG"]; kl=[x for x in fails if x["mode"]=="KLAG"]

def frac(rows,cls): return sum(x["class"]==cls for x in rows)/len(rows) if rows else 0.0
nondec=frac(tg,"BACKTRACK_NONDECREASE")
stag=frac(tg,"STAGNATION")
post=frac(tg,"POSTSTEP_GATE")
over=frac(tg,"NEWTON_OVERSHOOT_WITH_RECOVERY")
if nondec>=0.75: primary="TIMEINT17E_BACKTRACK_NONDECREASE_DOMINANT"
elif stag>=0.75: primary="TIMEINT17E_STAGNATION_DOMINANT"
elif post>=0.75: primary="TIMEINT17E_POSTSTEP_GATE_DOMINANT"
elif over>=0.75: primary="TIMEINT17E_NEWTON_OVERSHOOT_WITH_RECOVERY"
else: primary="TIMEINT17E_MIXED_CONTRACTION_BLOCKER"

pairs=0; same=0
for x in tg:
    y=next((q for q in kl if q["material"]==x["material"] and q["route"]==x["route"] and q["dt"]==x["dt"]),None)
    if y:
        pairs+=1
        if y["class"]==x["class"]: same+=1
shared=same/pairs if pairs else 0.0
secondary="TIMEINT17E_SHARED_NEWTON_BLOCKER" if shared>=0.75 else "TIMEINT17E_TG_SPECIFIC_NEWTON_SIGNAL"

gates={}
for x in tg:
    g=x.get("dominant_gate","NONE"); gates[g]=gates.get(g,0)+1
summary={"classification":primary,"secondary_classification":secondary,"tg_endpoint_failures":len(tg),
         "klag_endpoint_failures":len(kl),"tg_class_counts":{c:sum(x["class"]==c for x in tg) for c in
         ("BACKTRACK_NONDECREASE","STAGNATION","POSTSTEP_GATE","NEWTON_OVERSHOOT_WITH_RECOVERY","MIXED")},
         "shared_pairs":pairs,"same_class_pairs":same,"shared_class_fraction":shared,"dominant_gate_counts":gates,
         "process_failures":sum(not x["process_ok"] for x in rows)}
print("F_PE_TIMEINT17E_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17E_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17E=PASS")
