#!/usr/bin/env python3
import json,math,statistics,subprocess,sys,time

exe=sys.argv[1]

def run_case(variant,emit=True):
    t0=time.perf_counter()
    cp=subprocess.run([exe,variant,"EQUILIBRIUM"],text=True,capture_output=True)
    wall=time.perf_counter()-t0
    if emit: print(cp.stdout,end="")
    if cp.returncode:
        if emit: print(cp.stderr,file=sys.stderr)
        return {"execution_invalid":True,"wall":wall}
    line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_MIQUAL07_RESULT|")),None)
    hv=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_MIQUAL07_H=")),None)
    tv=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_MIQUAL07_TH=")),None)
    if not line or not hv or not tv:
        return {"execution_invalid":True,"wall":wall}
    d={k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}
    return {
      "variant":variant,"wall":wall,
      "complete":int(d["COMPLETE"])==1,"last_accepted":int(d["LAST_ACCEPTED"]),
      "fail_reason":d["FAIL_REASON"],"cpu":float(d["CPU"]),"attempts":int(d["ATTEMPTS"]),
      "retries":int(d["RETRIES"]),"nl":int(d["NL"]),"jac":int(d["JAC"]),
      "lin":int(d["LIN"]),"back":int(d["BACK"]),"work":int(d["WORK"]),
      "reduced":int(d["REDUCED"]),"fallback":int(d["FALLBACK"]),"bypass":int(d["BYPASS"]),
      "max_mass":float(d["MAX_MASS"]),"storage":float(d["STORAGE"]),"pond":float(d["POND"]),
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

L=run_case("LEGACY"); M=run_case("MANAGER")
if L.get("execution_invalid") or M.get("execution_invalid"):
    agg="MIQUAL09_EXECUTION_INVALID"
    out={"aggregate":agg,"preflight":[L,M]}
else:
    cmp=compare(L,M)
    physical_ok=(L["complete"] and M["complete"] and L["last_accepted"]==40000 and M["last_accepted"]==40000 and
                 L["retries"]==0 and M["retries"]==0 and L["max_mass"]<=1e-8 and M["max_mass"]<=1e-8 and
                 cmp["max_hdiff"]<=1e-12 and cmp["max_tdiff"]<=1e-12 and cmp["storage_diff"]<=1e-12 and cmp["tail_diff"]==0)
    route_ok=(M["reduced"]==40000 and M["fallback"]==0 and M["bypass"]==0 and M["last_reason"]=="none")
    if not physical_ok:
        agg="MIQUAL09_PHYSICAL_MISMATCH"
        out={"aggregate":agg,"preflight":[L,M],"comparison":cmp}
    elif not route_ok:
        agg="MIQUAL09_MANAGER_ROUTE_FAILURE"
        out={"aggregate":agg,"preflight":[L,M],"comparison":cmp}
    else:
        # warmups
        for v in ("LEGACY","MANAGER"):
            r=run_case(v,emit=False)
            if r.get("execution_invalid") or not r["complete"]:
                print("F_PE_MIQUAL09_SUMMARY="+json.dumps({"aggregate":"MIQUAL09_EXECUTION_INVALID"},separators=(",",":")))
                print("F_PE_MIQUAL09_GATE=PASS")
                raise SystemExit
        pairs=[]
        invalid=False
        for p in range(1,12):
            order=("LEGACY","MANAGER") if p%2 else ("MANAGER","LEGACY")
            rr={}
            for v in order:
                rr[v]=run_case(v,emit=False)
            if any(x.get("execution_invalid") or not x["complete"] for x in rr.values()):
                invalid=True; break
            cc=compare(rr["LEGACY"],rr["MANAGER"])
            if cc["max_hdiff"]>1e-12 or cc["max_tdiff"]>1e-12 or cc["storage_diff"]>1e-12 or cc["tail_diff"]!=0:
                agg="MIQUAL09_PHYSICAL_MISMATCH"; invalid=True; break
            pairs.append({
              "pair":p,
              "legacy_wall":rr["LEGACY"]["wall"],"manager_wall":rr["MANAGER"]["wall"],
              "wall_ratio":rr["MANAGER"]["wall"]/rr["LEGACY"]["wall"],
              "legacy_cpu":rr["LEGACY"]["cpu"],"manager_cpu":rr["MANAGER"]["cpu"],
              "cpu_ratio":rr["MANAGER"]["cpu"]/rr["LEGACY"]["cpu"],
              "legacy_work":rr["LEGACY"]["work"],"manager_work":rr["MANAGER"]["work"],
              "work_ratio":rr["MANAGER"]["work"]/rr["LEGACY"]["work"],
            })
        if invalid and 'agg' not in locals():
            agg="MIQUAL09_EXECUTION_INVALID"
        if not invalid:
            median_wall=statistics.median(x["wall_ratio"] for x in pairs)
            gm_wall=math.exp(sum(math.log(x["wall_ratio"]) for x in pairs)/len(pairs))
            median_cpu=statistics.median(x["cpu_ratio"] for x in pairs)
            work_ratio=pairs[0]["work_ratio"]
            if median_wall<0.99 and gm_wall<0.99 and median_cpu<0.99 and work_ratio<0.90:
                agg="QUALIFIED_MIQUAL09_EQUILIBRIUM_RUNTIME_GAIN"
            else:
                agg="MIQUAL09_EQUILIBRIUM_PERFORMANCE_NOT_READY"
            out={"aggregate":agg,"preflight":[L,M],"comparison":cmp,"pairs":pairs,
                 "median_wall_ratio":median_wall,"geomean_wall_ratio":gm_wall,
                 "median_cpu_ratio":median_cpu,"deterministic_work_ratio":work_ratio}
        else:
            out={"aggregate":agg,"preflight":[L,M],"comparison":cmp,"pairs":pairs}

print("F_PE_MIQUAL09_SUMMARY="+json.dumps(out,separators=(",",":"),sort_keys=True))
print("F_PE_MIQUAL09_GATE=PASS")
