from __future__ import annotations
import argparse,json,math
from pathlib import Path

NODES=16
DZ_CM=10.0
LADDER=[1e-6,1e-7,1e-8,1e-9,1e-10,1e-12]
H16_MIN=1e-2
CAND_ALLOWED={"DIRECTION","RATE_INDEX","FRACTION","STEPS","TRANSFER_RATE","T"}
NODE_ALLOWED={"DIRECTION","RATE_INDEX","STEPS","NODE","H","THETA"}

def fields(line:str,allowed:set[str])->dict[str,str]:
    out={}
    for tok in line.rstrip("\n").split("|")[1:]:
        if "=" not in tok: continue
        k,v=tok.split("=",1)
        if k in allowed: out[k]=v
    return out

def parse(path:Path):
    raw=path.read_bytes()
    meta={}
    nodes={}
    stops=[]
    for line in raw.decode("utf-8").splitlines():
        if line.startswith("RZM06E07_CANDIDATE|"):
            f=fields(line,CAND_ALLOWED); assert set(f)==CAND_ALLOWED,f
            key=(f["DIRECTION"],int(f["RATE_INDEX"]),int(f["STEPS"]))
            assert key not in meta
            meta[key]={
              "direction":f["DIRECTION"],"rate_index":int(f["RATE_INDEX"]),
              "fraction":float(f["FRACTION"]),"steps":int(f["STEPS"]),
              "transfer_rate_cm_per_day":float(f["TRANSFER_RATE"]),"time_day":float(f["T"])
            }
        elif line.startswith("RZM06E07_NODE|"):
            f=fields(line,NODE_ALLOWED); assert set(f)==NODE_ALLOWED,f
            key=(f["DIRECTION"],int(f["RATE_INDEX"]),int(f["STEPS"]))
            node=int(f["NODE"]); assert 1<=node<=NODES
            nodes.setdefault(key,{})[node]=(float(f["H"]),float(f["THETA"]))
        elif line.startswith("RZM06E07_STOP|"):
            stops.append(line)
    records={}
    for key,m in meta.items():
        ns=nodes.get(key,{})
        assert len(ns)==NODES,(key,len(ns))
        h=[ns[i][0] for i in range(1,NODES+1)]
        theta=[ns[i][1] for i in range(1,NODES+1)]
        assert all(math.isfinite(x) for x in h+theta)
        w=math.fsum(v*DZ_CM for v in theta)
        root=math.fsum(theta[i]*DZ_CM for i in range(3))
        records[key]={**m,"pressure_head_cm":h,"water_content":theta,
                      "profile_water_cm":w,"root30_water_cm":root,"H16_cm":h[15],"theta16":theta[15]}
    return raw,records,stops

def pair_metrics(a,b):
    return {
      "abs_delta_profile_water_cm":abs(b["profile_water_cm"]-a["profile_water_cm"]),
      "abs_delta_root30_water_cm":abs(b["root30_water_cm"]-a["root30_water_cm"]),
      "abs_delta_H16_cm":abs(b["H16_cm"]-a["H16_cm"]),
      "abs_delta_theta16":abs(b["theta16"]-a["theta16"]),
      "cumulative_internal_transfer_cm":a["transfer_rate_cm_per_day"]*a["time_day"]
    }

def compact(r,full=False):
    out={k:r[k] for k in ("direction","rate_index","fraction","steps","transfer_rate_cm_per_day",
                           "time_day","profile_water_cm","root30_water_cm","H16_cm","theta16")}
    if full:
        out["pressure_head_cm"]=r["pressure_head_cm"];out["water_content"]=r["water_content"]
    return out

def summarize(p,full=False):
    if p is None:return None
    return {"A":compact(p["A"],full),"B":compact(p["B"],full),
            **{k:v for k,v in p.items() if k.startswith("abs_delta_") or k=="cumulative_internal_transfer_cm"}}

def rank_key(p):
    return (-p["abs_delta_H16_cm"],p["abs_delta_root30_water_cm"],
            p["abs_delta_profile_water_cm"],p["cumulative_internal_transfer_cm"],
            p["A"]["rate_index"],p["A"]["steps"])

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--o0",required=True);ap.add_argument("--o2",required=True);ap.add_argument("--output",required=True)
    a=ap.parse_args()
    raw0,r0,st0=parse(Path(a.o0));raw2,r2,st2=parse(Path(a.o2))
    assert raw0==raw2,"E07 O0/O2 output drift"
    assert r0==r2 and st0==st2

    twins=[]
    completed_keys=[]
    for rate_index in range(1,7):
        for steps in (1,2,4,8):
            ku=("UPSHIFT",rate_index,steps);kd=("DOWNSHIFT",rate_index,steps)
            if ku not in r0 or kd not in r0: continue
            u,d=r0[ku],r0[kd]
            assert u["fraction"]==d["fraction"] and u["transfer_rate_cm_per_day"]==d["transfer_rate_cm_per_day"]
            p={"A":u,"B":d,**pair_metrics(u,d)}
            twins.append(p);completed_keys.append({"rate_index":rate_index,"steps":steps,"fraction":u["fraction"]})
    assert twins,"E07 no complete direction twins"

    rungs=[]
    tightest=None
    for eps in LADDER:
        q=[p for p in twins if p["abs_delta_profile_water_cm"]<=eps and
           p["abs_delta_root30_water_cm"]<=eps and p["abs_delta_H16_cm"]>=H16_MIN]
        q.sort(key=rank_key)
        rungs.append({"epsilon_cm":eps,"qualifying_pairs":len(q),"best_pair":summarize(q[0]) if q else None})
        if q:tightest=(eps,q[0])

    exact=[p for p in twins if p["abs_delta_profile_water_cm"]==0.0 and p["abs_delta_root30_water_cm"]==0.0
           and p["abs_delta_H16_cm"]>=H16_MIN]
    exact.sort(key=rank_key)

    if exact:
        decision="SELECTED_EXACT_DEEP_REDISTRIBUTION_PAIR";mode="EXACT";sel=exact[0]
    elif tightest is not None:
        decision="SELECTED_TIGHT_DEEP_REDISTRIBUTION_PAIR";mode=tightest[0];sel=tightest[1]
    else:
        decision="NO_MATCH";mode=None;sel=None

    evidence={
      "schema":"swap5.gc_rootzone_memory.rzm06e07.deep_internal_redistribution_selection.v1",
      "preregistration_commit":"0127e46ceee2bb35d6eb739d67b26c3e101c9169",
      "production_changes":False,
      "firewall":{"response_fields_parsed":False,"state_input":"committed H/theta plus family provenance only"},
      "generation":{"complete_twin_count":len(twins),"complete_twins":completed_keys,"stop_records":st0},
      "H16_gate_cm":H16_MIN,
      "rungs":rungs,
      "exact_rung":{"qualifying_pairs":len(exact),"best_pair":summarize(exact[0]) if exact else None},
      "selected_mode":mode,
      "selected_pair":summarize(sel,True) if sel else None,
      "decision":decision,
      "nonclaims":["E07 performs no fixed-Hc response probe",
                   "qssdi/qdra are controlled research construction channels here",
                   "selection alone does not establish response-memory causality"]
    }
    Path(a.output).write_text(json.dumps(evidence,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print("RZM06E07_SELECTION_JSON",json.dumps(evidence,sort_keys=True,separators=(",",":")))
    print("GC_RZM06E07_RESPONSE_BLIND_SELECTION=PASS")
    return 0

if __name__=="__main__":
    raise SystemExit(main())
