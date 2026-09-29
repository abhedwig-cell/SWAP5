#!/usr/bin/env python3
"""F-PE-ELASTIC41 qualification over frozen BRO authority."""
from __future__ import annotations

import argparse
import importlib.util
import json
import sys
import tempfile
from pathlib import Path

def load(name: str, path: Path):
    spec=importlib.util.spec_from_file_location(name,path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"F_PE_ELASTIC41_FAIL cannot load {path}")
    mod=importlib.util.module_from_spec(spec)
    sys.modules[spec.name]=mod
    spec.loader.exec_module(mod)
    return mod

def req(cond,msg):
    if not cond:
        raise SystemExit("F_PE_ELASTIC41_FAIL "+msg)

def find_one_gpkg(root: Path) -> Path:
    hits=list(root.rglob("*.gpkg"))
    if len(hits)!=1:
        raise SystemExit(f"F_PE_ELASTIC41_FAIL gpkg hits={len(hits)}")
    return hits[0]

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--repo-root",required=True)
    ap.add_argument("--artifact-dir",required=True)
    a=ap.parse_args()
    root=Path(a.repo_root)
    tools=root/"tools"
    if str(tools) not in sys.path:
        sys.path.insert(0,str(tools))

    e34=load("fpe_elastic34_rd_point_maparea",tools/"fpe_elastic34_rd_point_maparea.py")
    e36=load("fpe_elastic36_rd_point_profile_interchange",tools/"fpe_elastic36_rd_point_profile_interchange.py")
    e41=load("fpe_elastic41_rd_application_handoff",tools/"fpe_elastic41_rd_application_handoff.py")
    gpkg=find_one_gpkg(Path(a.artifact_dir))

    with tempfile.TemporaryDirectory() as td:
        td=Path(td)
        row=td/"inactive.rows"
        prov=td/"inactive.json"
        result=e41.prepare_handoff(False,Path("definitely-missing.gpkg"),float("nan"),float("nan"),row,prov)
        req(result["status"]=="INACTIVE" and not row.exists() and not prov.exists(),"A1 inactive")
        print("F_PE_ELASTIC41_A1_INACTIVE_NO_SOURCE_IO=PASS")

    polygons=e34.load_polygons(gpkg)
    n=len(polygons)
    indices=sorted({round(i*(n-1)/63) for i in range(64)})
    successes=0
    first_case=None
    original_compose=e41.elastic36.compose
    def cached_compose(source,x,y):
        return e36.compose(source,x,y,polygons=polygons)
    e41.elastic36.compose=cached_compose
    with tempfile.TemporaryDirectory() as td:
        td=Path(td)
        for slot,idx in enumerate(indices):
            poly=polygons[idx]
            probe=e34.strict_probe(poly)
            req(probe is not None,f"A4 no strict probe {poly.maparea_id}")
            expected_prov,expected_rows=e36.compose(gpkg,probe[0],probe[1],polygons=polygons)
            row=td/f"rows-{slot}.txt"
            prov=td/f"prov-{slot}.json"
            result=e41.prepare_handoff(True,gpkg,probe[0],probe[1],row,prov)
            req(result["status"]=="OK" and row.exists() and prov.exists(),f"A2 outputs {slot}")
            actual_rows=row.read_text(encoding="utf-8")
            req(actual_rows==expected_rows,f"A2 row identity {slot}")
            manifest=json.loads(prov.read_text(encoding="utf-8"))
            req(manifest["schema"]==e41.SCHEMA,f"A3 schema got={manifest.get('schema')!r} expected={e41.SCHEMA!r}")
            req(manifest["generated_prior_requested"] is True,f"A3 request flag got={manifest.get('generated_prior_requested')!r}")
            req(manifest["row_file"]==str(row),"A3 row path")
            for key in ("source_artifact_sha256","srs_id","x_rd_m","y_rd_m","maparea_id","normalsoilprofile_id","horizon_count"):
                req(manifest[key]==expected_prov[key],f"A3 provenance {key} {slot}")
            req(actual_rows.startswith("SWAP5_ELASTIC33_BRO_ROWS_V1\n"),"A9 row magic")
            if first_case is None:
                first_case=(probe,actual_rows,prov.read_bytes(),str(row),str(prov))
            successes+=1
        req(successes==64,"A4 sample count")
        print("F_PE_ELASTIC41_A2_ELASTIC36_ROW_IDENTITY=PASS")
        print("F_PE_ELASTIC41_A3_PROVENANCE_IDENTITY=PASS")
        print("F_PE_ELASTIC41_A4_REAL_SOURCE_SAMPLE=PASS")
        print("F_PE_ELASTIC41_A9_ELASTIC37_CONSUMABLE_ROWS=PASS")

        probe,first_rows,first_prov,row_name,prov_name=first_case
        row=Path(row_name); prov=Path(prov_name)
        result=e41.prepare_handoff(True,gpkg,probe[0],probe[1],row,prov)
        req(row.read_text(encoding="utf-8")==first_rows and prov.read_bytes()==first_prov,"A7 repeat")
        print("F_PE_ELASTIC41_A7_REPEAT_IDENTITY=PASS")

    e41.elastic36.compose=original_compose

    with tempfile.TemporaryDirectory() as td:
        td=Path(td)
        row=td/"fail.rows"; prov=td/"fail.json"
        try:
            e41.prepare_handoff(True,Path("missing.gpkg"),100000.0,450000.0,row,prov)
        except e41.Elastic41Error:
            pass
        else:
            req(False,"A6 missing active accepted")
        req(not row.exists() and not prov.exists(),"A6 partial output")
        inactive=e41.prepare_handoff(False,Path("missing.gpkg"),100000.0,450000.0,row,prov)
        req(inactive["status"]=="INACTIVE" and not row.exists() and not prov.exists(),"A6 inactive missing")
        print("F_PE_ELASTIC41_A6_SOURCE_FAIL_CLOSED=PASS")

    # Parent ELASTIC36 already qualifies actual BOUNDARY/NOT_FOUND/AMBIGUOUS semantics.
    # Here we verify ELASTIC41 propagates those parent failures atomically.
    original=e41.elastic36.compose
    try:
        for code in ("SPATIAL_BOUNDARY","SPATIAL_NOT_FOUND","SPATIAL_AMBIGUOUS"):
            def reject(*args,_code=code,**kwargs):
                raise e36.Elastic36Error(_code)
            e41.elastic36.compose=reject
            with tempfile.TemporaryDirectory() as td:
                td=Path(td); row=td/"fail.rows"; prov=td/"fail.json"
                try:
                    e41.prepare_handoff(True,gpkg,1.0,1.0,row,prov)
                except e41.Elastic41Error as exc:
                    req(code in str(exc),f"A5 provenance {code}")
                else:
                    req(False,f"A5 accepted {code}")
                req(not row.exists() and not prov.exists(),f"A5 partial {code}")
    finally:
        e41.elastic36.compose=original
    print("F_PE_ELASTIC41_A5_SPATIAL_FAIL_CLOSED=PASS")
    print("F_PE_ELASTIC41_A8_INACTIVE_SOURCE_INDEPENDENCE=PASS")
    print("F_PE_ELASTIC41=PASS")

if __name__=="__main__":
    main()
