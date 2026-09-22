from __future__ import annotations
import argparse, hashlib, json, math
from pathlib import Path

EXPECTED_STATES=768
EXPECTED_DISCOVERY_STRICT=475
NODES=16
DZ_CM=10.0
Z_CM=[-5.0-10.0*i for i in range(NODES)]
W_TOL_CM=1e-4
M1_MIN_CM=1e-2

STATE_ALLOWED={"SPLIT","HISTORY","STEP","T","FALLBACK"}
NODE_ALLOWED={"SPLIT","HISTORY","STEP","NODE","H","THETA"}

def extract(line:str, allowed:set[str]) -> dict[str,str]:
    out={}
    for token in line.rstrip("\n").split("|")[1:]:
        if "=" not in token:
            continue
        key,val=token.split("=",1)
        if key in allowed:
            out[key]=val
    return out

def sha256(path:Path)->str:
    h=hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda:f.read(1<<20),b""):
            h.update(chunk)
    return h.hexdigest()

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--artifact-dir",required=True)
    args=ap.parse_args()
    root=Path(args.artifact_dir)
    o0=root/"o0.txt"; o2=root/"o2.txt"
    if not o0.is_file() or not o2.is_file():
        raise SystemExit("missing ROM1AR2 authority logs")
    raw=o0.read_bytes()
    assert raw==o2.read_bytes(),"ROM1AR2 O0/O2 authority drift"

    state_meta={}
    node_rows={}
    all_state_lines=0
    heldout_node_observables_parsed=0

    for line in raw.decode("utf-8").splitlines():
        if line.startswith("ROM1AR2_STATE|"):
            all_state_lines+=1
            split=extract(line,{"SPLIT"}).get("SPLIT")
            if split!="DISCOVERY":
                continue
            m=extract(line,STATE_ALLOWED)
            assert set(m)==STATE_ALLOWED,m
            key=(m["HISTORY"],int(m["STEP"]))
            assert key not in state_meta
            state_meta[key]=m
        elif line.startswith("ROM1AR2_NODE|"):
            split=extract(line,{"SPLIT"}).get("SPLIT")
            if split!="DISCOVERY":
                continue
            m=extract(line,NODE_ALLOWED)
            assert set(m)==NODE_ALLOWED,m
            key=(m["HISTORY"],int(m["STEP"]))
            node=int(m["NODE"])
            assert 1<=node<=NODES
            node_rows.setdefault(key,{})[node]=(float(m["H"]),float(m["THETA"]))

    assert all_state_lines==EXPECTED_STATES,all_state_lines

    states=[]
    excluded_fallback=0
    for key,m in state_meta.items():
        if m["FALLBACK"]!="F":
            excluded_fallback+=1
            continue
        nodes=node_rows.get(key,{})
        assert len(nodes)==NODES,(key,len(nodes))
        h=[nodes[i][0] for i in range(1,NODES+1)]
        theta=[nodes[i][1] for i in range(1,NODES+1)]
        assert all(math.isfinite(x) for x in h+theta)
        w=math.fsum(theta[i]*DZ_CM for i in range(NODES))
        assert w>0.0 and math.isfinite(w)
        m1=math.fsum(theta[i]*DZ_CM*Z_CM[i] for i in range(NODES))/w
        upper30=math.fsum(theta[i]*DZ_CM for i in range(3))
        t=float(m["T"])
        assert math.isfinite(t)
        states.append({
          "split":"DISCOVERY","history":m["HISTORY"],"step":int(m["STEP"]),
          "original_time_text":m["T"],"original_time_day":t,
          "pressure_head_cm":h,"water_content":theta,
          "profile_water_cm":w,"distribution_moment_cm":m1,
          "upper_30cm_water_cm":upper30,
          "producing_interval_fallback":"F"
        })
    assert len(states)==EXPECTED_DISCOVERY_STRICT,len(states)
    states.sort(key=lambda s:(s["history"],s["step"]))

    candidate_pairs=0
    water_matched_pairs=0
    qualifying=[]
    best_water=None
    for i,a in enumerate(states):
        for b in states[i+1:]:
            if a["history"]==b["history"]:
                continue
            candidate_pairs+=1
            dw=abs(b["profile_water_cm"]-a["profile_water_cm"])
            dm=abs(b["distribution_moment_cm"]-a["distribution_moment_cm"])
            if dw<=W_TOL_CM:
                water_matched_pairs+=1
                rec=(dm,dw,a,b)
                if best_water is None or (dm,-dw)>(best_water[0],-best_water[1]):
                    best_water=rec
                if dm>=M1_MIN_CM:
                    qualifying.append(rec)

    qualifying.sort(key=lambda q:(
      -q[0],q[1],q[2]["history"],q[2]["step"],q[3]["history"],q[3]["step"]
    ))
    selected=None
    if qualifying:
        dm,dw,a,b=qualifying[0]
        selected={
          "A":a,"B":b,
          "abs_delta_profile_water_cm":dw,
          "abs_delta_distribution_moment_cm":dm,
          "abs_delta_upper_30cm_water_cm":abs(b["upper_30cm_water_cm"]-a["upper_30cm_water_cm"])
        }
        disposition="SELECTED_RESPONSE_BLIND_CROSS_TIME_H2_ORIGIN_PAIR"
    else:
        disposition="NO_MATCH"

    best_water_out=None
    if best_water is not None:
        dm,dw,a,b=best_water
        best_water_out={
          "A":{"history":a["history"],"step":a["step"],"original_time_day":a["original_time_day"]},
          "B":{"history":b["history"],"step":b["step"],"original_time_day":b["original_time_day"]},
          "abs_delta_profile_water_cm":dw,
          "abs_delta_distribution_moment_cm":dm,
          "fraction_of_required_M1_separation":dm/M1_MIN_CM
        }

    evidence={
      "schema":"swap5.gc_rootzone_memory.rzm06d03.cross_time_origin_selection.v1",
      "preregistration_commit":"c1f96aa01d07564c2166f1346ef383ec2357406a",
      "production_changes":False,
      "artifact_authority":{
        "workflow_run":35379176697,
        "artifact_id":10561841507,
        "artifact_digest":"sha256:2b04e188b7ce1593e073031fc43580550513e857dfb74b9993844a3230a1a67f",
        "o0_sha256":sha256(o0),"o2_sha256":sha256(o2),
        "o0_o2_byte_identity":True
      },
      "firewall":{
        "all_state_lines_seen":all_state_lines,
        "discovery_metadata_records":len(state_meta),
        "eligible_current_interval_fallback_false_records":len(states),
        "excluded_discovery_fallback_true_records":excluded_fallback,
        "heldout_node_observables_parsed":heldout_node_observables_parsed,
        "response_fields_parsed":False,
        "same_library_time_required":False,
        "different_history_required":True
      },
      "frozen_gate":{
        "max_abs_profile_water_difference_cm":W_TOL_CM,
        "min_abs_distribution_moment_difference_cm":M1_MIN_CM
      },
      "census":{
        "different_history_candidate_pairs":candidate_pairs,
        "water_matched_pairs":water_matched_pairs,
        "qualifying_pairs":len(qualifying),
        "best_water_matched_pair":best_water_out
      },
      "selected_pair":selected,
      "disposition":disposition,
      "common_time_reseed_authority":"GC-RZM06D02R1",
      "nonclaims":[
        "D03 performs no HeadCalc solve and no response probe",
        "D03 does not use HELD_OUT states",
        "FALLBACK=F classifies only the interval producing the retained state",
        "Selection alone does not support or falsify H2"
      ]
    }
    print("RZM06D03_SELECTION_JSON",json.dumps(evidence,sort_keys=True,separators=(",",":")))
    print("GC_RZM06D03_RESPONSE_BLIND_SELECTION=PASS")
    return 0

if __name__=="__main__":
    raise SystemExit(main())
