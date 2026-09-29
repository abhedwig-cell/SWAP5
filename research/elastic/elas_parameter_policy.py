#!/usr/bin/env python3
"""F-PE-ELASTIC13: frozen physical parameter-policy audit."""
from __future__ import annotations
import argparse, csv, io, json, math, sqlite3, statistics, zipfile
from collections import Counter, defaultdict
from pathlib import Path

HEADS=(-100.0,-200.0)
F=2.123968031921196

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
        raise SystemExit(f"F_PE_ELASTIC13_FAIL {name} hits={len(hits)}")
    return hits[0]

def find_gpkg(root:Path):
    hits=list(root.rglob("*.gpkg"))
    if len(hits)!=1:
        raise SystemExit(f"F_PE_ELASTIC13_FAIL gpkg hits={len(hits)}")
    return hits[0]

def load_bofek(root:Path):
    zp=find_one(root,"bofek.zip")
    with zipfile.ZipFile(zp) as z:
        p=list(csv.DictReader(io.TextIOWrapper(z.open("bofek/Data/allprofiles368_2020.csv"),encoding="utf-8-sig")))
        r=list(csv.DictReader(io.TextIOWrapper(z.open("bofek/Data/all_results_95_bofek2020.csv"),encoding="utf-8-sig")))
    return {int(x["iprofile"]):x for x in p},{int(x["iprofile"]):int(x["clust1"]) for x in r}

def load_staring(root:Path):
    zp=find_one(root,"staring.zip")
    with zipfile.ZipFile(zp) as z:
        raw=z.read("staringreeks/Data/staringreeks_2018.csv").decode("utf-8-sig")
    out={}
    for r in csv.DictReader(io.StringIO(raw)):
        out[r["name"]]={k:float(r[k]) for k in ("wcr","wcs","alpha","npar")}
    return out

def block_name(block:int):
    if 101<=block<=118: return f"B{block-100:02d}"
    if 201<=block<=218: return f"O{block-200:02d}"
    raise ValueError(block)

def theta(p,h):
    n=p["npar"]; m=1.0-1.0/n
    return p["wcr"]+(p["wcs"]-p["wcr"])/(1.0+(p["alpha"]*abs(h))**n)**m

def q(vals,p):
    s=sorted(vals)
    pos=(len(s)-1)*p
    lo=int(math.floor(pos)); hi=int(math.ceil(pos))
    if lo==hi: return s[lo]
    return s[lo]*(hi-pos)+s[hi]*(pos-lo)

