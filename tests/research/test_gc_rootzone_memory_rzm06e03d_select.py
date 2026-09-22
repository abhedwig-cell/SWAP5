from __future__ import annotations
import argparse
import json
import math
import struct
from pathlib import Path

NODES=16
DZ_CM=10.0
Z_CM=[-5.0-10.0*i for i in range(NODES)]
W_TOL=1e-4
ROOT_TOL=1e-4
DEEP_CENTROID_MIN=1e-2

def fields(line:str)->dict[str,str]:
    out={}
    for token in line.rstrip("\n").split("|")[1:]:
        if "=" in token:
            k,v=token.split("=",1)
            out[k]=v
    return out

def make_record(source:str, provenance:str, meta:dict, nodes:dict[int,tuple[float,float]])->dict:
    assert len(nodes)==NODES,(source,provenance,len(nodes))
    h=[nodes[i][0] for i in range(1,NODES+1)]
    theta=[nodes[i][1] for i in range(1,NODES+1)]
    assert all(math.isfinite(x) for x in h+theta)
    w=math.fsum(x*DZ_CM for x in theta)
    root=math.fsum(theta[i]*DZ_CM for i in range(3))
    deep=math.fsum(theta[i]*DZ_CM for i in range(3,NODES))
    assert w>0.0 and root>0.0 and deep>0.0
    deep_centroid=math.fsum(theta[i]*DZ_CM*Z_CM[i] for i in range(3,NODES))/deep
    root_centroid=math.fsum(theta[i]*DZ_CM*Z_CM[i] for i in range(3))/root
    return {
      "source":source,"provenance":provenance,"meta":meta,
      "pressure_head_cm":h,"water_content":theta,
      "profile_water_cm":w,"root30_water_cm":root,"deep_water_cm":deep,
      "deep_distribution_centroid_cm":deep_centroid,
      "root_distribution_centroid_cm":root_centroid,
    }

def parse_d04(path:Path)->list[dict]:
    meta={}
    nodes={}
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("RZM06D04_ENDPOINT|"):
            m=fields(line)
            key=(m["ORIGIN"],int(m["CRANK"]),int(m["DIDX"]))
            meta[key]={"origin":m["ORIGIN"],"control":m["CONTROL"],
                       "control_rank":int(m["CRANK"]),"duration_index":int(m["DIDX"]),
                       "duration_day":float(m["DT"])}
        elif line.startswith("RZM06D04_NODE|"):
            m=fields(line)
            key=(m["ORIGIN"],int(m["CRANK"]),int(m["DIDX"]))
            nodes.setdefault(key,{})[int(m["NODE"])]=(float(m["H"]),float(m["THETA"]))
    out=[]
    for key,m in meta.items():
        prov=f"D04:{key[0]}:C{key[1]}:D{key[2]}"
        out.append(make_record("D04",prov,m,nodes.get(key,{})))
    return out

def parse_e01(path:Path)->list[dict]:
    meta={}
    nodes={}
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("RZM06E01_STATE|"):
            m=fields(line); key=(m["FAMILY"],int(m["STEP"]))
            meta[key]={"family":m["FAMILY"],"step":int(m["STEP"]),"time_day":float(m["T"])}
        elif line.startswith("RZM06E01_NODE|"):
            m=fields(line); key=(m["FAMILY"],int(m["STEP"]))
            nodes.setdefault(key,{})[int(m["NODE"])]=(float(m["H"]),float(m["THETA"]))
    return [make_record("E01",f"E01:{k[0]}:{k[1]}",m,nodes.get(k,{})) for k,m in meta.items()]

def parse_e03(path:Path)->list[dict]:
    meta={}
    nodes={}
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("RZM06E03_STATE|"):
            m=fields(line); key=(m["FAMILY"],int(m["STEP"]))
            meta[key]={"family":m["FAMILY"],"phase":m["PHASE"],"step":int(m["STEP"]),
                       "phase_step":int(m["PHASE_STEP"]),"time_day":float(m["T"])}
        elif line.startswith("RZM06E03_NODE|"):
            m=fields(line); key=(m["FAMILY"],int(m["STEP"]))
            nodes.setdefault(key,{})[int(m["NODE"])]=(float(m["H"]),float(m["THETA"]))
    return [make_record("E03",f"E03:{k[0]}:{m['phase']}:{k[1]}",m,nodes.get(k,{})) for k,m in meta.items()]

