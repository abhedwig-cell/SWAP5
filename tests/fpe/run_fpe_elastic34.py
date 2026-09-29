#!/usr/bin/env python3
"""F-PE-ELASTIC34 qualification over synthetic and frozen BRO polygons."""
from __future__ import annotations
import argparse, importlib.util, json, math, sqlite3
from pathlib import Path

def load_tool(root:Path):
    path=root/"tools/fpe_elastic34_rd_point_maparea.py"
    spec=importlib.util.spec_from_file_location("elastic34",path)
    if spec is None or spec.loader is None:
        raise SystemExit("F_PE_ELASTIC34_FAIL cannot load tool")
    mod=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

def find_one_gpkg(root:Path):
    hits=list(root.rglob("*.gpkg"))
    if len(hits)!=1:
        raise SystemExit(f"F_PE_ELASTIC34_FAIL gpkg hits={len(hits)}")
    return hits[0]

def req(cond,msg):
    if not cond:
        raise SystemExit("F_PE_ELASTIC34_FAIL "+msg)

def synthetic(mod):
    P=mod.Polygon
    square=((0.0,0.0),(10.0,0.0),(10.0,10.0),(0.0,10.0),(0.0,0.0))
    hole=((3.0,3.0),(7.0,3.0),(7.0,7.0),(3.0,7.0),(3.0,3.0))
    p=P("A",(square,hole),(0.0,0.0,10.0,10.0))
    req(mod.select_maparea([p],1.0,1.0)["status"]=="OK","synthetic inside")
    req(mod.select_maparea([p],5.0,5.0)["status"]=="NOT_FOUND","synthetic hole")
    req(mod.select_maparea([p],0.0,5.0)["status"]=="BOUNDARY","synthetic exterior boundary")
    req(mod.select_maparea([p],3.0,5.0)["status"]=="BOUNDARY","synthetic hole boundary")
    req(mod.select_maparea([p],20.0,20.0)["status"]=="NOT_FOUND","synthetic outside")
    p2=P("B",(((1.0,1.0),(9.0,1.0),(9.0,9.0),(1.0,9.0),(1.0,1.0)),),(1.0,1.0,9.0,9.0))
    req(mod.select_maparea([p,p2],2.0,2.0)["status"]=="AMBIGUOUS","synthetic ambiguity")
    print("F_PE_ELASTIC34_A2_SYNTHETIC_POLICY=PASS")
    print("F_PE_ELASTIC34_A8_AMBIGUITY_FAIL_CLOSED=PASS")

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--repo-root",required=True)
    ap.add_argument("--artifact-dir",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    root=Path(a.repo_root)
    mod=load_tool(root)
    gpkg=find_one_gpkg(Path(a.artifact_dir))

    con=sqlite3.connect(f"file:{gpkg.resolve()}?mode=ro",uri=True)
    try:
        meta=con.execute(
            "select geometry_type_name,srs_id from gpkg_geometry_columns "
            "where table_name='soilarea' and column_name='geom'"
        ).fetchall()
        ids=[r[0] for r in con.execute(
            "select maparea_id from soilarea where maparea_id is not null order by maparea_id"
        )]
        null_ids=con.execute("select count(*) from soilarea where maparea_id is null").fetchone()[0]
        null_geom=con.execute("select count(*) from soilarea where geom is null").fetchone()[0]
    finally:
        con.close()
    req(meta==[("POLYGON",28992)],"A1 metadata")
    req(len(ids)==48025 and len(set(ids))==48025 and null_ids==0 and null_geom==0,"A1 identity/count")
    print("F_PE_ELASTIC34_A1_SOURCE_AUTHORITY=PASS")

    synthetic(mod)

    polygons=mod.load_polygons(gpkg)
    req(len(polygons)==48025,"A3 polygon count")
    req(len({p.maparea_id for p in polygons})==48025,"A4 unique IDs")
    print("F_PE_ELASTIC34_A3_ALL_GEOMETRIES_DECODE=PASS")
    print("F_PE_ELASTIC34_A4_IDENTITY=PASS")

    n=len(polygons)
    sample_indices=sorted({round(i*(n-1)/63) for i in range(64)})
    probes=[]
    skipped=[]
    for idx in sample_indices:
        p=polygons[idx]
        probe=mod.strict_probe(p)
        if probe is None:
            skipped.append(p.maparea_id)
            continue
        result=mod.select_maparea(polygons,probe[0],probe[1])
        req(result["status"]=="OK",f"A5 probe status id={p.maparea_id} got={result}")
        req(result["maparea_id"]==p.maparea_id,f"A5 probe id mismatch source={p.maparea_id} got={result}")
        repeat=mod.select_maparea(polygons,probe[0],probe[1])
        req(repeat==result,f"A9 repeat drift id={p.maparea_id}")
        probes.append({"maparea_id":p.maparea_id,"x":probe[0],"y":probe[1]})
    req(len(probes)>=48,f"A5 insufficient strict probes {len(probes)} skipped={len(skipped)}")
    print("F_PE_ELASTIC34_A5_REAL_SOURCE_PROBES=PASS")
    print("F_PE_ELASTIC34_A9_REPEAT_DETERMINISM=PASS")

    boundary_checked=0
    for idx in sample_indices[:16]:
        p=polygons[idx]
        x,y=p.rings[0][0]
        result=mod.select_maparea(polygons,x,y)
        req(result["status"]=="BOUNDARY",f"A6 boundary id={p.maparea_id} got={result}")
        boundary_checked+=1
    req(boundary_checked==16,"A6 count")
    print("F_PE_ELASTIC34_A6_BOUNDARY_FAIL_CLOSED=PASS")

    minx=min(p.bbox[0] for p in polygons)
    miny=min(p.bbox[1] for p in polygons)
    outside=mod.select_maparea(polygons,minx-1000.0,miny-1000.0)
    req(outside["status"]=="NOT_FOUND","A7 outside")
    print("F_PE_ELASTIC34_A7_OUTSIDE_NOT_FOUND=PASS")

    result={
        "work_unit":"F-PE-ELASTIC34",
        "gpkg":gpkg.name,
        "srs_id":28992,
        "polygon_count":len(polygons),
        "sample_requested":len(sample_indices),
        "strict_probe_count":len(probes),
        "strict_probe_skipped":skipped,
        "boundary_probe_count":boundary_checked,
        "probes":probes,
    }
    Path(a.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print("F_PE_ELASTIC34=PASS")

if __name__=="__main__":
    main()
