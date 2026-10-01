#!/usr/bin/env python3
import json,math,statistics,subprocess,sys,time

specs={}
for item in sys.argv[1:]:
    label,exe=item.split("=",1); specs[label]=exe
expected=["N16_T13","N32_T25","N64_T49"]
if sorted(specs)!=sorted(expected):
    raise SystemExit(f"expected {expected}, got {sorted(specs)}")

def run(exe,variant,emit=False):
    t0=time.perf_counter()
    cp=subprocess.run([exe,variant,"EQUILIBRIUM"],text=True,capture_output=True)
    wall=time.perf_counter()-t0
    if emit: print(cp.stdout,end="")
    if cp.returncode: return {"invalid":True,"wall":wall}
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_MIQUAL07_RESULT|")),None)
    hv=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_MIQUAL07_H=")),None)
    tv=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_MIQUAL07_TH=")),None)
    if not line or not hv or not tv: return {"invalid":True,"wall":wall}
    d={k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
    return {
      "invalid":False,"wall":wall,"complete":int(d["COMPLETE"])==1,
      "last_accepted":int(d["LAST_ACCEPTED"]),"cpu":float(d["CPU"]),
      "retries":int(d["RETRIES"]),"work":int(d["WORK"]),
      "reduced":int(d["REDUCED"]),"fallback":int(d["FALLBACK"]),"bypass":int(d["BYPASS"]),
      "max_mass":float(d["MAX_MASS"]),"storage":float(d["STORAGE"]),"tail":int(d["TAIL"]),
      "h":[float(x) for x in hv.split("=",1)[1].split(",")],
      "theta":[float(x) for x in tv.split("=",1)[1].split(",")],
    }

def cmp(a,b):
    return max(abs(x-y) for x,y in zip(a["h"],b["h"])), max(abs(x-y) for x,y in zip(a["theta"],b["theta"])), abs(a["storage"]-b["storage"])

out={"geometries":{}}
any_gain=False
semantic_fail=False
execution_invalid=False
for label in expected:
    exe=specs[label]
    L=run(exe,"LEGACY",True); M=run(exe,"MANAGER",True)
    if L["invalid"] or M["invalid"]:
        execution_invalid=True; out["geometries"][label]={"status":"EXECUTION_INVALID"}; continue
    hd,td,sd=cmp(L,M)
    nsteps=40000
    physical=(L["complete"] and M["complete"] and L["last_accepted"]==nsteps and M["last_accepted"]==nsteps and
              L["retries"]==0 and M["retries"]==0 and L["max_mass"]<=1e-8 and M["max_mass"]<=1e-8 and
              hd<=1e-12 and td<=1e-12 and sd<=1e-12 and L["tail"]==M["tail"])
    route=(M["reduced"]==nsteps and M["fallback"]==0 and M["bypass"]==0)
    if not physical or not route:
        semantic_fail=True; out["geometries"][label]={"status":"SEMANTIC_FAIL","preflight":[L,M],"hd":hd,"td":td,"sd":sd}; continue
    for v in ("LEGACY","MANAGER"):
        w=run(exe,v)
        if w["invalid"] or not w["complete"]: execution_invalid=True
    pairs=[]
    if execution_invalid: break
    for p in range(1,8):
        order=("LEGACY","MANAGER") if p%2 else ("MANAGER","LEGACY")
        rr={v:run(exe,v) for v in order}
        if any(x["invalid"] or not x["complete"] for x in rr.values()):
            execution_invalid=True; break
        hd,td,sd=cmp(rr["LEGACY"],rr["MANAGER"])
        if hd>1e-12 or td>1e-12 or sd>1e-12:
            semantic_fail=True; break
        pairs.append({
          "pair":p,
          "wall_ratio":rr["MANAGER"]["wall"]/rr["LEGACY"]["wall"],
          "cpu_ratio":rr["MANAGER"]["cpu"]/rr["LEGACY"]["cpu"],
          "work_ratio":rr["MANAGER"]["work"]/rr["LEGACY"]["work"],
          "legacy_wall":rr["LEGACY"]["wall"],"manager_wall":rr["MANAGER"]["wall"]
        })
    if execution_invalid or semantic_fail: break
    medw=statistics.median(x["wall_ratio"] for x in pairs)
    gmw=math.exp(sum(math.log(x["wall_ratio"]) for x in pairs)/len(pairs))
    medc=statistics.median(x["cpu_ratio"] for x in pairs)
    wr=pairs[0]["work_ratio"]
    gain=medw<1.0 and medc<1.0
    if label!="N16_T13" and gain: any_gain=True
    out["geometries"][label]={"status":"GAIN" if gain else "NO_GAIN","pairs":pairs,
       "median_wall_ratio":medw,"geomean_wall_ratio":gmw,"median_cpu_ratio":medc,
       "deterministic_work_ratio":wr,"preflight":[L,M]}

if execution_invalid: agg="MIQUAL14_EXECUTION_INVALID"
elif semantic_fail: agg="MIQUAL14_PHYSICAL_OR_ROUTE_FAILURE"
elif any_gain: agg="QUALIFIED_MIQUAL14_BREAK_EVEN_REACHED"
else: agg="MIQUAL14_NO_BREAK_EVEN_IN_TESTED_RANGE"
out["aggregate"]=agg
print("F_PE_MIQUAL14_RESULT="+json.dumps(out,separators=(",",":"),sort_keys=True))
print("F_PE_MIQUAL14_GATE=PASS")