def summary(rows):
    if not rows: return {"n":0}
    vals=[r["ss"] for r in rows]
    dry=[r["dry_density"] for r in rows]
    om=[r["organic_matter"] for r in rows if r["organic_matter"] is not None]
    dom=Counter(r["domain"] for r in rows)
    bins=Counter("below" if r["ss"]<0.5e-6 else "near" if r["ss"]<=2e-6 else "above" for r in rows)
    return {
      "n":len(rows),
      "profiles":len({r["iprofile"] for r in rows}),
      "dry_density":{"min":min(dry),"median":statistics.median(dry),"max":max(dry)},
      "organic_matter":{"n":len(om),"min":min(om) if om else None,"median":statistics.median(om) if om else None,"max":max(om) if om else None},
      "ss":{"min":min(vals),"p10":q(vals,0.1),"median":statistics.median(vals),"p90":q(vals,0.9),"max":max(vals)},
      "domain_fraction":{k:dom[k]/len(rows) for k in ("IN_DOMAIN","EDGE","EXTRAPOLATION")},
      "one_e_minus6_fraction":{k:bins[k]/len(rows) for k in ("below","near","above")},
      "uncertainty_lower_min":min(v/F for v in vals),
      "uncertainty_upper_max":max(v*F for v in vals),
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--source-artifact-dir",required=True)
    ap.add_argument("--pdok-artifact-dir",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    source=Path(a.source_artifact_dir); pdok=Path(a.pdok_artifact_dir)
    bofek,clusters=load_bofek(source); staring=load_staring(source)
    gpkg=find_gpkg(pdok)

    con=sqlite3.connect(gpkg)
    try:
        hz=list(con.execute(
          "select normalsoilprofile_id,layernumber,lowervalue,uppervalue,staringseriesblock,"
          "organicmattercontent,peattype,density from soilhorizon "
          "where normalsoilprofile_id in (%s) order by normalsoilprofile_id,layernumber"
          % ",".join("?" for _ in bofek), tuple(sorted(bofek))))
    finally:
        con.close()

    if len(hz)!=1568:
        raise SystemExit(f"F_PE_ELASTIC13_FAIL horizon count={len(hz)}")

    records=[]
    unknown=[]
    peattypes=Counter()
    for pid,layer,low,up,block,om,peattype,density in hz:
        pid=int(pid); layer=int(layer); block=int(block)
        if pid not in bofek:
            raise SystemExit("F_PE_ELASTIC13_FAIL profile identity")
        d=float(density)
        omv=None if om is None else float(om)
        pt=None if peattype is None or not str(peattype).strip() else str(peattype).strip()
        if pt:
            regime="PEAT"; peattypes[pt]+=1
        elif omv is None or not math.isfinite(omv):
            regime="UNKNOWN"; unknown.append({"iprofile":pid,"layer":layer})
        elif omv>15.0:
            regime="ORGANIC_RICH_NONPEAT"
        else:
            regime="MINERAL"

        name=block_name(block)
        if name not in staring:
            raise SystemExit(f"F_PE_ELASTIC13_FAIL block {block}")
        p=staring[name]
        for h in HEADS:
            th=theta(p,h)
            rho_wet=d+th
            water=100.0*th/d
            zrho=(rho_wet-RHO_MEAN)/RHO_SD
            zw=(water-WATER_MEAN)/WATER_SD
            maxz=max(abs(zrho),abs(zw))
            domain="IN_DOMAIN" if maxz<=2 else ("EDGE" if maxz<=3 else "EXTRAPOLATION")
            y=INTERCEPT+RHO_COEF*zrho+WATER_COEF*zw
            ss=10.0**y
            records.append({
              "iprofile":pid,"bofek_unit":clusters[pid],"layer":layer,
              "low_m":float(low),"up_m":float(up),"staring":name,
              "dry_density":d,"organic_matter":omv,"peattype":pt,"regime":regime,
              "h_cm":h,"theta":th,"wet_density":rho_wet,"water_content_pct":water,
              "z_rho":zrho,"z_water":zw,"domain":domain,"ss":ss,
              "elas_lower":ss/F,"elas_upper":ss*F,
            })

    by_regime={}
    regimes=("MINERAL","ORGANIC_RICH_NONPEAT","PEAT","UNKNOWN")
    for reg in regimes:
        by_regime[reg]={str(int(h)):summary([r for r in records if r["regime"]==reg and r["h_cm"]==h]) for h in HEADS}

    pairs=defaultdict(dict)
    for r in records:
        pairs[(r["iprofile"],r["layer"])][r["h_cm"]]=r
    mineral_ratios=[]
    all_ratios_by_regime=defaultdict(list)
    for vals in pairs.values():
        if -100.0 not in vals or -200.0 not in vals: continue
        ratio=vals[-200.0]["ss"]/vals[-100.0]["ss"]
        reg=vals[-100.0]["regime"]
        all_ratios_by_regime[reg].append(ratio)
        if reg=="MINERAL": mineral_ratios.append(ratio)

    def ratio_summary(vals):
        if not vals: return {"n":0}
        return {"n":len(vals),"min":min(vals),"p10":q(vals,0.1),"median":statistics.median(vals),"p90":q(vals,0.9),"max":max(vals),
                "fraction_0p8_1p25":sum(0.8<=x<=1.25 for x in vals)/len(vals),
                "fraction_0p67_1p5":sum(0.67<=x<=1.5 for x in vals)/len(vals)}

    min100=[r for r in records if r["regime"]=="MINERAL" and r["h_cm"]==-100.0]
    min200=[r for r in records if r["regime"]=="MINERAL" and r["h_cm"]==-200.0]
    extrap100=sum(r["domain"]=="EXTRAPOLATION" for r in min100)
    extrap200=sum(r["domain"]=="EXTRAPOLATION" for r in min200)
    ratio_ok_95=sum(0.8<=x<=1.25 for x in mineral_ratios)/len(mineral_ratios)>=0.95
    ratio_ok_all=all(0.67<=x<=1.5 for x in mineral_ratios)
    mineral_pass=(extrap100==0 and extrap200==0 and ratio_ok_95 and ratio_ok_all)
    classification=("STATIC_MINERAL_ELAS_POLICY_QUALIFIED_FOR_PRODUCTION_SHAPING"
                    if mineral_pass else "STATIC_MINERAL_ELAS_POLICY_NOT_QUALIFIED")

    result={
      "source_counts":{"horizons":1568,"profiles":len({int(x[0]) for x in hz})},
      "regime_counts":{reg:sum(1 for k,v in pairs.items() if v[-100.0]["regime"]==reg) for reg in regimes},
      "peattypes":dict(sorted(peattypes.items())),
      "unknown_layers":unknown,
      "summary_by_regime":by_regime,
      "ratio_by_regime":{reg:ratio_summary(all_ratios_by_regime[reg]) for reg in regimes},
      "mineral_gate":{
        "extrapolation_minus100":extrap100,
        "extrapolation_minus200":extrap200,
        "fraction_ratio_0p8_1p25":sum(0.8<=x<=1.25 for x in mineral_ratios)/len(mineral_ratios),
        "all_ratio_0p67_1p5":ratio_ok_all,
        "pass":mineral_pass,
      },
      "policy":{
        "MINERAL":"AUTO_STATIC_PRIOR_AT_H_MINUS100" if mineral_pass else "NOT_QUALIFIED",
        "ORGANIC_RICH_NONPEAT":"RESEARCH_ONLY_NOT_AUTO_ASSIGNED",
        "PEAT":"RESEARCH_ONLY_NOT_AUTO_ASSIGNED",
        "UNKNOWN":"NO_AUTO_ASSIGNMENT",
        "uncertainty_factor":F,
        "reference_head_cm":-100.0,
        "sensitivity_head_cm":-200.0,
      },
      "classification":classification,
      "records":records,
    }
    out=Path(a.output); out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(result,indent=2)+"\n")
    print("F_PE_ELASTIC13_REGIMES="+json.dumps(result["regime_counts"],separators=(",",":"),sort_keys=True))
    print("F_PE_ELASTIC13_PEATTYPES="+json.dumps(result["peattypes"],separators=(",",":"),sort_keys=True))
    print("F_PE_ELASTIC13_MINERAL_GATE="+json.dumps(result["mineral_gate"],separators=(",",":"),sort_keys=True))
    print("F_PE_ELASTIC13_RATIO="+json.dumps(result["ratio_by_regime"],separators=(",",":"),sort_keys=True))
    print("F_PE_ELASTIC13_SUMMARY="+json.dumps(result["summary_by_regime"],separators=(",",":"),sort_keys=True))
    print("F_PE_ELASTIC13_CLASSIFICATION="+classification)
    print("F_PE_ELASTIC13=PASS")

if __name__=="__main__":
    raise SystemExit(main())
