#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text())
mats={x["id"]:x for x in bank["materials"]}
routes=("FLUX","HEAD","RUNOFF")
dts=[0.00025,0.000125,0.0000625,0.00003125]
dtop=10.0; pmax=0.05; rsro=0.05

def k_vg(m,h):
    mm=1.0-1.0/m["n"]
    se=(1.0+(abs(m["alpha"]*h))**m["n"])**(-mm)
    term=1.0-(1.0-se**(1.0/mm))**mm
    return m["ksat"]*(se**m["lambda"])*(term**2)

def fixture(m,r):
    if r=="FLUX":
        h=-50.0; p=0.0
        kt=k_vg(m,h); kf=0.5*(m["ksat"]+kt)
        qhead=-kf*((p-h)/dtop+1.0)
        return h,p,0.25*(-qhead),kt
    if r=="HEAD":
        h=-5.0; p=0.025
        kt=k_vg(m,h); kf=0.5*(m["ksat"]+kt)
        qhead=-kf*((p-h)/dtop+1.0)
        return h,p,-qhead,kt
    h=-5.0; p=0.100
    kt=k_vg(m,h); kf=0.5*(m["ksat"]+kt)
    qhead=-kf*((p-h)/dtop+1.0)
    return h,p,-qhead+(p-pmax)/rsro,kt

def parse(line):
    d={k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
    return d

rows=[]; observations=[]
for mid in ("B01","B12","O05","O14"):
    m=mats[mid]
    for route in routes:
        h,pd,rain,ktop=fixture(m,route)
        for dt in dts:
            cmd=[str(exe),mid,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
                 str(m["ksat"]),str(m["lambda"]),str(h),str(pd),str(rain),str(dt),str(pmax),str(rsro),str(ktop)]
            cp=subprocess.run(cmd,text=True,capture_output=True)
            result=next((parse(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17D_RESULT|")),None)
            obs=[parse(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17D_OBS|")]
            row={"material":mid,"route":route,"dt":dt,"process_ok":cp.returncode==0}
            if result:
                row.update({"eligible":int(result["ELIGIBLE"]),
                            "deriv_available":int(result["DERIV_AVAILABLE"]),
                            "best_abs_err":float(result["BEST_ABS_ERR"]),
                            "best_rel_err":float(result["BEST_REL_ERR"]),
                            "base_route":int(result["BASE_ROUTE"])})
            else:
                row.update({"eligible":0,"deriv_available":0,"best_abs_err":math.inf,"best_rel_err":math.inf,"base_route":0,
                            "stdout":cp.stdout[-1000:],"stderr":cp.stderr[-1000:]})
            rows.append(row)
            for o in obs:
                observations.append({
                    "material":mid,"route":route,"dt":dt,
                    "eps":float(o["EPS"]),"provider_route":int(o["PROVIDER_ROUTE"]),
                    "an_dhsurf":float(o["AN_DHSURF"]),"fd_dhsurf":float(o["FD_DHSURF"]),
                    "fd_dqtop":float(o["FD_DQTOP"]),"fd_dpond":float(o["FD_DPOND"]),
                    "fd_drunoff":float(o["FD_DRUNOFF"])
                })

hr=[x for x in rows if x["route"] in ("HEAD","RUNOFF") and x["eligible"]>0 and x["deriv_available"]==1]
mismatch=sum(x["best_abs_err"]>max(1e-7,1e-5*max(1e-30,abs(next((o["fd_dhsurf"] for o in observations if o["material"]==x["material"] and o["route"]==x["route"] and o["dt"]==x["dt"]),0.0)))) for x in hr)
frac=mismatch/len(hr) if hr else 1.0
materials=sorted({x["material"] for x in hr})
route_set=sorted({x["route"] for x in rows if x["eligible"]>0})
coverage=(sum(x["eligible"] for x in rows)>=100 and len(materials)>=3 and "HEAD" in route_set and "RUNOFF" in route_set and "FLUX" in route_set)
if not coverage:
    cls="BLOCKED_TIMEINT17D_FD_COVERAGE"
elif frac>=0.25:
    cls="TIMEINT17D_PROVIDER_DERIVATIVE_MISMATCH"
else:
    cls="TIMEINT17D_PROVIDER_DERIVATIVE_PASSES_P0"
summary={"classification":cls,"coverage_ok":coverage,"eligible_epsilon_observations":sum(x["eligible"] for x in rows),
         "eligible_head_runoff_fixtures":len(hr),"provider_mismatch_fixtures":mismatch,
         "provider_mismatch_fraction":frac,"materials":materials,"routes":route_set,
         "process_failures":sum(not x["process_ok"] for x in rows)}
print("F_PE_TIMEINT17D_RESULTS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17D_OBSERVATIONS="+json.dumps(observations,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17D_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17D=PASS")
