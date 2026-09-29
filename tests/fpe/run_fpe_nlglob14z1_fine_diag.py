#!/usr/bin/env python3
import json, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); m={x["id"]:x for x in data["materials"]}["O05"]
dt=1.5625e-5; horizon=2.8; dtop=10.; pmax=.05; rsro=.05

def kvg(h):
    if h>=0: return m["ksat"]
    mm=1-1/m["n"]; se=(1+(abs(m["alpha"]*h))**m["n"])**(-mm)
    term=1-(1-se**(1/mm))**mm
    return m["ksat"]*(se**m["lambda"])*term**2
def fixture(route):
    h=-5.; p=.025 if route=="HEAD" else .1
    q=-.5*(m["ksat"]+kvg(h))*((p-h)/dtop+1)
    rain=-q if route=="HEAD" else -q+(p-pmax)/rsro
    return h,p,rain

rows=[]
for route in ("HEAD","RUNOFF"):
    h0,p0,rain=fixture(route)
    cp=subprocess.run([str(exe),"O05","TG",route,str(m["theta_r"]),str(m["theta_s"]),
      str(m["alpha"]),str(m["n"]),str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),
      str(rain),str(dt),str(horizon)],text=True,capture_output=True)
    lines=cp.stdout.splitlines()
    result=next((x for x in lines if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    states=[x for x in lines if x.startswith("F_PE_NLGLOB14F_STATE|")]
    retries=[x for x in lines if "RETRY" in x or "SATURATION_ROOT" in x or "ROOT" in x]
    rows.append({"route":route,"returncode":cp.returncode,"result_line":result,
                 "last_state_lines":states[-16:] if len(states)>=16 else states,
                 "diagnostic_tail":retries[-40:],
                 "stderr_tail":"\n".join(cp.stderr.splitlines()[-20:])})
print("F_PE_NLGLOB14Z1_FINE_DIAG="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z1_FINE_DIAG=PASS")
