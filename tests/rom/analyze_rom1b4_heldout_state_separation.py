#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, math, pathlib

EPS=0.0005420462931603476
DISC={f"D{i:02d}" for i in range(1,9)}
HELD={f"H{i:02d}" for i in range(1,5)}

def fields(payload):
    out={}
    for p in payload.split("|"):
        if "=" in p:
            k,v=p.split("=",1); out[k]=v
    return out

def linf(a,b):
    return max(abs(x-y) for x,y in zip(a,b))

def candidate_norm(a,b):
    # Z8 means for all bands; G8 resolves the final 140-160 cm band exactly.
    d=0.0
    for i in range(7):
        ma=0.5*(a[2*i]+a[2*i+1])
        mb=0.5*(b[2*i]+b[2*i+1])
        d=max(d,abs(ma-mb))
    d=max(d,abs(a[14]-b[14]),abs(a[15]-b[15]))
    return d

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True)
    ap.add_argument("--repeat",required=True)
    ap.add_argument("--prereg",required=True)
    ap.add_argument("--output",required=True)
    args=ap.parse_args()

    raw=pathlib.Path(args.input).read_text()
    repeat=pathlib.Path(args.repeat).read_text()
    p=json.loads(pathlib.Path(args.prereg).read_text())
    repeat_identity=(raw==repeat)

    states={}
    nodes={}
    for line in raw.splitlines():
        if "ROM1AR2_STATE|" in line:
            r=fields(line.split("ROM1AR2_STATE|",1)[1])
            states[(r["HISTORY"],int(r["STEP"]))]=r
        elif "ROM1AR2_NODE|" in line:
            r=fields(line.split("ROM1AR2_NODE|",1)[1])
            key=(r["HISTORY"],int(r["STEP"]))
            nodes.setdefault(key,{})[int(r["NODE"])]=(float(r["H"]),float(r["THETA"]))

    expected={(h,s) for h in DISC|HELD for s in range(1,65)}
    structure=(set(states)==expected and set(nodes)==expected and
               all(set(nodes[k])==set(range(1,17)) for k in expected))
    if not structure:
        raise SystemExit("ROM1B4 library structure mismatch")

    profiles={k:[nodes[k][i][1] for i in range(1,17)] for k in expected}
    finite=all(all(math.isfinite(v) for v in prof) for prof in profiles.values())

    keys=sorted(expected)
    pair_count=0
    relevant_count=0
    collision_rows=[]
    min_candidate=math.inf
    min_margin=math.inf
    max_full=0.0
    max_hidden=0.0
    dh_count=0
    hh_count=0

    for ia,ka in enumerate(keys):
        for kb in keys[ia+1:]:
            if ka[0]==kb[0]:
                continue
            if ka[0] not in HELD and kb[0] not in HELD:
                continue
            pair_count+=1
            if (ka[0] in HELD) != (kb[0] in HELD):
                dh_count+=1
            else:
                hh_count+=1
            a=profiles[ka]; b=profiles[kb]
            full=linf(a,b)
            max_full=max(max_full,full)
            if full<=EPS:
                continue
            relevant_count+=1
            q=candidate_norm(a,b)
            min_candidate=min(min_candidate,q)
            min_margin=min(min_margin,q-EPS)
            if q<=EPS:
                max_hidden=max(max_hidden,full)
                collision_rows.append({
                  "a":{"history":ka[0],"step":ka[1]},
                  "b":{"history":kb[0],"step":kb[1]},
                  "candidate_induced_theta_linf":q,
                  "full_theta_linf":full,
                  "hidden_excess_over_theta_floor":full-EPS,
                })

    collision_rows.sort(key=lambda r:(
      r["candidate_induced_theta_linf"],
      -r["full_theta_linf"],
      r["a"]["history"],r["a"]["step"],r["b"]["history"],r["b"]["step"]))
    manifest=collision_rows[:8]
    collision_count=len(collision_rows)

    if collision_count==0:
        decision="ROM1B4_HELDOUT_STATE_SEPARATION_QUALIFIED"
    else:
        decision="ROM1B4_HELDOUT_STATE_SEPARATION_NO_GO"

    complete=(
      repeat_identity and structure and finite and pair_count==155648 and
      dh_count==131072 and hh_count==24576 and
      p["frozen_coordinate"]["theta_floor"]==EPS and
      p["firewalls"][0]=="NO_HELDOUT_DRIVEN_ENRICHMENT"
    )
    if not complete:
        decision="ROM1B4_EVIDENCE_BLOCKED"

    result={
      "schema":"swap5.rom1b4.result.v1","workstream":"F-ROM","work_unit":"ROM-1B4",
      "decision":decision,"repeat_stdout_bitwise_identity":repeat_identity,
      "library":{"state_count":len(states),"discovery_states":512,"heldout_states":256,
                 "finite_theta_profiles":finite},
      "pair_population":{
        "heldout_inclusive_cross_history_pair_count":pair_count,
        "discovery_heldout_pair_count":dh_count,
        "heldout_heldout_cross_history_pair_count":hh_count,
        "full_theta_distinguishable_pair_count":relevant_count
      },
      "frozen_coordinate":{"id":"Z8_PLUS_G8","dimension":9,"theta_floor":EPS},
      "collision_count":collision_count,
      "collision_manifest":manifest,
      "minimum_candidate_induced_theta_linf_over_full_distinguishable_pairs":min_candidate,
      "minimum_separation_margin_over_theta_floor":min_margin,
      "maximum_full_theta_linf":max_full,
      "maximum_hidden_full_theta_linf_among_collisions":max_hidden,
      "raw_library_sha256":hashlib.sha256(raw.encode()).hexdigest(),
      "coordinate_changed_from_discovery":False,
      "theta_floor_changed":False,
      "future_probe_outcomes_used":False,
      "B14_used":False,
      "heldout_driven_enrichment_allowed":False,
      "production_rom_authorized":False
    }
    pathlib.Path(args.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    pathlib.Path(pathlib.Path(args.output).with_name("ROM1B4_COLLISION_MANIFEST.json")).write_text(
      json.dumps({"schema":"swap5.rom1b4.collision-manifest.v1",
                  "coordinate":"Z8_PLUS_G8","theta_floor":EPS,
                  "collision_count":collision_count,"pairs":manifest},indent=2,sort_keys=True)+"\n")
    print(json.dumps(result,sort_keys=True))
    return 0 if complete else 2

if __name__=="__main__":
    raise SystemExit(main())