def parse_e03b(path:Path)->list[dict]:
    meta={}
    nodes={}
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("RZM06E03B_CANDIDATE|"):
            m=fields(line); key=m["FAMILY"]
            meta[key]={"family":key,"order":m["ORDER"],"n":int(m["N"]),
                       "committed_steps":int(m["STEPS"]),"time_day":float(m["T"])}
        elif line.startswith("RZM06E03B_NODE|"):
            m=fields(line); key=m["FAMILY"]
            nodes.setdefault(key,{})[int(m["NODE"])]=(float(m["H"]),float(m["THETA"]))
    return [make_record("E03B",f"E03B:{k}",m,nodes.get(k,{})) for k,m in meta.items()]

def parse_e03c(path:Path)->list[dict]:
    meta={}
    nodes={}
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("RZM06E03C_CANDIDATE|"):
            m=fields(line); key=m["FAMILY"]
            meta[key]={"family":key,"rate_fraction":float(m["RATE_FRACTION"]),"n":int(m["N"]),
                       "committed_steps":int(m["STEPS"]),"time_day":float(m["T"])}
        elif line.startswith("RZM06E03C_NODE|"):
            m=fields(line); key=m["FAMILY"]
            nodes.setdefault(key,{})[int(m["NODE"])]=(float(m["H"]),float(m["THETA"]))
    return [make_record("E03C",f"E03C:{k}",m,nodes.get(k,{})) for k,m in meta.items()]

def bit_key(r:dict)->bytes:
    vals=[]
    for h,t in zip(r["pressure_head_cm"],r["water_content"]):
        vals.extend((h,t))
    return b"".join(struct.pack(">d",float(x)) for x in vals)

