#!/usr/bin/env python3
"""F-PE-ELASTIC12A5: exact BOFEK/BRO profile bridge and frozen-state ELAS transfer audit."""
from __future__ import annotations
import argparse, csv, io, json, math, sqlite3, statistics, zipfile
from collections import defaultdict
from pathlib import Path

HEADS=(-10.0,-33.0,-100.0,-330.0,-1000.0)

# Frozen ELASTIC11 M1
INTERCEPT=-5.144312248981006
RHO_COEF=-0.25581251314464676
WATER_COEF=0.15229775506831100
RHO_MEAN=1.4337873737373736
RHO_SD=0.34422692442216535
WATER_MEAN=191.8190909090909
WATER_SD=182.02868188688447

def find_one(root:Path,name:str):
    hits=list(root.rglob(name))
    if len(hits)!=1:
        raise SystemExit(f"F_PE_ELASTIC12A5_FAIL {name} hits={len(hits)}")
    return hits[0]

def find_gpkg(root:Path):
    hits=list(root.rglob("*.gpkg"))
    if len(hits)!=1:
        raise SystemExit(f"F_PE_ELASTIC12A5_FAIL gpkg hits={len(hits)}")
    return hits[0]

def load_bofek(source_root:Path):
    zp=find_one(source_root,"bofek.zip")
    with zipfile.ZipFile(zp) as z:
        profiles=list(csv.DictReader(io.TextIOWrapper(z.open("bofek/Data/allprofiles368_2020.csv"),encoding="utf-8-sig")))
        results=list(csv.DictReader(io.TextIOWrapper(z.open("bofek/Data/all_results_95_bofek2020.csv"),encoding="utf-8-sig")))
    if len(profiles)!=368:
        raise SystemExit(f"F_PE_ELASTIC12A5_FAIL BOFEK profiles={len(profiles)}")
    return profiles,results

def load_staring(source_root:Path):
    zp=find_one(source_root,"staring.zip")
    with zipfile.ZipFile(zp) as z:
        raw=z.read("staringreeks/Data/staringreeks_2018.csv").decode("utf-8-sig")
    rows=list(csv.DictReader(io.StringIO(raw)))
    if len(rows)!=36:
        raise SystemExit("F_PE_ELASTIC12A5_FAIL staring rows")
    out={}
    for r in rows:
        out[r["name"]]={k:float(r[k]) for k in ("wcr","wcs","alpha","npar","lambda","ksfit")}
    expected={f"B{i:02d}" for i in range(1,19)}|{f"O{i:02d}" for i in range(1,19)}
    if set(out)!=expected:
        raise SystemExit("F_PE_ELASTIC12A5_FAIL staring set")
    return out

def isoil_to_block(i:int):
    if 1<=i<=18: return 100+i
    if 19<=i<=36: return 200+(i-18)
    raise ValueError(i)

def block_to_name(block:int):
    if 101<=block<=118: return f"B{block-100:02d}"
    if 201<=block<=218: return f"O{block-200:02d}"
    raise ValueError(block)

def theta_vg(p,h):
    # Staringreeks alpha is cm^-1 and h here is cm.
    n=p["npar"]
    m=1.0-1.0/n
    return p["wcr"]+(p["wcs"]-p["wcr"])/(1.0+(p["alpha"]*abs(h))**n)**m

def quantile(vals,q):
    s=sorted(vals)
    if not s: return None
    pos=(len(s)-1)*q
    lo=int(math.floor(pos)); hi=int(math.ceil(pos))
    if lo==hi: return s[lo]
    return s[lo]*(hi-pos)+s[hi]*(pos-lo)

