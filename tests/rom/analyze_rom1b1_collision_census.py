#!/usr/bin/env python3
from __future__ import annotations
import argparse,hashlib,json,math,pathlib

EPS=0.0005420462931603476
COORDS=("Z1","Z2","Z4","Z8","Z16")

def fields(s):
    out={}
    for part in s.split("|"):
        if "=" in part:
            k,v=part.split("=",1); out[k]=v
    return out

def coord(theta,kind):
    if kind=="Z1":
        return [sum(theta)/16.0]
    if kind=="Z2":
        return [sum(theta[0:4])/4.0,sum(theta[4:16])/12.0]
    if kind=="Z4":
        return [sum(theta[i:i+4])/4.0 for i in (0,4,8,12)]
    if kind=="Z8":
        return [sum(theta[i:i+2])/2.0 for i in range(0,16,2)]
    if kind=="Z16":
        return list(theta)
    raise ValueError(kind)

def linf(a,b):
    return max(abs(x-y) for x,y in zip(a,b))

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True)
    ap.add_argument("--repeat",required=True)
    ap.add_argument("--output",required=True)
    args=ap.parse_args()
    raw=pathlib.Path(args.input).read_text()
    repeat=pathlib.Path(args.repeat).read_text()
    repeat_identity=raw==repeat

    states={}
    nodes={}
    for line in raw.splitlines():
        if "ROM1AR1D3_STATE|" in line:
            r=fields(line.split("ROM1AR1D3_STATE|",1)[1])
            if r.get("SPLIT","").strip()!="DISCOVERY":
                raise SystemExit("non-discovery state in B1 generator")
            key=(r["HISTORY"],int(r["STEP"]))
            states[key]=r
        elif "ROM1AR1D3_NODE|" in line:
            r=fields(line.split("ROM1AR1D3_NODE|",1)[1])
            if r.get("SPLIT","").strip()!="DISCOVERY":
                raise SystemExit("non-discovery node in B1 generator")
            key=(r["HISTORY"],int(r["STEP"]))
            nodes.setdefault(key,{})[int(r["NODE"])]=(float(r["H"]),float(r["THETA"]))

    expected={(f"D{i:02d}",s) for i in range(1,9) for s in range(1,65)}
    structure=(set(states)==expected and set(nodes)==expected and
               all(set(nodes[k])==set(range(1,17)) for k in expected))
    if not structure:
        raise SystemExit("B1 discovery structure mismatch")

    rec=[]
    for key in sorted(expected):
        prof=[nodes[key][i][1] for i in range(1,17)]
        head=[nodes[key][i][0] for i in range(1,17)]
        rec.append({"key":key,"theta":prof,"head":head,
                    "coords":{z:coord(prof,z) for z in COORDS}})

    pairs=[]
    for i,a in enumerate(rec):
        for b in rec[i+1:]:
            if a["key"][0]==b["key"][0]:
                continue
            full_theta=linf(a["theta"],b["theta"])
            full_head=linf(a["head"],b["head"])
            pairs.append((a,b,full_theta,full_head))
    eligible_count=len(pairs)

    results={}
    first_zero=None
    manifests={}
    for z in COORDS:
        collisions=[]
        min_dist=math.inf
        for a,b,full_theta,full_head in pairs:
            d=linf(a["coords"][z],b["coords"][z])
            min_dist=min(min_dist,d)
            if d<=EPS and full_theta>EPS:
                collisions.append((d,-full_theta,a["key"],b["key"],full_theta,full_head))
        collisions.sort(key=lambda x:(x[0],x[1],x[2][0],x[2][1],x[3][0],x[3][1]))
        top=[]
        for d,neg_full,ka,kb,full_theta,full_head in collisions[:8]:
            top.append({
              "a":{"history":ka[0],"step":ka[1]},
              "b":{"history":kb[0],"step":kb[1]},
              "coordinate_linf":d,
              "full_theta_linf":full_theta,
              "full_head_linf_cm":full_head,
            })
        manifests[z]=top
        max_hidden=max((x[4] for x in collisions),default=0.0)
        results[z]={
          "dimension":int(z[1:]),
          "minimum_cross_history_coordinate_linf":min_dist,
          "collision_count":len(collisions),
          "maximum_full_theta_linf_among_collisions":max_hidden,
          "top_collision_pairs":top,
        }
        if first_zero is None and len(collisions)==0:
            first_zero=z

    # Z16 is a self-consistency control: its coordinate distance is exactly the
    # full-theta L_inf distance, so the preregistered collision predicate must
    # yield zero collisions.
    z16_control=(results["Z16"]["collision_count"]==0)
    complete=(repeat_identity and structure and eligible_count>0 and z16_control)
    decision="ROM1B1_COLLISION_CENSUS_COMPLETE" if complete else "ROM1B1_COLLISION_CENSUS_BLOCKED"
    result={
      "schema":"swap5.rom1b1.result.v1",
      "work_unit":"ROM-1B1",
      "decision":decision,
      "repeat_stdout_bitwise_identity":repeat_identity,
      "discovery_state_count":len(rec),
      "eligible_cross_history_pair_count":eligible_count,
      "theta_collision_floor":EPS,
      "coordinate_results":results,
      "first_coordinate_with_zero_discovery_collisions":first_zero,
      "Z16_full_state_control_pass":z16_control,
      "pair_manifests":manifests,
      "raw_discovery_sha256":hashlib.sha256(raw.encode()).hexdigest(),
      "heldout_used":False,
      "future_probe_outcomes_used":False,
      "B14_used":False,
      "coordinate_selected_final":False,
    }
    pathlib.Path(args.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    pathlib.Path(pathlib.Path(args.output).with_name("ROM1B1_PAIR_MANIFEST.json")).write_text(
      json.dumps({"schema":"swap5.rom1b1.pair-manifest.v1","theta_collision_floor":EPS,
                  "manifests":manifests},indent=2,sort_keys=True)+"\n")
    print(json.dumps(result,sort_keys=True))
    return 0 if complete else 2

if __name__=="__main__":
    raise SystemExit(main())
