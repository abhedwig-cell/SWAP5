from __future__ import annotations
import argparse
import itertools
import json
import math
from pathlib import Path

NODES=16
DZ_CM=10.0
Z_CM=[-5.0-10.0*i for i in range(NODES)]
W_TOL_CM=1e-4
ROOT30_TOL_CM=1e-4
M1_MIN_CM=1e-2
CANDIDATE_ALLOWED={"FAMILY","ORDER","N","STEPS","T"}
NODE_ALLOWED={"FAMILY","NODE","H","THETA"}


def extract(line:str, allowed:set[str])->dict[str,str]:
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
    meta={}
    nodes={}
    stops=[]
    for line in raw.decode("utf-8").splitlines():
        if line.startswith("RZM06E03B_CANDIDATE|"):
            f=extract(line,CANDIDATE_ALLOWED)
            assert set(f)==CANDIDATE_ALLOWED,f
            fam=f["FAMILY"]
            assert fam not in meta
            meta[fam]={
                "family":fam,
                "order":f["ORDER"],
                "n":int(f["N"]),
                "committed_steps":int(f["STEPS"]),
                "time_day":float(f["T"]),
            }
        elif line.startswith("RZM06E03B_NODE|"):
            f=extract(line,NODE_ALLOWED)
            assert set(f)==NODE_ALLOWED,f
            fam=f["FAMILY"]; node=int(f["NODE"])
            assert 1<=node<=NODES
            nodes.setdefault(fam,{})[node]=(float(f["H"]),float(f["THETA"]))
        elif line.startswith("RZM06E03B_STOP|"):
            stops.append(line)

    records=[]
    for fam,m in meta.items():
        ns=nodes.get(fam,{})
        assert len(ns)==NODES,(fam,len(ns))
        h=[ns[i][0] for i in range(1,NODES+1)]
        theta=[ns[i][1] for i in range(1,NODES+1)]
        assert all(math.isfinite(x) for x in h+theta)
        w=math.fsum(x*DZ_CM for x in theta)
        root=math.fsum(theta[i]*DZ_CM for i in range(3))
        m1=math.fsum(theta[i]*DZ_CM*Z_CM[i] for i in range(NODES))/w
        records.append({
            **m,
            "pressure_head_cm":h,
            "water_content":theta,
            "profile_water_cm":w,
            "root30_water_cm":root,
            "distribution_moment_cm":m1,
        })
    records.sort(key=lambda r:r["family"])
    return raw,records,stops


def metrics(a:dict,b:dict)->dict:
    return {
        "abs_delta_profile_water_cm":abs(b["profile_water_cm"]-a["profile_water_cm"]),
        "abs_delta_root30_water_cm":abs(b["root30_water_cm"]-a["root30_water_cm"]),
        "abs_delta_distribution_moment_cm":abs(b["distribution_moment_cm"]-a["distribution_moment_cm"]),
    }


def endpoint_summary(r:dict)->dict:
    return {
        "family":r["family"],
        "order":r["order"],
        "n":r["n"],
        "committed_steps":r["committed_steps"],
        "time_day":r["time_day"],
        "profile_water_cm":r["profile_water_cm"],
        "root30_water_cm":r["root30_water_cm"],
        "distribution_moment_cm":r["distribution_moment_cm"],
    }


def persisted_origin(r:dict)->dict:
    return {
        **endpoint_summary(r),
        "pressure_head_cm":r["pressure_head_cm"],
        "water_content":r["water_content"],
    }