def compact(r:dict,full:bool=False)->dict:
    out={k:r[k] for k in ("source","provenance","meta","profile_water_cm","root30_water_cm",
                           "deep_water_cm","deep_distribution_centroid_cm","root_distribution_centroid_cm")}
    if full:
        out["pressure_head_cm"]=r["pressure_head_cm"]
        out["water_content"]=r["water_content"]
    return out

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--d04",required=True)
    ap.add_argument("--e01",required=True)
    ap.add_argument("--e03",required=True)
    ap.add_argument("--e03b",required=True)
    ap.add_argument("--e03c",required=True)
    ap.add_argument("--output",required=True)
    args=ap.parse_args()

    raw=[]
    raw.extend(parse_d04(Path(args.d04)))
    raw.extend(parse_e01(Path(args.e01)))
    raw.extend(parse_e03(Path(args.e03)))
    raw.extend(parse_e03b(Path(args.e03b)))
    raw.extend(parse_e03c(Path(args.e03c)))
    assert raw,"empty E03D state census"

    source_counts={}
    for r in raw:
        source_counts[r["source"]]=source_counts.get(r["source"],0)+1

    dedup={}
    duplicates=[]
    for r in sorted(raw,key=lambda x:x["provenance"]):
        k=bit_key(r)
        if k in dedup:
            duplicates.append({"kept":dedup[k]["provenance"],"dropped":r["provenance"]})
        else:
            dedup[k]=r
    states=sorted(dedup.values(),key=lambda r:r["provenance"])

    water_pairs=0
    root_pairs=0
    qualifying=[]
    best_rootmatched=None
    for i,a in enumerate(states):
        for b in states[i+1:]:
            dw=abs(b["profile_water_cm"]-a["profile_water_cm"])
            if dw>W_TOL: continue
            water_pairs+=1
            dr=abs(b["root30_water_cm"]-a["root30_water_cm"])
            if dr>ROOT_TOL: continue
            root_pairs+=1
            dd=abs(b["deep_distribution_centroid_cm"]-a["deep_distribution_centroid_cm"])
            drootc=abs(b["root_distribution_centroid_cm"]-a["root_distribution_centroid_cm"])
            rec={"A":a,"B":b,"abs_delta_profile_water_cm":dw,
                 "abs_delta_root30_water_cm":dr,
                 "abs_delta_deep_distribution_centroid_cm":dd,
                 "abs_delta_root_distribution_centroid_cm":drootc}
            if best_rootmatched is None or (
                dd,-dr,-dw,-drootc,a["provenance"],b["provenance"]
            ) > (
                best_rootmatched["abs_delta_deep_distribution_centroid_cm"],
                -best_rootmatched["abs_delta_root30_water_cm"],
                -best_rootmatched["abs_delta_profile_water_cm"],
                -best_rootmatched["abs_delta_root_distribution_centroid_cm"],
                best_rootmatched["A"]["provenance"],best_rootmatched["B"]["provenance"]
            ):
                best_rootmatched=rec
            if dd>=DEEP_CENTROID_MIN:
                qualifying.append(rec)

    qualifying.sort(key=lambda r:(
      -r["abs_delta_deep_distribution_centroid_cm"],
      r["abs_delta_root30_water_cm"],r["abs_delta_profile_water_cm"],
      r["abs_delta_root_distribution_centroid_cm"],
      r["A"]["provenance"],r["B"]["provenance"]))

    selected=None
    disposition="NO_MATCH"
    if qualifying:
        q=qualifying[0]
        selected={
          "A":compact(q["A"],True),"B":compact(q["B"],True),
          "abs_delta_profile_water_cm":q["abs_delta_profile_water_cm"],
          "abs_delta_root30_water_cm":q["abs_delta_root30_water_cm"],
          "abs_delta_deep_distribution_centroid_cm":q["abs_delta_deep_distribution_centroid_cm"],
          "abs_delta_root_distribution_centroid_cm":q["abs_delta_root_distribution_centroid_cm"],
        }
        disposition="SELECTED_RESPONSE_BLIND_DEEP_DISTRIBUTION_PAIR"

    best=None
    if best_rootmatched is not None:
        q=best_rootmatched
        best={
          "A":compact(q["A"]),"B":compact(q["B"]),
          "abs_delta_profile_water_cm":q["abs_delta_profile_water_cm"],
          "abs_delta_root30_water_cm":q["abs_delta_root30_water_cm"],
          "abs_delta_deep_distribution_centroid_cm":q["abs_delta_deep_distribution_centroid_cm"],
          "fraction_of_required_deep_separation":q["abs_delta_deep_distribution_centroid_cm"]/DEEP_CENTROID_MIN,
          "abs_delta_root_distribution_centroid_cm":q["abs_delta_root_distribution_centroid_cm"],
        }

    evidence={
      "schema":"swap5.gc_rootzone_memory.rzm06e03d.deep_profile_library_census.v1",
      "preregistration_commit":"011d73f42d01dda40efe898483269fdb34deb2aa",
      "production_changes":False,
      "response_fields_parsed":False,
      "source_counts_before_dedup":source_counts,
      "raw_state_count":len(raw),
      "unique_state_count":len(states),
      "duplicates":duplicates,
      "frozen_gate":{"max_abs_profile_water_difference_cm":W_TOL,
                     "max_abs_root30_water_difference_cm":ROOT_TOL,
                     "min_abs_deep_distribution_centroid_difference_cm":DEEP_CENTROID_MIN},
      "pair_census":{"total_unique_pairs":len(states)*(len(states)-1)//2,
                     "profile_water_matched_pairs":water_pairs,
                     "profile_and_root30_matched_pairs":root_pairs,
                     "qualifying_pairs":len(qualifying),
                     "best_rootmatched_pair":best},
      "selected_pair":selected,
      "disposition":disposition,
      "nonclaims":["E03D performs state-only selection and no fixed-Hc response probe",
                   "the deep centroid is a research observable for the C01 carrier",
                   "a selected pair would require separate E04 preregistration before response access"]
    }
    Path(args.output).write_text(json.dumps(evidence,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print("RZM06E03D_CENSUS_JSON",json.dumps(evidence,sort_keys=True,separators=(",",":")))
    print("GC_RZM06E03D_RESPONSE_BLIND_CENSUS=PASS")
    return 0

if __name__=="__main__":
    raise SystemExit(main())
