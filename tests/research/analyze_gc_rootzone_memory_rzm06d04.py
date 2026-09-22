from __future__ import annotations
import argparse, json, math
from pathlib import Path

NODES=16
DZ_CM=10.0
Z_CM=[-5.0-10.0*i for i in range(NODES)]
W_TOL_CM=1e-4
M1_MIN_CM=1e-2

def fields(line):
    out={}
    for token in line.strip().split("|")[1:]:
        if "=" in token:
            k,v=token.split("=",1)
            out[k]=v
    return out

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True)
    ap.add_argument("--output",required=True)
    args=ap.parse_args()
    endpoints={}
    nodes={}
    rejects=[]
    for raw in Path(args.input).read_text().splitlines():
        if raw.startswith("RZM06D04_ENDPOINT|"):
            m=fields(raw)
            key=(m["ORIGIN"],int(m["CRANK"]),int(m["DIDX"]))
            assert key not in endpoints,key
            endpoints[key]={
              "origin":m["ORIGIN"],"control":m["CONTROL"],
              "control_rank":int(m["CRANK"]),"duration_index":int(m["DIDX"]),
              "duration_day":float(m["DT"]),
              "mass_residual_cm":float(m["MASS"]),
              "nonlinear_iterations":int(m["NL"]),
              "backtracking_attempts":int(m["BACKTRACK"])
            }
        elif raw.startswith("RZM06D04_NODE|"):
            m=fields(raw)
            key=(m["ORIGIN"],int(m["CRANK"]),int(m["DIDX"]))
            nodes.setdefault(key,{})[int(m["NODE"])]=(float(m["H"]),float(m["THETA"]))
        elif raw.startswith("RZM06D04_REJECT|"):
            m=fields(raw)
            rejects.append({
              "origin":m["ORIGIN"],"control":m["CONTROL"],"control_rank":int(m["CRANK"]),
              "duration_index":int(m["DIDX"]),"duration_day":float(m["DT"]),
              "result_status":int(m["RESULT_STATUS"]),"physical_advances":int(m["PHYSICAL_ADVANCES"]),
              "transaction_retries":int(m["TX_RETRIES"]),"solver_rejections":int(m["SOLVER_REJECTIONS"]),
              "mass_rejections":int(m["MASS_REJECTIONS"]),"mass_complete":m["MASS_COMPLETE"],
              "mass_residual_cm":float(m["MASS_RESIDUAL"]),
              "nonlinear_iterations":int(m["NL"]),"backtracking_attempts":int(m["BACKTRACK"])
            })

    for key,e in endpoints.items():
        ns=nodes.get(key,{})
        assert len(ns)==NODES,(key,len(ns))
        h=[ns[i][0] for i in range(1,NODES+1)]
        theta=[ns[i][1] for i in range(1,NODES+1)]
        assert all(math.isfinite(x) for x in h+theta)
        w=math.fsum(theta[i]*DZ_CM for i in range(NODES))
        weighted=math.fsum(theta[i]*DZ_CM*Z_CM[i] for i in range(NODES))
        assert w>0.0 and math.isfinite(weighted)
        e["pressure_head_cm"]=h
        e["water_content"]=theta
        e["profile_water_cm"]=w
        e["distribution_moment_cm"]=weighted/w
        e["upper_30cm_water_cm"]=math.fsum(theta[i]*DZ_CM for i in range(3))

    A=sorted([e for e in endpoints.values() if e["origin"]=="A"],
             key=lambda e:(e["control_rank"],e["duration_index"]))
    B=sorted([e for e in endpoints.values() if e["origin"]=="B"],
             key=lambda e:(e["control_rank"],e["duration_index"]))
    assert A and B
    assert A[0]["control"]=="IDENTITY" and B[0]["control"]=="IDENTITY"

    pairs=[]
    water_matches=[]
    for a in A:
        for b in B:
            dw=abs(b["profile_water_cm"]-a["profile_water_cm"])
            dm=abs(b["distribution_moment_cm"]-a["distribution_moment_cm"])
            rec=(dm,dw,a,b)
            if dw<=W_TOL_CM:
                water_matches.append(rec)
                if dm>=M1_MIN_CM:
                    pairs.append(rec)

    pairs.sort(key=lambda q:(-q[0],q[1],
      q[2]["control_rank"],q[2]["duration_index"],q[3]["control_rank"],q[3]["duration_index"]))
    selected=None
    if pairs:
        dm,dw,a,b=pairs[0]
        selected={
          "A":a,"B":b,
          "abs_delta_profile_water_cm":dw,
          "abs_delta_distribution_moment_cm":dm,
          "abs_delta_upper_30cm_water_cm":abs(b["upper_30cm_water_cm"]-a["upper_30cm_water_cm"])
        }
        disposition="SELECTED_STRICT_ACCEPTED_LOCAL_H2_ORIGIN_PAIR"
    else:
        disposition="NO_MATCH"

    best=None
    if water_matches:
        water_matches.sort(key=lambda q:(-q[0],q[1],
          q[2]["control_rank"],q[2]["duration_index"],q[3]["control_rank"],q[3]["duration_index"]))
        dm,dw,a,b=water_matches[0]
        best={
          "A":{"control":a["control"],"control_rank":a["control_rank"],"duration_index":a["duration_index"],"duration_day":a["duration_day"]},
          "B":{"control":b["control"],"control_rank":b["control_rank"],"duration_index":b["duration_index"],"duration_day":b["duration_day"]},
          "abs_delta_profile_water_cm":dw,
          "abs_delta_distribution_moment_cm":dm,
          "fraction_of_required_M1_separation":dm/M1_MIN_CM
        }

    evidence={
      "schema":"swap5.gc_rootzone_memory.rzm06d04.local_strict_continuation.v1",
      "preregistration_commit":"8de97e12dc9cc50caab3d8808e88caf3db1599c3",
      "production_changes":False,
      "origins":{"A":"D02/64","B":"D08/44","common_reseed_time_day":0.0},
      "endpoint_census":{
        "A_admitted":len(A),"B_admitted":len(B),
        "A_rejected":sum(1 for x in rejects if x["origin"]=="A"),
        "B_rejected":sum(1 for x in rejects if x["origin"]=="B"),
        "attempted_nonidentity_per_origin":35,
        "identity_included_per_origin":1
      },
      "frozen_gate":{
        "max_abs_profile_water_difference_cm":W_TOL_CM,
        "min_abs_distribution_moment_difference_cm":M1_MIN_CM
      },
      "pair_census":{
        "cross_origin_endpoint_pairs":len(A)*len(B),
        "water_matched_pairs":len(water_matches),
        "qualifying_pairs":len(pairs),
        "best_water_matched_pair":best
      },
      "selected_pair":selected,
      "rejections":rejects,
      "response_fields_emitted_or_parsed":False,
      "disposition":disposition,
      "nonclaims":[
        "D04 performs state construction only and does not probe E_c",
        "all non-identity endpoints are strict Reference candidates from immutable reconstructed origins",
        "failed candidate trials are retained as admissibility evidence"
      ]
    }
    Path(args.output).write_text(json.dumps(evidence,indent=2,sort_keys=True)+"\n")
    print("RZM06D04_EXPERIMENT_JSON",json.dumps(evidence,sort_keys=True,separators=(",",":")))
    print("GC_RZM06D04_STATE_ONLY_SELECTION=PASS")

if __name__=="__main__":
    main()
