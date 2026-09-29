#!/usr/bin/env python3
"""F-PE-ELASTIC24 qualification oracle over the frozen BRO GeoPackage."""
from __future__ import annotations
import argparse, importlib.util, json, sqlite3, tempfile
from pathlib import Path

def load_tool(root:Path):
    path=root/"tools/fpe_elastic24_profile_retrieval.py"
    spec=importlib.util.spec_from_file_location("elastic24_tool",path)
    if spec is None or spec.loader is None:
        raise SystemExit("F_PE_ELASTIC23_FAIL cannot load tool")
    mod=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

def find_one_gpkg(root:Path):
    hits=list(root.rglob("*.gpkg"))
    if len(hits)!=1:
        raise SystemExit(f"F_PE_ELASTIC23_FAIL gpkg hits={len(hits)}")
    return hits[0]

def direct_rows(con,pid:int):
    prow=list(con.execute(
        "select normalsoilprofile_id,soilunit from normalsoilprofiles "
        "where normalsoilprofile_id=?",(pid,)))
    hrows=list(con.execute(
        "select normalsoilprofile_id,layernumber,lowervalue,uppervalue,"
        "staringseriesblock,organicmattercontent,peattype,density "
        "from soilhorizon where normalsoilprofile_id=? order by layernumber",(pid,)))
    return prow,hrows

def same_float(a,b):
    if a is None or b is None:
        return a is None and b is None
    return float(a)==float(b)

def compare_profile(result,prow,hrows,source_sha):
    if len(prow)!=1:
        return False
    if result["schema"]!="swap5.elastic24.bro-profile.v1":
        return False
    if result["source_artifact_sha256"]!=source_sha:
        return False
    if result["normalsoilprofile_id"]!=int(prow[0][0]):
        return False
    soilunit=None if prow[0][1] is None else str(prow[0][1])
    if result["soilunit"]!=soilunit:
        return False
    if result["horizon_count"]!=len(hrows) or len(result["horizons"])!=len(hrows):
        return False
    for got,row in zip(result["horizons"],hrows):
        _,layer,low,up,block,om,peat,density=row
        if got["layernumber"]!=int(layer): return False
        if not same_float(got["top_depth_m"],low): return False
        if not same_float(got["bottom_depth_m"],up): return False
        if got["staringseriesblock"]!=int(block): return False
        if not same_float(got["dry_density_g_cm3"],density): return False
        expected_om=None if om is None else float(om)
        if got["organic_matter_pct"]!=expected_om: return False
        expected_peat=None if peat is None else str(peat)
        if got["peat_type"]!=expected_peat: return False
    return True

