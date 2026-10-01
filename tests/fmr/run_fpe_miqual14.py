#!/usr/bin/env python3
import json,math,statistics,subprocess,sys,time

steps=20000
pairs_n=7
geometries={}
for spec in sys.argv[1:]:
    label,path=spec.split("=",1)
    geometries[label]=path

def run_case(exe,variant,emit=False):
    t0=time.perf_counter()
    cp=subprocess.run([exe,variant,"EQUILIBRIUM"],text=True,capture_output=True)
    wall=time.perf_counter()-t0
    if emit: print(cp.stdout,end="")
    if cp.returncode:
        if emit: print(cp.stderr,file=sys.stderr)
        return {"invalid":True,"wall":wall}
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_MIQUAL07_RESULT|")),None)
    hv=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_MIQUAL07_H=")),None)
    tv=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_MIQUAL07_TH=")),None)
    if not line or not hv or not tv: return {"invalid":True,"wall":wall}
    d={k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
    return {
      "variant":variant,"wall":wall,"complete":int(d["COMPLETE"])==1,
      "last_accepted":int(d["LAST_ACCEPTED"]),"cpu":float(d["CPU"]),
      "attempts":int(d["ATTEMPTS"]),"retries":int(d["RETRIES"]),
      "work":int(d["WORK"]),"reduced":int(d["REDUCED"]),
      "fallback":int(d["FALLBACK"]),"bypass":int(d["BYPASS"]),
      "max_mass":float(d["MAX_MASS"]),"storage":float(d["STORAGE"]),
      "tail":int(d["TAIL"]),"last_reason":d["LAST_REASON"],
      "h":[float(x) for x in hv.split("=",1)[1].split(",")],
      "theta":[float(x) for x in tv.split("=",1)[1].split(",")],
    }

def compare(a,b):
    return {
      "max_hdiff":max(abs(x-y) for x,y in zip(a["h"],b["h"])),
      "max_tdiff":max(abs(x-y) for x,y in zip(a["theta"],b["theta"])),
      "storage_diff":abs(a["storage"]-b["storage"]),
      "tail_diff":abs(a["tail"]-b["tail"]),
    }

summary={}
aggregate="QUALIFIED_MIQUAL14_SERIALIZED_SCALE_CROSSOVER"
for label in ("N16","N32","N64"):
    exe=geometries[label]
    L=run_case(exe,"LEGACY",emit=True)
    M=run_case(exe,"MANAGER",emit=True)
    if L.get("invalid") or M.get("invalid"):
        aggregate="MIQUAL14_EXECUTION_INVALID"; summary[label]={"preflight":[L,M]}; break
    cmp=compare(L,M)
    physical=(L["complete"] and M["complete"] and L["last_accepted"]==steps and M["last_accepted"]==steps and
              L["retries"]==0 and M["retries"]==0 and L["max_mass"]<=1e-8 and M["max_mass"]<=1e-8 and
              cmp["max_hdiff"]<=1e-12 and cmp["max_tdiff"]<=1e-12 and cmp["storage_diff"]<=1e-12 and cmp["tail_diff"]==0)
    route=(M["reduced"]==steps and M["fallback"]==0 and M["bypass"]==0 and M["last_reason"]=="none")
    if not physical:
        aggregate="MIQUAL14_PHYSICAL_MISMATCH"; summary[label]={"preflight":[L,M],"comparison":cmp}; break
    if not route:
        aggregate="MIQUAL14_MANAGER_ROUTE_FAILURE"; summary[label]={"preflight":[L,M],"comparison":cmp}; break

    for v in ("LEGACY","MANAGER"):
        w=run_case(exe,v)
        if w.get("invalid") or not w["complete"]:
            aggregate="MIQUAL14_EXECUTION_INVALID"; break
    if aggregate!="QUALIFIED_MIQUAL14_SERIALIZED_SCALE_CROSSOVER": break

    pairs=[]
    for p in range(1,pairs_n+1):
        order=("LEGACY","MANAGER") if p%2 else ("MANAGER","LEGACY")
        rr={v:run_case(exe,v) for v in order}
        if any(x.get("invalid") or not x["complete"] for x in rr.values()):
            aggregate="MIQUAL14_EXECUTION_INVALID"; break
        cc=compare(rr["LEGACY"],rr["MANAGER"])
        if cc["max_hdiff"]>1e-12 or cc["max_tdiff"]>1e-12 or cc["storage_diff"]>1e-12 or cc["tail_diff"]!=0:
            aggregate="MIQUAL14_PHYSICAL_MISMATCH"; break
        pairs.append({
          "pair":p,
          "wall_ratio":rr["MANAGER"]["wall"]/rr["LEGACY"]["wall"],
          "cpu_ratio":rr["MANAGER"]["cpu"]/rr["LEGACY"]["cpu"],
          "work_ratio":rr["MANAGER"]["work"]/rr["LEGACY"]["work"],
          "legacy_wall":rr["LEGACY"]["wall"],"manager_wall":rr["MANAGER"]["wall"]
        })
    if aggregate!="QUALIFIED_MIQUAL14_SERIALIZED_SCALE_CROSSOVER": break
    summary[label]={
      "preflight":[L,M],"comparison":cmp,"pairs":pairs,
      "median_wall_ratio":statistics.median(x["wall_ratio"] for x in pairs),
      "geomean_wall_ratio":math.exp(sum(math.log(x["wall_ratio"]) for x in pairs)/len(pairs)),
      "median_cpu_ratio":statistics.median(x["cpu_ratio"] for x in pairs),
      "deterministic_work_ratio":pairs[0]["work_ratio"]
    }

if aggregate=="QUALIFIED_MIQUAL14_SERIALIZED_SCALE_CROSSOVER":
    s=summary["N64"]
    if not (s["median_wall_ratio"]<0.99 and s["median_cpu_ratio"]<0.99 and s["deterministic_work_ratio"]<0.85):
        aggregate="MIQUAL14_NO_SCALE_CROSSOVER_TO_N64"

print("F_PE_MIQUAL14_SUMMARY="+json.dumps({"aggregate":aggregate,"geometries":summary},separators=(",",":"),sort_keys=True))
print("F_PE_MIQUAL14_GATE=PASS")
