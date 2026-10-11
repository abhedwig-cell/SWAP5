#!/usr/bin/env python3
"""F-PE-ELASTIC36: compose RD point -> maparea -> profile -> ELASTIC33 interchange."""
from __future__ import annotations
import argparse, json, sqlite3
from pathlib import Path

import fpe_elastic24_profile_retrieval as elastic24
import fpe_elastic33_profile_row_interchange as elastic33
import fpe_elastic34_rd_point_maparea as elastic34

SOURCE_ARTIFACT_SHA256 = elastic24.SOURCE_ARTIFACT_SHA256
RELATION_TABLE = "soilarea_normalsoilprofile"

class Elastic36Error(RuntimeError):
    pass

def resolve_profile_id(con:sqlite3.Connection, maparea_id):
    rows=con.execute(
        "select normalsoilprofile_id from soilarea_normalsoilprofile where maparea_id=?",
        (maparea_id,)
    ).fetchall()
    if len(rows)==0:
        raise Elastic36Error("MAPAREA_NOT_FOUND")
    if len(rows)>1:
        raise Elastic36Error("AMBIGUOUS_MAPAREA")
    value=rows[0][0]
    if isinstance(value,bool):
        raise Elastic36Error("INVALID_PROFILE_ID")
    try:
        pid=int(value)
    except Exception as exc:
        raise Elastic36Error("INVALID_PROFILE_ID") from exc
    if pid!=value or pid<=0:
        raise Elastic36Error("INVALID_PROFILE_ID")
    return pid

def compose(gpkg:Path,x:float,y:float,polygons=None):
    if polygons is None:
        polygons=elastic34.load_polygons(gpkg)
    spatial=elastic34.select_maparea(polygons,float(x),float(y))
    if spatial["status"]!="OK":
        raise Elastic36Error("SPATIAL_"+spatial["status"])
    maparea_id=spatial["maparea_id"]

    con=sqlite3.connect(f"file:{gpkg.resolve()}?mode=ro",uri=True)
    try:
        pid=resolve_profile_id(con,maparea_id)
    finally:
        con.close()

    profile=elastic24.retrieve_profile(gpkg,pid)
    interchange=elastic33.materialize_interchange(profile)
    provenance={
        "schema":"swap5.elastic36.rd-profile-interchange.v1",
        "source_artifact_sha256":SOURCE_ARTIFACT_SHA256,
        "srs_id":elastic34.SRS_ID,
        "x_rd_m":float(x),
        "y_rd_m":float(y),
        "maparea_id":maparea_id,
        "normalsoilprofile_id":pid,
        "horizon_count":profile["horizon_count"],
    }
    return provenance,interchange

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--gpkg",required=True)
    ap.add_argument("--x",required=True,type=float)
    ap.add_argument("--y",required=True,type=float)
    ap.add_argument("--provenance-output",required=True)
    ap.add_argument("--interchange-output",required=True)
    a=ap.parse_args()
    try:
        provenance,interchange=compose(Path(a.gpkg),a.x,a.y)
    except (Elastic36Error,elastic24.Elastic24Error,elastic33.Elastic33Error,elastic34.SpatialError) as exc:
        raise SystemExit(f"F_PE_ELASTIC36_FAIL {exc}") from exc
    Path(a.provenance_output).write_text(json.dumps(provenance,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    Path(a.interchange_output).write_text(interchange,encoding="utf-8")
    print("F_PE_ELASTIC36_SELECTION="+json.dumps(provenance,sort_keys=True,separators=(",",":")))
    print("F_PE_ELASTIC36=PASS")

if __name__=="__main__":
    main()
