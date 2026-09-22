from __future__ import annotations
import argparse,itertools,json,math,struct
from pathlib import Path

N=16
DZ=10.0
W_TOL=1e-9
ROOT_TOL=1e-9
H16_LADDER=[1e-2,1e-3,1e-4,1e-5,1e-6,1e-7,1e-8,1e-9]
H15_SEP=1e-2
CAND_ALLOWED={"DIRECTION","RATE_INDEX","FRACTION","STEPS","TRANSFER_RATE","T"}
NODE_ALLOWED={"DIRECTION","RATE_INDEX","STEPS","NODE","H","THETA"}

def fields(line,allowed):
    out={}
    for tok in line.rstrip("\n").split("|")[1:]:
        if "=" in tok:
            k,v=tok.split("=",1)
            if k in allowed: out[k]=v
    return out

def parse(path:Path):
    meta={}; nodes={}
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("RZM06E07_CANDIDATE|"):
            f=fields(line,CAND_ALLOWED); assert set(f)==CAND_ALLOWED,f
            key=(f["DIRECTION"],int(f["RATE_INDEX"]),int(f["STEPS"]))
            meta[key]={"direction":f["DIRECTION"],"rate_index":int(f["RATE_INDEX"]),
                       "fraction":float(f["FRACTION"]),"steps":int(f["STEPS"]),
                       "transfer_rate_cm_per_day":float(f["TRANSFER_RATE"]),"time_day":float(f["T"])}
        elif line.startswith("RZM06E07_NODE|"):
            f=fields(line,NODE_ALLOWED); assert set(f)==NODE_ALLOWED,f
            key=(f["DIRECTION"],int(f["RATE_INDEX"]),int(f["STEPS"]))
            nodes.setdefault(key,{})[int(f["NODE"])]=(float(f["H"]),float(f["THETA"]))
    rec=[]
    for key,m in meta.items():
        ns=nodes.get(key,{})
        assert len(ns)==N,(key,len(ns))
        h=[ns[i][0] for i in range(1,N+1)]
        th=[ns[i][1] for i in range(1,N+1)]
        assert all(math.isfinite(x) for x in h+th)
        w=math.fsum(v*DZ for v in th)
        root=math.fsum(th[i]*DZ for i in range(3))
        rec.append({**m,"provenance":[m["direction"],m["rate_index"],m["steps"]],
                    "pressure_head_cm":h,"water_content":th,
                    "profile_water_cm":w,"root30_water_cm":root,
                    "H15_cm":h[14],"H16_cm":h[15],
                    "gradient_15_16":(h[15]-h[14])/DZ})
    return rec

def bits(r):
    vals=[]
    for h,t in zip(r["pressure_head_cm"],r["water_content"]): vals += [h,t]
    return b"".join(struct.pack(">d",x) for x in vals)

def metrics(a,b):
    return {
      "abs_delta_profile_water_cm":abs(b["profile_water_cm"]-a["profile_water_cm"]),
      "abs_delta_root30_water_cm":abs(b["root30_water_cm"]-a["root30_water_cm"]),
      "abs_delta_H16_cm":abs(b["H16_cm"]-a["H16_cm"]),
      "abs_delta_H15_cm":abs(b["H15_cm"]-a["H15_cm"]),
      "abs_delta_gradient_15_16":abs(b["gradient_15_16"]-a["gradient_15_16"])
    }

def compact(r,full=False):
    out={k:r[k] for k in ("provenance","direction","rate_index","fraction","steps",
                           "transfer_rate_cm_per_day","time_day","profile_water_cm",
                           "root30_water_cm","H15_cm","H16_cm","gradient_15_16")}
    if full:
        out["pressure_head_cm"]=r["pressure_head_cm"]
        out["water_content"]=r["water_content"]
    return out

def summarize(p,full=False):
    if p is None:return None
    return {"A":compact(p["A"],full),"B":compact(p["B"],full),
            **{k:v for k,v in p.items() if k.startswith("abs_delta_")}}

def rank(p):
    return (-p["abs_delta_H15_cm"],p["abs_delta_H16_cm"],p["abs_delta_root30_water_cm"],
            p["abs_delta_profile_water_cm"],tuple(p["A"]["provenance"]),tuple(p["B"]["provenance"]))

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--o0",required=True);ap.add_argument("--o2",required=True);ap.add_argument("--output",required=True)
    a=ap.parse_args()
    assert Path(a.o0).read_bytes()==Path(a.o2).read_bytes(),"E09A source O0/O2 drift"
    raw=parse(Path(a.o2))
    dedup={}
    for r in sorted(raw,key=lambda x:tuple(x["provenance"])): dedup.setdefault(bits(r),r)
    states=sorted(dedup.values(),key=lambda x:tuple(x["provenance"]))
    pairs=[]
    for x,y in itertools.combinations(states,2):
        m=metrics(x,y)
        if m["abs_delta_profile_water_cm"]<=W_TOL and m["abs_delta_root30_water_cm"]<=ROOT_TOL and m["abs_delta_H15_cm"]>=H15_SEP:
            pairs.append({"A":x,"B":y,**m})
    rungs=[]; selected=None; selected_eps=None
    for eps in H16_LADDER:
        q=[p for p in pairs if p["abs_delta_H16_cm"]<=eps]
        q.sort(key=rank)
        rungs.append({"max_abs_delta_H16_cm":eps,"qualifying_pairs":len(q),"best_pair":summarize(q[0]) if q else None})
        if q:
            selected=q[0];selected_eps=eps
    exact=[p for p in pairs if p["abs_delta_H16_cm"]==0.0]
    exact.sort(key=rank)
    if exact:
        decision="SELECTED_EXACT_H16_MATCHED_H15_SEPARATED_PAIR";selected=exact[0];selected_mode="EXACT"
    elif selected is not None:
        decision="SELECTED_H16_MATCHED_H15_SEPARATED_PAIR";selected_mode=selected_eps
    else:
        decision="NO_MATCH";selected_mode=None
    ev={
      "schema":"swap5.gc_rootzone_memory.rzm06e09a.local_interface_state_census.v1",
      "preregistration_commit":"e151ee9c19c58d27c7f446d60c1042743f507882",
      "production_changes":False,
      "firewall":{"response_fields_parsed":False,"source":"E07 committed H/theta only"},
      "library":{"raw_state_count":len(raw),"unique_state_count":len(states),
                 "total_unique_pairs":len(states)*(len(states)-1)//2},
      "aggregate_gates":{"max_abs_profile_water_difference_cm":W_TOL,
                         "max_abs_root30_water_difference_cm":ROOT_TOL},
      "H15_separation_gate_cm":H15_SEP,
      "rungs":rungs,
      "exact_H16_rung":{"qualifying_pairs":len(exact),"best_pair":summarize(exact[0]) if exact else None},
      "selected_mode":selected_mode,
      "selected_pair":summarize(selected,True) if selected else None,
      "decision":decision,
      "nonclaims":["E09A performs no response probe","selection does not prove H15 necessity or sufficiency"]
    }
    Path(a.output).write_text(json.dumps(ev,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print("RZM06E09A_CENSUS_JSON",json.dumps(ev,sort_keys=True,separators=(",",":")))
    print("GC_RZM06E09A_RESPONSE_BLIND_CENSUS=PASS")
    return 0
if __name__=="__main__": raise SystemExit(main())
