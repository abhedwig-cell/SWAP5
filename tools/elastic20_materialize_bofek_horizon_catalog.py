#!/usr/bin/env python3
"""F-PE-ELASTIC20: materialize deterministic offline BOFEK/BRO ELAS horizon catalog."""
from __future__ import annotations
import argparse, csv, hashlib, io, json, math, sqlite3, zipfile
from collections import Counter
from pathlib import Path

SCHEMA="swap5.elastic20.bofek_horizon_catalog.v1"
BOFEK_RUN=36549054287
BOFEK_ARTIFACT=11023058542
PDOK_RUN=36550782840
PDOK_ARTIFACT=11024079961
EXPECTED_PROFILES=368
EXPECTED_HORIZONS=1568
EXPECTED_REGIMES={
    "MINERAL":1356,
    "ORGANIC_RICH_NONPEAT":8,
    "PEAT":204,
    "UNKNOWN":0,
}

FIELDS=[
    "profile_id","bofek_unit","soilunit","layer_number",
    "top_depth_m","bottom_depth_m","staring_code",
    "rho_dry_g_cm3","organic_matter_available","organic_matter_pct",
    "peat_type_present","peat_type",
    "wcr","wcs","alpha_cm_inv","npar",
    "theta_ref_h_minus100","regime",
]

def sha256_bytes(data:bytes)->str:
    return hashlib.sha256(data).hexdigest()

def sha256_file(path:Path)->str:
    h=hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024),b""):
            h.update(chunk)
    return h.hexdigest()

def find_one(root:Path,name:str)->Path:
    hits=list(root.rglob(name))
    if len(hits)!=1:
        raise SystemExit(f"F_PE_ELASTIC20_FAIL {name} hits={len(hits)}")
    return hits[0]

def find_gpkg(root:Path)->Path:
    hits=list(root.rglob("*.gpkg"))
    if len(hits)!=1:
        raise SystemExit(f"F_PE_ELASTIC20_FAIL gpkg hits={len(hits)}")
    return hits[0]

def fmt(x:float)->str:
    if not math.isfinite(x):
        raise ValueError("nonfinite")
    return format(x,".17g")

def block_to_code(block:int)->str:
    if 101<=block<=118:
        return f"B{block-100:02d}"
    if 201<=block<=218:
        return f"O{block-200:02d}"
    raise ValueError(f"invalid staring block {block}")

def theta_ref(p:dict[str,float])->float:
    n=p["npar"]
    m=1.0-1.0/n
    x=p["alpha_cm_inv"]*100.0
    theta=p["wcr"]+(p["wcs"]-p["wcr"])/(1.0+x**n)**m
    if not math.isfinite(theta) or theta<p["wcr"] or theta>p["wcs"]:
        raise ValueError("invalid theta")
    return theta

def regime(om,peat)->str:
    if peat:
        return "PEAT"
    if om is None:
        return "UNKNOWN"
    if om>15.0:
        return "ORGANIC_RICH_NONPEAT"
    return "MINERAL"

def load_sources(source_root:Path,pdok_root:Path):
    bofek_zip=find_one(source_root,"bofek.zip")
    staring_zip=find_one(source_root,"staring.zip")
    gpkg=find_gpkg(pdok_root)

    with zipfile.ZipFile(bofek_zip) as z:
        profiles=list(csv.DictReader(io.TextIOWrapper(
            z.open("bofek/Data/allprofiles368_2020.csv"),encoding="utf-8-sig")))
        results=list(csv.DictReader(io.TextIOWrapper(
            z.open("bofek/Data/all_results_95_bofek2020.csv"),encoding="utf-8-sig")))

    profile_rows={int(r["iprofile"]):r for r in profiles}
    cluster={int(r["iprofile"]):int(r["clust1"]) for r in results}
    if len(profile_rows)!=EXPECTED_PROFILES or len(cluster)!=EXPECTED_PROFILES:
        raise SystemExit("F_PE_ELASTIC20_FAIL BOFEK profile authority")

    with zipfile.ZipFile(staring_zip) as z:
        text=z.read("staringreeks/Data/staringreeks_2018.csv").decode("utf-8-sig")
    staring={}
    for r in csv.DictReader(io.StringIO(text)):
        code=r["name"]
        staring[code]={
            "wcr":float(r["wcr"]),
            "wcs":float(r["wcs"]),
            "alpha_cm_inv":float(r["alpha"]),
            "npar":float(r["npar"]),
        }
    expected={f"B{i:02d}" for i in range(1,19)}|{f"O{i:02d}" for i in range(1,19)}
    if set(staring)!=expected:
        raise SystemExit("F_PE_ELASTIC20_FAIL Staringreeks set")

    con=sqlite3.connect(gpkg)
    try:
        nsp={int(r[0]):str(r[1]) for r in con.execute(
            "select normalsoilprofile_id,soilunit from normalsoilprofiles")}
        hz=list(con.execute(
            "select normalsoilprofile_id,layernumber,lowervalue,uppervalue,"
            "staringseriesblock,density,organicmattercontent,peattype "
            "from soilhorizon order by normalsoilprofile_id,layernumber"))
    finally:
        con.close()

    if set(nsp)!=set(profile_rows):
        raise SystemExit("F_PE_ELASTIC20_FAIL profile-id identity")
    if len(hz)!=EXPECTED_HORIZONS:
        raise SystemExit(f"F_PE_ELASTIC20_FAIL horizon count={len(hz)}")

    source_meta={
        "bofek_zip":{"sha256":sha256_file(bofek_zip),"bytes":bofek_zip.stat().st_size},
        "staring_zip":{"sha256":sha256_file(staring_zip),"bytes":staring_zip.stat().st_size},
        "pdok_gpkg":{"sha256":sha256_file(gpkg),"bytes":gpkg.stat().st_size},
    }
    return profile_rows,cluster,staring,nsp,hz,source_meta

