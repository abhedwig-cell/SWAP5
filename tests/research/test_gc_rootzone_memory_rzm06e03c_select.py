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

CANDIDATE_ALLOWED={"FAMILY","RATE_FRACTION","N","STEPS","T"}
NODE_ALLOWED={"FAMILY","NODE","H","THETA"}
STOP_ALLOWED={"FAMILY","PHASE","RATE_FRACTION","PHASE_STEP","COMMITTED_STEPS","CUM_BOTTOM_CM","STATUS",
              "SAMPLE_VALID","CANDIDATE_READY","MASS_COMPLETE","SOLVER_REJECTIONS","MASS_REJECTIONS"}

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
    meta={}
    nodes={}
    stops=[]
    for line in raw.decode("utf-8").splitlines():
        if line.startswith("RZM06E03C_CANDIDATE|"):
            f=extract(line,CANDIDATE_ALLOWED)
            assert set(f)==CANDIDATE_ALLOWED,f
            fam=f["FAMILY"]
            assert fam not in meta
            meta[fam]={
                "family":fam,
                "rate_fraction":float(f["RATE_FRACTION"]),
                "n":int(f["N"]),
                "committed_steps":int(f["STEPS"]),
                "time_day":float(f["T"]),
            }
        elif line.startswith("RZM06E03C_NODE|"):
            f=extract(line,NODE_ALLOWED)
            assert set(f)==NODE_ALLOWED,f
            fam=f["FAMILY"]; node=int(f["NODE"])
            assert 1<=node<=NODES
            nodes.setdefault(fam,{})[node]=(float(f["H"]),float(f["THETA"]))
        elif line.startswith("RZM06E03C_STOP|"):
            f=extract(line,STOP_ALLOWED)
            assert set(f)==STOP_ALLOWED,f
            stops.append({
                "family":f["FAMILY"],
                "phase":f["PHASE"],
                "rate_fraction":float(f["RATE_FRACTION"]),
                "phase_step":int(f["PHASE_STEP"]),
                "committed_steps":int(f["COMMITTED_STEPS"]),
                "cumulative_bottom_cm":float(f["CUM_BOTTOM_CM"]),
                "status":int(f["STATUS"]),
                "sample_valid":f["SAMPLE_VALID"].upper() in {"T","TRUE",".TRUE."},
                "candidate_ready":f["CANDIDATE_READY"].upper() in {"T","TRUE",".TRUE."},
                "mass_complete":f["MASS_COMPLETE"].upper() in {"T","TRUE",".TRUE."},
                "solver_rejections":int(f["SOLVER_REJECTIONS"]),
                "mass_rejections":int(f["MASS_REJECTIONS"]),
            })
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
        records.append({**m,"pressure_head_cm":h,"water_content":theta,
                        "profile_water_cm":w,"root30_water_cm":root,
                        "distribution_moment_cm":m1})
    records.sort(key=lambda r:r["family"])
    stops.sort(key=lambda r:r["family"])
    return raw,records,stops

def metrics(a:dict,b:dict)->dict:
    return {
      "abs_delta_profile_water_cm":abs(b["profile_water_cm"]-a["profile_water_cm"]),
      "abs_delta_root30_water_cm":abs(b["root30_water_cm"]-a["root30_water_cm"]),
      "abs_delta_distribution_moment_cm":abs(b["distribution_moment_cm"]-a["distribution_moment_cm"]),
    }

def endpoint(r:dict,full:bool=False)->dict:
    out={
      "family":r["family"],"rate_fraction":r["rate_fraction"],"n":r["n"],
      "committed_steps":r["committed_steps"],"time_day":r["time_day"],
      "profile_water_cm":r["profile_water_cm"],"root30_water_cm":r["root30_water_cm"],
      "distribution_moment_cm":r["distribution_moment_cm"],
    }
    if full:
        out["pressure_head_cm"]=r["pressure_head_cm"]
        out["water_content"]=r["water_content"]
    return out

