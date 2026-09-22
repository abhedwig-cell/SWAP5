from __future__ import annotations
import argparse, json, math
from pathlib import Path

NODES=16
DZ_CM=10.0
Z_CM=[-5.0-10.0*i for i in range(NODES)]
W_TOL_CM=1e-4
M1_MIN_CM=1e-2

STATE_ALLOWED={"FAMILY","STEP","T"}
NODE_ALLOWED={"FAMILY","STEP","NODE","H","THETA"}

def extract(line:str,allowed:set[str])->dict[str,str]:
    out={}
    for token in line.rstrip("\n").split("|")[1:]:
        if "=" not in token:
            continue
        k,v=token.split("=",1)
        if k in allowed:
            out[k]=v
    return out

def parse(path:Path):
    raw=path.read_bytes()
    states={}
    nodes={}
    stop=None
    for line in raw.decode("utf-8").splitlines():
        if line.startswith("RZM06E01_STATE|"):
            m=extract(line,STATE_ALLOWED)
            assert set(m)==STATE_ALLOWED,m
            key=(m["FAMILY"],int(m["STEP"]))
            assert key not in states
            states[key]={"family":m["FAMILY"],"step":int(m["STEP"]),"time_day":float(m["T"])}
        elif line.startswith("RZM06E01_NODE|"):
            m=extract(line,NODE_ALLOWED)
            assert set(m)==NODE_ALLOWED,m
            key=(m["FAMILY"],int(m["STEP"]))
            node=int(m["NODE"])
            assert 1<=node<=NODES
            nodes.setdefault(key,{})[node]=(float(m["H"]),float(m["THETA"]))
        elif line.startswith("RZM06E01_STOP|"):
            stop=line
    records=[]
    for key,meta in states.items():
        ns=nodes.get(key,{})
        assert len(ns)==NODES,(key,len(ns))
        h=[ns[i][0] for i in range(1,NODES+1)]
        theta=[ns[i][1] for i in range(1,NODES+1)]
        assert all(math.isfinite(x) for x in h+theta)
        w=math.fsum(theta[i]*DZ_CM for i in range(NODES))
        m1=math.fsum(theta[i]*DZ_CM*Z_CM[i] for i in range(NODES))/w
        upper=math.fsum(theta[i]*DZ_CM for i in range(3))
        records.append({
            **meta,
            "pressure_head_cm":h,
            "water_content":theta,
            "profile_water_cm":w,
            "distribution_moment_cm":m1,
            "upper_30cm_water_cm":upper
        })
    records.sort(key=lambda r:(r["family"],r["step"]))
    return raw,records,stop

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--o0",required=True)
    ap.add_argument("--o2",required=True)
    args=ap.parse_args()
    raw0,records0,stop0=parse(Path(args.o0))
    raw2,records2,stop2=parse(Path(args.o2))
    assert raw0==raw2,"E01 O0/O2 output drift"
    assert records0==records2
    assert stop0==stop2

    eq=[r for r in records0 if r["family"]=="EQ"]
    closed=[r for r in records0 if r["family"]=="CLOSED"]
    assert len(eq)==1,len(eq)
    assert len(closed)>=1,len(closed)
    control=eq[0]

    qualifying=[]
    best=None
    for cand in closed:
        dw=abs(cand["profile_water_cm"]-control["profile_water_cm"])
        dm=abs(cand["distribution_moment_cm"]-control["distribution_moment_cm"])
        rec=(dm,dw,cand["step"],cand)
        if best is None or (dm,-dw,-cand["step"])>(best[0],-best[1],-best[2]):
            best=rec
        if dw<=W_TOL_CM and dm>=M1_MIN_CM:
            qualifying.append(rec)

    qualifying.sort(key=lambda x:(-x[0],x[1],x[2]))
    selected=None
    disposition="NO_MATCH"
    if qualifying:
        dm,dw,_,cand=qualifying[0]
        selected={
            "A_EQ":control,
            "B_CLOSED":cand,
            "abs_delta_profile_water_cm":dw,
            "abs_delta_distribution_moment_cm":dm,
            "abs_delta_upper_30cm_water_cm":abs(cand["upper_30cm_water_cm"]-control["upper_30cm_water_cm"])
        }
        disposition="SELECTED_RESPONSE_BLIND_ZERO_DIVERGENCE_H2_ORIGIN_PAIR"

    best_out=None
    if best is not None:
        dm,dw,_,cand=best
        best_out={
            "closed_step":cand["step"],
            "closed_time_day":cand["time_day"],
            "abs_delta_profile_water_cm":dw,
            "abs_delta_distribution_moment_cm":dm,
            "fraction_of_required_M1_separation":dm/M1_MIN_CM
        }

    evidence={
        "schema":"swap5.gc_rootzone_memory.rzm06e01.zero_divergence_state_expansion.v1",
        "preregistration_commit":"c11c08282a3abc9b1beee3002f5a9a01df58d95f",
        "production_changes":False,
        "firewall":{
            "response_fields_parsed":False,
            "external_library_used":False,
            "state_fields":["FAMILY","STEP","T"],
            "node_fields":["FAMILY","STEP","NODE","H","THETA"]
        },
        "generation":{
            "eq_states":len(eq),
            "closed_accepted_states":len(closed),
            "closed_stop_record":stop0
        },
        "frozen_gate":{
            "max_abs_profile_water_difference_cm":W_TOL_CM,
            "min_abs_distribution_moment_difference_cm":M1_MIN_CM
        },
        "census":{
            "candidate_pairs":len(closed),
            "qualifying_pairs":len(qualifying),
            "best_pair":best_out
        },
        "selected_pair":selected,
        "disposition":disposition,
        "nonclaims":[
            "E01 performs no mode-5 fixed-Hc response probe",
            "selection uses only committed H/theta state",
            "selection alone does not support or falsify H2"
        ]
    }
    print("RZM06E01_SELECTION_JSON",json.dumps(evidence,sort_keys=True,separators=(",",":")))
    print("GC_RZM06E01_RESPONSE_BLIND_SELECTION=PASS")
    return 0

if __name__=="__main__":
    raise SystemExit(main())
