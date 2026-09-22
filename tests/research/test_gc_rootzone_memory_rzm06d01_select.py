from __future__ import annotations
import argparse, hashlib, json, math, struct
from collections import defaultdict
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

def bits(x:float) -> bytes:
    return struct.pack(">d",x)

def sha256(path:Path) -> str:
    h=hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda:f.read(1<<20),b""):
            h.update(chunk)
    return h.hexdigest()

def main() -> int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--artifact-dir",required=True)
    args=ap.parse_args()
    root=Path(args.artifact_dir)
    o0=root/"o0.txt"; o2=root/"o2.txt"
    if not o0.is_file() or not o2.is_file():
        raise SystemExit("missing ROM1AR2 o0/o2 authority logs")
    b0=o0.read_bytes(); b2=o2.read_bytes()
    assert b0==b2,"ROM1AR2 O0/O2 authority drift"

    state_meta={}
    discovery_node_rows=defaultdict(dict)
    state_line_count=0
    heldout_node_observables_parsed=0

    for line in b0.decode("utf-8").splitlines():
        if line.startswith("ROM1AR2_STATE|"):
            state_line_count+=1
            split=extract(line,{"SPLIT"}).get("SPLIT")
            if split!="DISCOVERY":
                continue
            m=extract(line,STATE_ALLOWED)
            assert set(m)==STATE_ALLOWED,m
            key=(m["SPLIT"],m["HISTORY"],int(m["STEP"]))
            assert key not in state_meta
            state_meta[key]=m
        elif line.startswith("ROM1AR2_NODE|"):
            split=extract(line,{"SPLIT"}).get("SPLIT")
            if split!="DISCOVERY":
                # Deliberately do not parse H/THETA for HELD_OUT lines.
                continue
            m=extract(line,NODE_ALLOWED)
            assert set(m)==NODE_ALLOWED,m
            key=(m["SPLIT"],m["HISTORY"],int(m["STEP"]))
            node=int(m["NODE"])
            assert 1<=node<=NODES
            discovery_node_rows[key][node]=(float(m["H"]),float(m["THETA"]))

    assert state_line_count==EXPECTED_STATES,state_line_count

    states=[]
    for key,m in state_meta.items():
        if m["FALLBACK"]!="F":
            continue
        nodes=discovery_node_rows.get(key,{})
        assert len(nodes)==NODES,(key,len(nodes))
        h=[nodes[i][0] for i in range(1,NODES+1)]
        theta=[nodes[i][1] for i in range(1,NODES+1)]
        t=float(m["T"])
        assert math.isfinite(t)
        w=math.fsum(theta[i]*DZ_CM for i in range(NODES))
        assert w>0 and math.isfinite(w)
        m1=math.fsum(theta[i]*DZ_CM*Z_CM[i] for i in range(NODES))/w
        upper30=math.fsum(theta[i]*DZ_CM for i in range(3))
        states.append({
            "split":"DISCOVERY","history":m["HISTORY"],"step":int(m["STEP"]),
            "t_text":m["T"],"time_day":t,
            "pressure_head_cm":h,"water_content":theta,
            "profile_water_cm":w,"distribution_moment_cm":m1,
            "upper_30cm_water_cm":upper30,
        })

    assert len(states)==EXPECTED_DISCOVERY_STRICT,len(states)

    by_time=defaultdict(list)
    for s in states:
        by_time[s["t_text"]].append(s)

    candidate_pairs=0
    qualifying=[]
    for t_text,group in by_time.items():
        # Text identity is the primary equality gate; round-trip binary equality
        # is asserted as an independent representation check.
        t_values=[g["time_day"] for g in group]
        assert all(bits(x)==bits(t_values[0]) for x in t_values)
        ordered=sorted(group,key=lambda x:(x["history"],x["step"]))
        for i,a in enumerate(ordered):
            for b in ordered[i+1:]:
                if a["history"]==b["history"]:
                    continue
                candidate_pairs+=1
                dw=abs(b["profile_water_cm"]-a["profile_water_cm"])
                dm=abs(b["distribution_moment_cm"]-a["distribution_moment_cm"])
                if dw<=W_TOL_CM and dm>=M1_MIN_CM:
                    qualifying.append((dm,dw,a,b))

    selected=None
    if qualifying:
        qualifying.sort(key=lambda q:(
            -q[0],q[1],
            q[2]["history"],q[2]["step"],q[3]["history"],q[3]["step"]
        ))
        dm,dw,a,b=qualifying[0]
        selected={
            "A":a,"B":b,
            "abs_delta_profile_water_cm":dw,
            "abs_delta_distribution_moment_cm":dm,
        }
        disposition="SELECTED_RESPONSE_BLIND_H2_ORIGIN_PAIR"
    else:
        disposition="NO_MATCH"

    evidence={
        "schema":"swap5.gc_rootzone_memory.rzm06d01.rom_library_h2_origin_selection.v1",
        "preregistration_commit":"2af534f0455ceb121f9a7965d1fe9f92895b3e4d",
        "library_authority":{
            "workflow_run":35379176697,
            "artifact_id":10561841507,
            "artifact_digest":"sha256:2b04e188b7ce1593e073031fc43580550513e857dfb74b9993844a3230a1a67f",
            "o0_sha256":sha256(o0),
            "o2_sha256":sha256(o2),
            "o0_o2_byte_identity":True,
        },
        "selector":{
            "discovery_strict_states":len(states),
            "heldout_node_observables_parsed":heldout_node_observables_parsed,
            "same_time_different_history_candidate_pairs":candidate_pairs,
            "qualifying_pairs":len(qualifying),
            "profile_water_tolerance_cm":W_TOL_CM,
            "distribution_moment_min_separation_cm":M1_MIN_CM,
            "response_fields_parsed":False,
        },
        "selected_pair":selected,
        "disposition":disposition,
        "nonclaims":[
            "D01 performs no HeadCalc solve and no response probe",
            "D01 does not support or falsify H2 by itself",
            "HELD_OUT and FALLBACK=T states are excluded",
        ],
    }
    print("RZM06D01_SELECTION_JSON",json.dumps(evidence,sort_keys=True,separators=(",",":")))
    print("GC_RZM06D01_RESPONSE_BLIND_SELECTION=PASS")
    return 0

if __name__=="__main__":
    raise SystemExit(main())
