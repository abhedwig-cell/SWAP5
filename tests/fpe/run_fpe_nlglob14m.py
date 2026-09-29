#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); mats={x["id"]:x for x in data["materials"]}
dts=[0.00025,0.000125,0.0000625,0.00003125]; routes=("HEAD","RUNOFF")
horizon=.05; dtop=10.; pmax=.05; rsro=.05

def fields(line): return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
def kvg(m,h):
    mm=1-1/m["n"]; se=(1+(abs(m["alpha"]*h))**m["n"])**(-mm); term=1-(1-se**(1/mm))**mm
    return m["ksat"]*(se**m["lambda"])*term**2
def fixture(m,r):
    h=-5.; p=.025 if r=="HEAD" else .1
    kt=kvg(m,h); kf=.5*(m["ksat"]+kt); q=-kf*((p-h)/dtop+1)
    rain=-q if r=="HEAD" else -q+(p-pmax)/rsro
    return h,p,rain

rows=[]; proc=0
m=mats["O05"]
for route in routes:
  h0,p0,rain=fixture(m,route)
  for dt in dts:
    cp=subprocess.run([str(exe),"O05","TG",route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
      str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
    if cp.returncode!=0: proc+=1
    states=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14F_STATE|")]
    res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    bystep={}
    for x in states: bystep.setdefault(int(x["STEP"]),[]).append(x)
    series=[]; inconsistent=False
    for step in sorted(bystep):
      xs=sorted(bystep[step],key=lambda q:int(q["NODE"]))
      if len(xs)!=16: continue
      sat=[]
      for x in xs:
        sh=int(x["SAT_H"])==1; st=int(x["SAT_THETA"])==1
        if sh!=st: inconsistent=True
        if sh and st: sat.append(int(x["NODE"]))
      series.append({"step":step,"time":step*dt,"xs":xs,"sat":sat,"count":len(sat),
                     "contiguous":(not sat) or sat==list(range(min(sat),17))})
    counts=[x["count"] for x in series]
    peak=max(counts) if counts else None
    last_peak=None; first_lower=None
    if counts:
      peak_idx=[i for i,v in enumerate(counts) if v==peak]
      for i in peak_idx:
        if i+1<len(counts) and counts[i+1]<peak:
          last_peak=i; first_lower=i+1; break
    valid=False; event_node=0; tl=tr=None; hl=hr=thl=thr=None; width=None
    if last_peak is not None and first_lower is not None:
      L=series[last_peak]; R=series[first_lower]
      lost=sorted(set(L["sat"])-set(R["sat"]))
      if len(lost)==1: event_node=lost[0]
      if event_node>0:
        xl=L["xs"][event_node-1]; xr=R["xs"][event_node-1]
        tl=L["time"]; tr=R["time"]; width=tr-tl
        hl=float(xl["H"]); hr=float(xr["H"]); thl=float(xl["THETA"]); thr=float(xr["THETA"])
        valid=(peak==14 and R["count"]==13 and R["step"]==L["step"]+1 and
               L["contiguous"] and R["contiguous"] and
               int(xl["SAT_H"])==1 and int(xl["SAT_THETA"])==1 and
               int(xr["SAT_H"])==0 and int(xr["SAT_THETA"])==0 and
               hl>=0 and hr<0 and thl==m["theta_s"] and thr<m["theta_s"] and
               not inconsistent and abs(width-dt)<=max(1e-15,1e-12*dt))
    complete=bool(res and res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1)
    mass_ok=bool(res and abs(float(res["MAX_LEDGER"]))<=5e-8 and abs(float(res["CUM_LEDGER"]))<=5e-8)
    rows.append({"route":route,"dt":dt,"valid_bracket":valid,"event_node":event_node,
                 "t_left":tl,"t_right":tr,"width":width,"t_mid":0.5*(tl+tr) if tl is not None else None,
                 "h_left":hl,"h_right":hr,"theta_left":thl,"theta_right":thr,
                 "indicator_inconsistent":inconsistent,"complete":complete,"mass_ok":mass_ok,
                 "process_ok":cp.returncode==0})

families={}
all_pass=True; node_inconsistent=False; state_inconsistent=False
for route in routes:
    rs=sorted([x for x in rows if x["route"]==route],key=lambda x:-x["dt"])
    same_node=len({x["event_node"] for x in rs})==1 and rs[0]["event_node"]>0
    widths_ok=all(x["width"] is not None and abs(x["width"]-x["dt"])<=max(1e-15,1e-12*x["dt"]) for x in rs)
    valid_all=all(x["valid_bracket"] and x["complete"] and x["mass_ok"] for x in rs)
    finest=rs[-1]; nextf=rs[-2]
    mid_cons=abs(finest["t_mid"]-nextf["t_mid"])<=4*finest["dt"] if valid_all else False
    env_l=min(x["t_left"] for x in rs) if valid_all else None
    env_r=max(x["t_right"] for x in rs) if valid_all else None
    finest_in=bool(valid_all and env_l<=finest["t_left"]<=env_r and env_l<=finest["t_right"]<=env_r)
    fam_pass=valid_all and same_node and widths_ok and mid_cons and finest_in
    families[route]={"pass":fam_pass,"same_event_node":same_node,"event_node":rs[0]["event_node"] if same_node else None,
                     "midpoint_finest":finest["t_mid"] if valid_all else None,
                     "midpoint_next":nextf["t_mid"] if valid_all else None,
                     "finest_mid_diff":abs(finest["t_mid"]-nextf["t_mid"]) if valid_all else None,
                     "finest_dt":finest["dt"],"envelope_left":env_l,"envelope_right":env_r}
    all_pass=all_pass and fam_pass
    if not same_node: node_inconsistent=True
    if any(not x["valid_bracket"] for x in rs): state_inconsistent=True

coverage=(len(rows)==8 and proc==0 and all(x["complete"] and x["mass_ok"] for x in rows))
if not coverage:
    cls="BLOCKED_NLGLOB14M_RETREAT_EVENT_COVERAGE"
elif state_inconsistent:
    cls="NLGLOB14M_RETREAT_EVENT_STATE_INCONSISTENT"
elif node_inconsistent:
    cls="NLGLOB14M_RETREAT_EVENT_NODE_INCONSISTENT"
elif all_pass:
    cls="NLGLOB14M_RETREAT_EVENT_BRACKET_QUALIFIED"
else:
    cls="NLGLOB14M_RETREAT_EVENT_TIME_NOT_CONVERGED"

summary={"classification":cls,"coverage_ok":coverage,"case_count":len(rows),"process_failures":proc,
         "families":families,"all_mass_ok":all(x["mass_ok"] for x in rows)}
print("F_PE_NLGLOB14M_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14M_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14M=PASS")