def pair_summary(r):
    if r is None:
        return None
    return {
      "A":endpoint(r["A"]),"B":endpoint(r["B"]),
      "abs_delta_profile_water_cm":r["abs_delta_profile_water_cm"],
      "abs_delta_root30_water_cm":r["abs_delta_root30_water_cm"],
      "abs_delta_distribution_moment_cm":r["abs_delta_distribution_moment_cm"],
      "fraction_of_M1_requirement":r["abs_delta_distribution_moment_cm"]/M1_MIN_CM,
    }

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--o0",required=True)
    ap.add_argument("--o2",required=True)
    args=ap.parse_args()
    raw0,records0,stops0=parse(Path(args.o0))
    raw2,records2,stops2=parse(Path(args.o2))
    assert raw0==raw2,"E03C O0/O2 output drift"
    assert records0==records2 and stops0==stops2

    base=[r for r in records0 if r["family"]=="BASE_EQ"]
    assert len(base)==1,len(base)

    eligible=[]
    water=[]
    root=[]
    qualifying=[]
    for a,b in itertools.combinations(records0,2):
        m=metrics(a,b)
        rec={"A":a,"B":b,**m}
        eligible.append(rec)
        if m["abs_delta_profile_water_cm"]<=W_TOL_CM:
            water.append(rec)
            if m["abs_delta_root30_water_cm"]<=ROOT30_TOL_CM:
                root.append(rec)
                if m["abs_delta_distribution_moment_cm"]>=M1_MIN_CM:
                    qualifying.append(rec)

    qualifying.sort(key=lambda r:(
      -r["abs_delta_distribution_moment_cm"],r["abs_delta_root30_water_cm"],
      r["abs_delta_profile_water_cm"],min(r["A"]["rate_fraction"],r["B"]["rate_fraction"]),
      r["A"]["n"]+r["B"]["n"],r["A"]["family"],r["B"]["family"]))
    root.sort(key=lambda r:(-r["abs_delta_distribution_moment_cm"],r["abs_delta_root30_water_cm"]))
    water.sort(key=lambda r:(r["abs_delta_root30_water_cm"],-r["abs_delta_distribution_moment_cm"]))

    selected=None
    disposition="NO_MATCH"
    if qualifying:
        q=qualifying[0]
        selected={
          "A":endpoint(q["A"],True),"B":endpoint(q["B"],True),
          "abs_delta_profile_water_cm":q["abs_delta_profile_water_cm"],
          "abs_delta_root30_water_cm":q["abs_delta_root30_water_cm"],
          "abs_delta_distribution_moment_cm":q["abs_delta_distribution_moment_cm"],
        }
        disposition="SELECTED_RESPONSE_BLIND_ROOTMATCHED_DEEP_MEMORY_PAIR"

    bottom_stops=[s for s in stops0 if s["phase"]=="BOTTOM"]
    rate_summary={}
    for frac in (0.5,0.25):
        rr=[s for s in bottom_stops if abs(s["rate_fraction"]-frac)<=1e-15]
        rate_summary[str(frac)]={
          "bottom_phase_failures":len(rr),
          "max_completed_bottom_transfer_before_failure_cm":
             max((s["cumulative_bottom_cm"] for s in rr),default=None),
          "min_failure_phase_step":min((s["phase_step"] for s in rr),default=None),
          "max_failure_phase_step":max((s["phase_step"] for s in rr),default=None),
        }

    evidence={
      "schema":"swap5.gc_rootzone_memory.rzm06e03c.gentle_bottom_first_selection.v1",
      "preregistration_commit":"cc0c6629981602eeb440a66c0b7c9b6558e1ca46",
      "production_changes":False,
      "firewall":{"response_fields_parsed":False,"external_library_used":False,
                  "candidate_fields":sorted(CANDIDATE_ALLOWED),"node_fields":sorted(NODE_ALLOWED)},
      "generation":{"candidate_count":len(records0),"candidate_families":[r["family"] for r in records0],
                    "stop_records":stops0},
      "rate_discriminator":rate_summary,
      "frozen_gate":{"max_abs_profile_water_difference_cm":W_TOL_CM,
                     "max_abs_root30_water_difference_cm":ROOT30_TOL_CM,
                     "min_abs_distribution_moment_difference_cm":M1_MIN_CM},
      "census":{"eligible_pairs":len(eligible),"profile_water_matched_pairs":len(water),
                "profile_and_root30_matched_pairs":len(root),"qualifying_pairs":len(qualifying),
                "best_rootmatched_pair":pair_summary(root[0] if root else None),
                "closest_root_pair_after_profile_gate":pair_summary(water[0] if water else None)},
      "selected_pair":selected,"disposition":disposition,
      "nonclaims":["E03C performs no fixed-Hc response probe",
                   "selection uses only committed pressure-head and water-content state",
                   "rate diagnostics concern this research construction, not production robustness"],
    }
    print("RZM06E03C_SELECTION_JSON",json.dumps(evidence,sort_keys=True,separators=(",",":")))
    print("GC_RZM06E03C_RESPONSE_BLIND_SELECTION=PASS")
    return 0

if __name__=="__main__":
    raise SystemExit(main())