def build_bad_geometry_db(path:Path):
    con=sqlite3.connect(path)
    try:
        con.execute("create table normalsoilprofiles(normalsoilprofile_id integer, soilunit text)")
        con.execute("create table soilhorizon(normalsoilprofile_id integer, layernumber integer, lowervalue real, uppervalue real, staringseriesblock integer, organicmattercontent real, peattype text, density real)")
        con.execute("insert into normalsoilprofiles values(1,'X')")
        con.execute("insert into soilhorizon values(1,1,0.0,0.5,101,2.0,null,1.4)")
        con.execute("insert into soilhorizon values(1,2,0.6,1.0,102,2.0,null,1.3)")
        con.commit()
    finally:
        con.close()

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--repo-root",required=True)
    ap.add_argument("--artifact-dir",required=True)
    a=ap.parse_args()
    root=Path(a.repo_root)
    artifact=Path(a.artifact_dir)
    tool=load_tool(root)
    gpkg=find_one_gpkg(artifact)

    con=sqlite3.connect(f"file:{gpkg.resolve()}?mode=ro",uri=True)
    try:
        tool.require_schema(con)
        pcols=[r[1] for r in con.execute("pragma table_info(normalsoilprofiles)")]
        hcols=[r[1] for r in con.execute("pragma table_info(soilhorizon)")]
        if any(c not in pcols for c in tool.PROFILE_COLUMNS):
            raise SystemExit("F_PE_ELASTIC23_FAIL profile schema")
        if any(c not in hcols for c in tool.HORIZON_COLUMNS):
            raise SystemExit("F_PE_ELASTIC23_FAIL horizon schema")
        print("F_PE_ELASTIC23_A1_SCHEMA=PASS")

        ids=[int(r[0]) for r in con.execute(
            "select normalsoilprofile_id from normalsoilprofiles order by normalsoilprofile_id")]
        if len(ids)!=368 or len(set(ids))!=368:
            raise SystemExit(f"F_PE_ELASTIC23_FAIL profile count={len(ids)}")

        total=0
        for pid in ids:
            result=tool.retrieve_profile(gpkg,pid)
            prow,hrows=direct_rows(con,pid)
            if not compare_profile(result,prow,hrows,tool.SOURCE_ARTIFACT_SHA256):
                raise SystemExit(f"F_PE_ELASTIC23_FAIL direct SQL mismatch profile={pid}")
            total+=len(hrows)
        if total!=1568:
            raise SystemExit(f"F_PE_ELASTIC23_FAIL horizon total={total}")
        print("F_PE_ELASTIC23_A2_ALL_PROFILES=PASS")
        print("F_PE_ELASTIC23_A3_ALL_HORIZONS=PASS")
        print("F_PE_ELASTIC23_A4_SQL_IDENTITY=PASS")

        if 16160 not in ids:
            raise SystemExit("F_PE_ELASTIC23_FAIL profile 16160 missing")
        known=tool.retrieve_profile(gpkg,16160)
        prow,hrows=direct_rows(con,16160)
        if not compare_profile(known,prow,hrows,tool.SOURCE_ARTIFACT_SHA256):
            raise SystemExit("F_PE_ELASTIC23_FAIL profile 16160 mismatch")
        print("F_PE_ELASTIC23_A5_PROFILE_16160=PASS")

        for bad_id in (999999999,-1,0):
            try:
                tool.retrieve_profile(gpkg,bad_id)
            except tool.Elastic24Error:
                pass
            else:
                raise SystemExit(f"F_PE_ELASTIC23_FAIL invalid profile accepted={bad_id}")
        print("F_PE_ELASTIC23_A6_PROFILE_FAIL_CLOSED=PASS")
    finally:
        con.close()

    with tempfile.TemporaryDirectory() as td:
        broken=Path(td)/"broken.gpkg"
        c=sqlite3.connect(broken)
        try:
            c.execute("create table normalsoilprofiles(normalsoilprofile_id integer)")
            c.execute("create table soilhorizon(normalsoilprofile_id integer)")
            c.commit()
        finally:
            c.close()
        try:
            tool.retrieve_profile(broken,1)
        except tool.Elastic24Error:
            pass
        else:
            raise SystemExit("F_PE_ELASTIC23_FAIL malformed schema did not fail")

        badgeo=Path(td)/"badgeo.gpkg"
        build_bad_geometry_db(badgeo)
        try:
            tool.retrieve_profile(badgeo,1)
        except tool.Elastic24Error:
            pass
        else:
            raise SystemExit("F_PE_ELASTIC23_FAIL malformed geometry did not fail")
    print("F_PE_ELASTIC23_A7_FAIL_CLOSED=PASS")

    first=tool.retrieve_profile(gpkg,ids[0])
    second=tool.retrieve_profile(gpkg,ids[0])
    if json.dumps(first,sort_keys=True,separators=(",",":")) != json.dumps(second,sort_keys=True,separators=(",",":")):
        raise SystemExit("F_PE_ELASTIC23_FAIL nondeterministic repeat")
    print("F_PE_ELASTIC23_A8_REPEAT_IDENTITY=PASS")

    if first["source_artifact_sha256"] != "f96bea1e9efdd0326ae1ca0d72684cd7928c90fd23f0930b51c782dfc0ff5fe6":
        raise SystemExit("F_PE_ELASTIC23_FAIL provenance hash")
    print("F_PE_ELASTIC23_A9_PROVENANCE=PASS")

    source=(root/"tools/fpe_elastic24_profile_retrieval.py").read_text(encoding="utf-8").lower()
    forbidden=("urllib","requests","http://","https://","latitude","longitude","socket","theta_ref","elas_prior")
    hits=[x for x in forbidden if x in source]
    if hits:
        raise SystemExit("F_PE_ELASTIC23_FAIL forbidden semantics="+repr(hits))
    print("F_PE_ELASTIC23_A10_BOUNDARY_HYGIENE=PASS")
    print("F_PE_ELASTIC23=PASS")

if __name__=="__main__":
    main()