def summarize(records):
    vals=[r["ss_cm_inv"] for r in records]
    n=len(vals)
    cls=defaultdict(int)
    bins=defaultdict(int)
    for r in records:
        cls[r["domain"]]+=1
        if r["ss_cm_inv"]<0.5e-6: bins["below"]+=1
        elif r["ss_cm_inv"]<=2.0e-6: bins["near"]+=1
        else: bins["above"]+=1
    return {
      "n":n,
      "ss_min":min(vals),"ss_p10":quantile(vals,0.10),"ss_median":statistics.median(vals),
      "ss_p90":quantile(vals,0.90),"ss_max":max(vals),
      "domain_fraction":{k:cls[k]/n for k in ("IN_DOMAIN","EDGE","EXTRAPOLATION")},
      "one_e_minus6_fraction":{k:bins[k]/n for k in ("below","near","above")},
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--source-artifact-dir",required=True)
    ap.add_argument("--pdok-artifact-dir",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    source_root=Path(a.source_artifact_dir)
    pdok_root=Path(a.pdok_artifact_dir)

    profiles,results=load_bofek(source_root)
    staring=load_staring(source_root)
    gpkg=find_gpkg(pdok_root)

    cluster_by_profile={int(r["iprofile"]):int(r["clust1"]) for r in results}
    bofek_by_id={int(r["iprofile"]):r for r in profiles}
    if len(bofek_by_id)!=368 or len(cluster_by_profile)!=368:
        raise SystemExit("F_PE_ELASTIC12A5_FAIL BOFEK id uniqueness")

    con=sqlite3.connect(gpkg)
    try:
        nsp={int(r[0]):r[1] for r in con.execute("select normalsoilprofile_id,soilunit from normalsoilprofiles")}
        hz_rows=list(con.execute(
          "select normalsoilprofile_id,layernumber,lowervalue,uppervalue,staringseriesblock,density "
          "from soilhorizon order by normalsoilprofile_id,layernumber"))
    finally:
        con.close()

    bofek_ids=set(bofek_by_id)
    if set(nsp)!=bofek_ids:
        raise SystemExit(f"F_PE_ELASTIC12A5_FAIL profile-id set difference bofek_only={len(bofek_ids-set(nsp))} bro_only={len(set(nsp)-bofek_ids)}")

    hz_by=defaultdict(list)
    for row in hz_rows:
        if int(row[0]) in bofek_ids:
            hz_by[int(row[0])].append(row)
    if set(hz_by)!=bofek_ids:
        raise SystemExit("F_PE_ELASTIC12A5_FAIL horizon profile coverage")

    bridge=[]
    total_layers=0
    for pid in sorted(bofek_ids):
        b=bofek_by_id[pid]
        expected=[]
        lower=0.0
        for k in range(1,10):
            iso=int(float(b[f"isoil{k}"]))
            iz=int(float(b[f"iz{k}"]))
            if iso==0:
                break
            block=isoil_to_block(iso)
            upper=iz/100.0
            expected.append((k,lower,upper,block))
            lower=upper
        got=hz_by[pid]
        if len(got)!=len(expected):
            raise SystemExit(f"F_PE_ELASTIC12A5_FAIL layer count profile={pid} bofek={len(expected)} bro={len(got)}")
        for exp,row in zip(expected,got):
            k,lower,upper,block=exp
            rpid,layer,rlow,rup,rblock,density=row
            if int(layer)!=k or abs(float(rlow)-lower)>1e-9 or abs(float(rup)-upper)>1e-9 or int(rblock)!=block:
                raise SystemExit(f"F_PE_ELASTIC12A5_FAIL horizon identity profile={pid} expected={exp} got={row[:5]}")
            d=float(density)
            if not math.isfinite(d) or d<=0:
                raise SystemExit(f"F_PE_ELASTIC12A5_FAIL density profile={pid} layer={k}")
            bridge.append({
              "iprofile":pid,"bodemcode":b["bodemcode"],"bofek_unit":cluster_by_profile[pid],
              "layer":k,"lower_m":lower,"upper_m":upper,"block":block,
              "staring_name":block_to_name(block),"dry_density_g_cm3":d,
            })
            total_layers+=1

    if total_layers!=1568:
        raise SystemExit(f"F_PE_ELASTIC12A5_FAIL total layers={total_layers}")

    records=[]
    for layer in bridge:
        p=staring[layer["staring_name"]]
        rho_d=layer["dry_density_g_cm3"]
        for h in HEADS:
            theta=theta_vg(p,h)
            rho_wet=rho_d+theta
            water_pct=100.0*theta/rho_d
            zrho=(rho_wet-RHO_MEAN)/RHO_SD
            zw=(water_pct-WATER_MEAN)/WATER_SD
            y=INTERCEPT+RHO_COEF*zrho+WATER_COEF*zw
            ss=10.0**y
            az=max(abs(zrho),abs(zw))
            domain="IN_DOMAIN" if az<=2.0 else ("EDGE" if az<=3.0 else "EXTRAPOLATION")
            records.append({
              **layer,"h_cm":h,"theta":theta,"wet_density_g_cm3":rho_wet,
              "water_content_pct":water_pct,"z_rho":zrho,"z_water":zw,
              "domain":domain,"log10_ss_cm_inv":y,"ss_cm_inv":ss,
            })

    by_head={}
    for h in HEADS:
        by_head[str(int(h))]=summarize([r for r in records if r["h_cm"]==h])

    # State sensitivity on identical layers.
    by_key=defaultdict(dict)
    for r in records:
        by_key[(r["iprofile"],r["layer"])][r["h_cm"]]=r["ss_cm_inv"]
    ratios=[]
    for vals in by_key.values():
        ratios.append(vals[-10.0]/vals[-1000.0])
    sensitivity={
      "ratio_ss_h_minus10_over_h_minus1000":{
        "min":min(ratios),"p10":quantile(ratios,0.10),"median":statistics.median(ratios),
        "p90":quantile(ratios,0.90),"max":max(ratios),
      }
    }

    max_non_extrap=max(v["domain_fraction"]["IN_DOMAIN"]+v["domain_fraction"]["EDGE"] for v in by_head.values())
    classification=("BOFEK_LAYER_PRIOR_TRANSFER_FEASIBLE" if max_non_extrap>=0.95
                    else "TRANSFER_NOT_SUPPORTED_WITH_CURRENT_PREDICTOR_DOMAIN")

    # Compact summaries by Staringreeks unit/family and BOFEK cluster at each state.
    def grouped(field):
        out={}
        keys=sorted({r[field] for r in records},key=str)
        for key in keys:
            out[str(key)]={}
            for h in HEADS:
                subset=[r for r in records if r[field]==key and r["h_cm"]==h]
                if subset: out[str(key)][str(int(h))]=summarize(subset)
        return out

    result={
      "bridge":{
        "bofek_profiles":368,"bro_profiles":len(nsp),"matched_profiles":368,
        "matched_layers":total_layers,"profile_id_identity":True,"horizon_identity":True,
      },
      "heads_cm":list(HEADS),
      "summary_by_head":by_head,
      "state_sensitivity":sensitivity,
      "summary_by_staringreeks":grouped("staring_name"),
      "summary_by_bofek_unit":grouped("bofek_unit"),
      "summary_by_family":{
        fam:{str(int(h)):summarize([r for r in records if r["staring_name"].startswith(fam) and r["h_cm"]==h])
             for h in HEADS}
        for fam in ("B","O")
      },
      "max_in_domain_or_edge_fraction":max_non_extrap,
      "classification":classification,
      "records":records,
    }
    out=Path(a.output); out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(result,indent=2)+"\n")
    print("F_PE_ELASTIC12A5_BRIDGE="+json.dumps(result["bridge"],separators=(",",":"),sort_keys=True))
    print("F_PE_ELASTIC12A5_HEAD_SUMMARY="+json.dumps(by_head,separators=(",",":"),sort_keys=True))
    print("F_PE_ELASTIC12A5_SENSITIVITY="+json.dumps(sensitivity,separators=(",",":"),sort_keys=True))
    print("F_PE_ELASTIC12A5_CLASSIFICATION="+classification)
    print("F_PE_ELASTIC12A5=PASS")

if __name__=="__main__":
    raise SystemExit(main())