def pair_summary(rec:dict|None):
    if rec is None:
        return None
    return {
        "A":endpoint_summary(rec["A"]),
        "B":endpoint_summary(rec["B"]),
        "abs_delta_profile_water_cm":rec["abs_delta_profile_water_cm"],
        "abs_delta_root30_water_cm":rec["abs_delta_root30_water_cm"],
        "abs_delta_distribution_moment_cm":rec["abs_delta_distribution_moment_cm"],
        "fraction_of_M1_requirement":rec["abs_delta_distribution_moment_cm"]/M1_MIN_CM,
    }


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--o0",required=True)
    ap.add_argument("--o2",required=True)
    args=ap.parse_args()
    raw0,records0,stops0=parse(Path(args.o0))
    raw2,records2,stops2=parse(Path(args.o2))
    assert raw0==raw2,"E03B O0/O2 output drift"
    assert records0==records2
    assert stops0==stops2

    base=[r for r in records0 if r["family"]=="BASE_EQ"]
    assert len(base)==1,len(base)
    split=[r for r in records0 if r["family"]!="BASE_EQ"]

    eligible=[]
    qualifying=[]
    water_matched=[]
    root_matched=[]
    for a,b in itertools.combinations(records0,2):
        if a["family"]==b["family"]:
            continue
        m=metrics(a,b)
        rec={"A":a,"B":b,**m}
        eligible.append(rec)
        if m["abs_delta_profile_water_cm"]<=W_TOL_CM:
            water_matched.append(rec)
            if m["abs_delta_root30_water_cm"]<=ROOT30_TOL_CM:
                root_matched.append(rec)
                if m["abs_delta_distribution_moment_cm"]>=M1_MIN_CM:
                    qualifying.append(rec)

    qualifying.sort(key=lambda r:(
        -r["abs_delta_distribution_moment_cm"],
        r["abs_delta_root30_water_cm"],
        r["abs_delta_profile_water_cm"],
        r["A"]["family"],
        r["B"]["family"],
    ))
    root_matched.sort(key=lambda r:(
        -r["abs_delta_distribution_moment_cm"],
        r["abs_delta_root30_water_cm"],
        r["abs_delta_profile_water_cm"],
    ))
    water_matched.sort(key=lambda r:(
        r["abs_delta_root30_water_cm"],
        -r["abs_delta_distribution_moment_cm"],
    ))

    selected=None
    disposition="NO_MATCH"
    if qualifying:
        q=qualifying[0]
        selected={
            "A":persisted_origin(q["A"]),
            "B":persisted_origin(q["B"]),
            "abs_delta_profile_water_cm":q["abs_delta_profile_water_cm"],
            "abs_delta_root30_water_cm":q["abs_delta_root30_water_cm"],
            "abs_delta_distribution_moment_cm":q["abs_delta_distribution_moment_cm"],
        }
        disposition="SELECTED_RESPONSE_BLIND_ROOTMATCHED_DEEP_MEMORY_PAIR"

    evidence={
        "schema":"swap5.gc_rootzone_memory.rzm06e03b.split_boundary_selection.v1",
        "preregistration_commit":"511b6f9fcf40702786ecb84bc5b253998db214aa",
        "production_changes":False,
        "firewall":{
            "response_fields_parsed":False,
            "external_library_used":False,
            "candidate_fields":sorted(CANDIDATE_ALLOWED),
            "node_fields":sorted(NODE_ALLOWED),
        },
        "generation":{
            "candidate_count":len(records0),
            "split_candidate_count":len(split),
            "candidate_families":[r["family"] for r in records0],
            "stop_records":stops0,
        },
        "frozen_gate":{
            "max_abs_profile_water_difference_cm":W_TOL_CM,
            "max_abs_root30_water_difference_cm":ROOT30_TOL_CM,
            "min_abs_distribution_moment_difference_cm":M1_MIN_CM,
        },
        "census":{
            "eligible_pairs":len(eligible),
            "profile_water_matched_pairs":len(water_matched),
            "profile_and_root30_matched_pairs":len(root_matched),
            "qualifying_pairs":len(qualifying),
            "best_rootmatched_pair":pair_summary(root_matched[0] if root_matched else None),
            "closest_root_pair_after_profile_gate":pair_summary(water_matched[0] if water_matched else None),
        },
        "selected_pair":selected,
        "disposition":disposition,
        "nonclaims":[
            "E03B performs no fixed-Hc response probe",
            "selection uses only committed pressure-head and water-content state",
            "selection alone does not establish deeper-profile response-memory causality",
        ],
    }
    print("RZM06E03B_SELECTION_JSON",json.dumps(evidence,sort_keys=True,separators=(",",":")))
    print("GC_RZM06E03B_RESPONSE_BLIND_SELECTION=PASS")
    return 0


if __name__=="__main__":
    raise SystemExit(main())
