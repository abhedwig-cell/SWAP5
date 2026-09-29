#!/usr/bin/env python3
"""F-PE-ELASTIC23: deterministic offline BRO normal-soil-profile retrieval."""
from __future__ import annotations
import argparse, json, math, sqlite3
from pathlib import Path

SCHEMA="swap5.elastic23.bro-profile.v1"
SOURCE_ARTIFACT_SHA256="f96bea1e9efdd0326ae1ca0d72684cd7928c90fd23f0930b51c782dfc0ff5fe6"
TOL_M=1.0e-10
PROFILE_TABLE="normalsoilprofiles"
HORIZON_TABLE="soilhorizon"
PROFILE_COLUMNS=("normalsoilprofile_id","soilunit")
HORIZON_COLUMNS=(
    "normalsoilprofile_id","layernumber","lowervalue","uppervalue",
    "staringseriesblock","organicmattercontent","peattype","density",
)

class Elastic23Error(RuntimeError):
    pass

def open_readonly(path:Path):
    if not path.is_file():
        raise Elastic23Error(f"missing GeoPackage: {path}")
    return sqlite3.connect(f"file:{path.resolve()}?mode=ro", uri=True)

def table_columns(con, table:str):
    return [str(row[1]) for row in con.execute(f"pragma table_info({table})")]

def require_schema(con):
    for table, required in ((PROFILE_TABLE,PROFILE_COLUMNS),(HORIZON_TABLE,HORIZON_COLUMNS)):
        cols=table_columns(con,table)
        if not cols:
            raise Elastic23Error(f"missing required table {table}")
        missing=[c for c in required if c not in cols]
        if missing:
            raise Elastic23Error(f"{table} missing columns: {missing}")

def finite(x):
    try:
        return math.isfinite(float(x))
    except (TypeError,ValueError):
        return False

def retrieve_profile(gpkg:Path, profile_id:int):
    if isinstance(profile_id,bool):
        raise Elastic23Error("profile id must be integer")
    try:
        pid=int(profile_id)
    except Exception as exc:
        raise Elastic23Error("profile id must be integer") from exc
    if pid != profile_id:
        raise Elastic23Error("profile id must be exact integer")

    con=open_readonly(gpkg)
    try:
        require_schema(con)
        prow=list(con.execute(
            "select normalsoilprofile_id,soilunit from normalsoilprofiles "
            "where normalsoilprofile_id=?",(pid,)))
        if len(prow)!=1:
            raise Elastic23Error(f"profile id {pid} occurrence count={len(prow)}")
        source_pid, soilunit=prow[0]
        rows=list(con.execute(
            "select normalsoilprofile_id,layernumber,lowervalue,uppervalue,"
            "staringseriesblock,organicmattercontent,peattype,density "
            "from soilhorizon where normalsoilprofile_id=? order by layernumber",(pid,)))
    finally:
        con.close()

    if not rows:
        raise Elastic23Error(f"profile id {pid} has no horizons")

    horizons=[]
    expected_layer=1
    previous_bottom=None
    for row in rows:
        rpid,layer,low,up,block,om,peat,density=row
        if int(rpid)!=pid:
            raise Elastic23Error("horizon profile identity drift")
        if int(layer)!=expected_layer:
            raise Elastic23Error(f"profile {pid} invalid layernumber {layer}, expected {expected_layer}")
        expected_layer+=1
        if not finite(low) or not finite(up):
            raise Elastic23Error(f"profile {pid} layer {layer} invalid depth")
        low=float(low); up=float(up)
        if up<=low:
            raise Elastic23Error(f"profile {pid} layer {layer} nonpositive thickness")
        if layer==1 and abs(low)>TOL_M:
            raise Elastic23Error(f"profile {pid} first horizon does not start at zero")
        if previous_bottom is not None and abs(low-previous_bottom)>TOL_M:
            raise Elastic23Error(f"profile {pid} horizon gap/overlap before layer {layer}")
        previous_bottom=up

        if isinstance(block,bool):
            raise Elastic23Error(f"profile {pid} layer {layer} invalid staringseriesblock")
        try:
            iblock=int(block)
        except Exception as exc:
            raise Elastic23Error(f"profile {pid} layer {layer} invalid staringseriesblock") from exc
        if iblock != block:
            raise Elastic23Error(f"profile {pid} layer {layer} noninteger staringseriesblock")

        if not finite(density) or float(density)<=0:
            raise Elastic23Error(f"profile {pid} layer {layer} invalid density")
        d=float(density)

        if om is None:
            om_out=None
        else:
            if not finite(om):
                raise Elastic23Error(f"profile {pid} layer {layer} invalid organic matter")
            om_out=float(om)
            if om_out<0 or om_out>100:
                raise Elastic23Error(f"profile {pid} layer {layer} organic matter outside [0,100]")

        peat_out=None if peat is None else str(peat)

        horizons.append({
            "layernumber":int(layer),
            "top_depth_m":low,
            "bottom_depth_m":up,
            "staringseriesblock":iblock,
            "dry_density_g_cm3":d,
            "organic_matter_pct":om_out,
            "peat_type":peat_out,
        })

    return {
        "schema":SCHEMA,
        "source_artifact_sha256":SOURCE_ARTIFACT_SHA256,
        "normalsoilprofile_id":int(source_pid),
        "soilunit":None if soilunit is None else str(soilunit),
        "horizon_count":len(horizons),
        "horizons":horizons,
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--gpkg",required=True)
    ap.add_argument("--profile-id",required=True,type=int)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    try:
        result=retrieve_profile(Path(a.gpkg),a.profile_id)
    except Elastic23Error as exc:
        raise SystemExit(f"F_PE_ELASTIC23_FAIL {exc}") from exc
    out=Path(a.output); out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print("F_PE_ELASTIC23_PROFILE="+json.dumps({
        "normalsoilprofile_id":result["normalsoilprofile_id"],
        "soilunit":result["soilunit"],
        "horizon_count":result["horizon_count"],
    },sort_keys=True,separators=(",",":")))
    print("F_PE_ELASTIC23=PASS")

if __name__=="__main__":
    main()