def build_rows(profile_rows,cluster,staring,nsp,hz):
    rows=[]
    keys=set()
    for pid,layer,top,bottom,block,density,om,peat in hz:
        pid=int(pid); layer=int(layer); block=int(block)
        key=(pid,layer)
        if key in keys:
            raise SystemExit(f"F_PE_ELASTIC20_FAIL duplicate key={key}")
        keys.add(key)

        top=float(top); bottom=float(bottom); rho=float(density)
        if not all(math.isfinite(x) for x in (top,bottom,rho)):
            raise SystemExit(f"F_PE_ELASTIC20_FAIL nonfinite source key={key}")
        if top<0 or bottom<=top or rho<=0:
            raise SystemExit(f"F_PE_ELASTIC20_FAIL invalid source key={key}")

        code=block_to_code(block)
        if code not in staring:
            raise SystemExit(f"F_PE_ELASTIC20_FAIL missing retention {code}")
        p=staring[code]
        th=theta_ref(p)

        omv=None if om is None else float(om)
        if omv is not None and (not math.isfinite(omv) or omv<0 or omv>100):
            raise SystemExit(f"F_PE_ELASTIC20_FAIL organic matter key={key}")
        peat_text="" if peat is None else str(peat).strip()
        peat_present=bool(peat_text)
        reg=regime(omv,peat_present)

        rows.append({
            "profile_id":str(pid),
            "bofek_unit":str(cluster[pid]),
            "soilunit":nsp[pid],
            "layer_number":str(layer),
            "top_depth_m":fmt(top),
            "bottom_depth_m":fmt(bottom),
            "staring_code":code,
            "rho_dry_g_cm3":fmt(rho),
            "organic_matter_available":"1" if omv is not None else "0",
            "organic_matter_pct":"" if omv is None else fmt(omv),
            "peat_type_present":"1" if peat_present else "0",
            "peat_type":peat_text,
            "wcr":fmt(p["wcr"]),
            "wcs":fmt(p["wcs"]),
            "alpha_cm_inv":fmt(p["alpha_cm_inv"]),
            "npar":fmt(p["npar"]),
            "theta_ref_h_minus100":fmt(th),
            "regime":reg,
        })
    rows.sort(key=lambda r:(int(r["profile_id"]),int(r["layer_number"])))
    return rows

def write_csv(rows,path:Path):
    buf=io.StringIO(newline="")
    w=csv.DictWriter(buf,fieldnames=FIELDS,lineterminator="\n")
    w.writeheader()
    w.writerows(rows)
    data=buf.getvalue().encode("utf-8")
    path.write_bytes(data)
    return data

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--source-artifact-dir",required=True)
    ap.add_argument("--pdok-artifact-dir",required=True)
    ap.add_argument("--output-dir",required=True)
    a=ap.parse_args()

    out=Path(a.output_dir)
    out.mkdir(parents=True,exist_ok=True)
    profile_rows,cluster,staring,nsp,hz,source_meta=load_sources(
        Path(a.source_artifact_dir),Path(a.pdok_artifact_dir))
    rows=build_rows(profile_rows,cluster,staring,nsp,hz)

    if len(rows)!=EXPECTED_HORIZONS:
        raise SystemExit("F_PE_ELASTIC20_FAIL row count")

    counts=Counter(r["regime"] for r in rows)
    observed={k:counts.get(k,0) for k in EXPECTED_REGIMES}
    if observed!=EXPECTED_REGIMES:
        raise SystemExit(f"F_PE_ELASTIC20_FAIL regimes={observed}")

    units={int(r["bofek_unit"]) for r in rows}
    if len(units)!=79:
        raise SystemExit(f"F_PE_ELASTIC20_FAIL bofek units={len(units)}")

    csv_path=out/"elastic20_bofek_horizon_catalog.csv"
    csv_data=write_csv(rows,csv_path)

    meta={
        "schema":SCHEMA,
        "source_authority":{
            "bofek_staring_run":BOFEK_RUN,
            "bofek_staring_artifact":BOFEK_ARTIFACT,
            "pdok_run":PDOK_RUN,
            "pdok_artifact":PDOK_ARTIFACT,
            **source_meta,
        },
        "profiles":len({r["profile_id"] for r in rows}),
        "horizons":len(rows),
        "bofek_units":len(units),
        "regime_counts":observed,
        "csv_sha256":sha256_bytes(csv_data),
        "csv_file":csv_path.name,
    }
    meta_path=out/"elastic20_bofek_horizon_catalog.meta.json"
    meta_path.write_text(json.dumps(meta,indent=2,sort_keys=True,separators=(",",": "))+"\n",encoding="utf-8")

    print("F_PE_ELASTIC20_SOURCE="+json.dumps(source_meta,separators=(",",":"),sort_keys=True))
    print("F_PE_ELASTIC20_COUNTS="+json.dumps({
        "profiles":meta["profiles"],"horizons":meta["horizons"],
        "bofek_units":meta["bofek_units"],"regimes":observed},
        separators=(",",":"),sort_keys=True))
    print("F_PE_ELASTIC20_CSV_SHA256="+meta["csv_sha256"])
    print("F_PE_ELASTIC20=PASS")

if __name__=="__main__":
    raise SystemExit(main())
