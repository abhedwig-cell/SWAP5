#!/usr/bin/env python3
"""F-PE-ELASTIC36 qualification."""
from __future__ import annotations
import argparse, importlib.util, sqlite3, sys
from pathlib import Path

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"F_PE_ELASTIC36_FAIL cannot load {path}")
    mod=importlib.util.module_from_spec(spec)
    sys.modules[spec.name]=mod
    spec.loader.exec_module(mod)
    return mod

def find_one_gpkg(root):
    hits=list(Path(root).rglob("*.gpkg"))
    if len(hits)!=1:
        raise SystemExit(f"F_PE_ELASTIC36_FAIL gpkg hits={len(hits)}")
    return hits[0]

def req(cond,msg):
    if not cond:
        raise SystemExit("F_PE_ELASTIC36_FAIL "+msg)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--repo-root",required=True)
    ap.add_argument("--artifact-dir",required=True)
    a=ap.parse_args()
    root=Path(a.repo_root)
    tools=root/"tools"
    if str(tools) not in sys.path:
        sys.path.insert(0,str(tools))
    e24=load("fpe_elastic24_profile_retrieval",tools/"fpe_elastic24_profile_retrieval.py")
    e33=load("fpe_elastic33_profile_row_interchange",tools/"fpe_elastic33_profile_row_interchange.py")
    e34=load("fpe_elastic34_rd_point_maparea",tools/"fpe_elastic34_rd_point_maparea.py")
    e36=load("fpe_elastic36_rd_point_profile_interchange",tools/"fpe_elastic36_rd_point_profile_interchange.py")
    gpkg=find_one_gpkg(a.artifact_dir)

    con=sqlite3.connect(f"file:{gpkg.resolve()}?mode=ro",uri=True)
    try:
        row=con.execute("select count(*),count(distinct maparea_id),count(distinct normalsoilprofile_id) from soilarea_normalsoilprofile").fetchone()
    finally:
        con.close()
    req(tuple(row)==(48025,48025,368),f"A1 relation authority {row}")
    req(e36.SOURCE_ARTIFACT_SHA256=="f96bea1e9efdd0326ae1ca0d72684cd7928c90fd23f0930b51c782dfc0ff5fe6","A1 hash")
    print("F_PE_ELASTIC36_A1_PARENT_AUTHORITY=PASS")

    polygons=e34.load_polygons(gpkg)
    n=len(polygons)
    indices=sorted({round(i*(n-1)/63) for i in range(64)})
    direct_con=sqlite3.connect(f"file:{gpkg.resolve()}?mode=ro",uri=True)
    selected_profiles=set()
    try:
        successes=0
        for idx in indices:
            p=polygons[idx]
            probe=e34.strict_probe(p)
            req(probe is not None,f"A2 no strict probe maparea={p.maparea_id}")
            prov,interchange=e36.compose(gpkg,probe[0],probe[1],polygons=polygons)
            req(prov["maparea_id"]==p.maparea_id,f"A2 maparea drift source={p.maparea_id} got={prov}")
            rows=direct_con.execute(
                "select normalsoilprofile_id from soilarea_normalsoilprofile where maparea_id=?",(p.maparea_id,)
            ).fetchall()
            req(len(rows)==1,f"A3 relation rows maparea={p.maparea_id} count={len(rows)}")
            direct_pid=int(rows[0][0])
            req(prov["normalsoilprofile_id"]==direct_pid,f"A3 profile mismatch maparea={p.maparea_id}")
            profile=e24.retrieve_profile(gpkg,direct_pid)
            req(profile["normalsoilprofile_id"]==direct_pid,"A4 retrieval identity")
            expected=e33.materialize_interchange(profile)
            req(interchange==expected,f"A5 interchange mismatch profile={direct_pid}")
            prov2,interchange2=e36.compose(gpkg,probe[0],probe[1],polygons=polygons)
            req(prov2==prov and interchange2==interchange,f"A9 repeat drift maparea={p.maparea_id}")
            selected_profiles.add(direct_pid)
            successes+=1
    finally:
        direct_con.close()
    req(successes==64,"A6 sample count")
    req(len(selected_profiles)>=16,f"A6 profile diversity={len(selected_profiles)}")
    print("F_PE_ELASTIC36_A2_REAL_MAPAREA_SELECTION=PASS")
    print("F_PE_ELASTIC36_A3_SQL_PROFILE_IDENTITY=PASS")
    print("F_PE_ELASTIC36_A4_ELASTIC24_IDENTITY=PASS")
    print("F_PE_ELASTIC36_A5_ELASTIC33_BYTE_IDENTITY=PASS")
    print("F_PE_ELASTIC36_A6_BROAD_SAMPLE=PASS")
    print("F_PE_ELASTIC36_A9_REPEAT_IDENTITY=PASS")

    P=e34.Polygon
    square=((0.0,0.0),(10.0,0.0),(10.0,10.0),(0.0,10.0),(0.0,0.0))
    overlap=((1.0,1.0),(9.0,1.0),(9.0,9.0),(1.0,9.0),(1.0,1.0))
    pa=P("A",(square,),(0.0,0.0,10.0,10.0))
    pb=P("B",(overlap,),(1.0,1.0,9.0,9.0))
    for point,status in [((0.0,5.0),"BOUNDARY"),((20.0,20.0),"NOT_FOUND")]:
        try:
            e36.compose(Path("missing.gpkg"),point[0],point[1],polygons=[pa])
        except e36.Elastic36Error as exc:
            req(str(exc)=="SPATIAL_"+status,f"A7 propagation {status} got={exc}")
        else:
            req(False,f"A7 {status} accepted")
    try:
        e36.compose(Path("missing.gpkg"),2.0,2.0,polygons=[pa,pb])
    except e36.Elastic36Error as exc:
        req(str(exc)=="SPATIAL_AMBIGUOUS",f"A7 ambiguous got={exc}")
    else:
        req(False,"A7 ambiguous accepted")
    print("F_PE_ELASTIC36_A7_SPATIAL_FAIL_CLOSED=PASS")

    mem=sqlite3.connect(":memory:")
    try:
        mem.execute("create table soilarea_normalsoilprofile(maparea_id text, normalsoilprofile_id integer)")
        mem.execute("insert into soilarea_normalsoilprofile values('one',10)")
        req(e36.resolve_profile_id(mem,"one")==10,"A8 exact")
        try:
            e36.resolve_profile_id(mem,"missing")
        except e36.Elastic36Error as exc:
            req(str(exc)=="MAPAREA_NOT_FOUND","A8 missing")
        else:
            req(False,"A8 missing accepted")
        mem.execute("insert into soilarea_normalsoilprofile values('dup',20)")
        mem.execute("insert into soilarea_normalsoilprofile values('dup',20)")
        try:
            e36.resolve_profile_id(mem,"dup")
        except e36.Elastic36Error as exc:
            req(str(exc)=="AMBIGUOUS_MAPAREA","A8 duplicate")
        else:
            req(False,"A8 duplicate accepted")
    finally:
        mem.close()
    print("F_PE_ELASTIC36_A8_RELATION_FAIL_CLOSED=PASS")
    print(f"F_PE_ELASTIC36_SAMPLE_PROFILES={len(selected_profiles)}")
    print("F_PE_ELASTIC36=PASS")

if __name__=="__main__":
    main()
