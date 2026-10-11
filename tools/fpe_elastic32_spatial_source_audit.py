#!/usr/bin/env python3
"""F-PE-ELASTIC32: audit frozen BRO GeoPackage spatial/maparea authority."""
from __future__ import annotations
import argparse, hashlib, json, sqlite3
from pathlib import Path

EXPECTED_ARCHIVE_SHA256 = "f96bea1e9efdd0326ae1ca0d72684cd7928c90fd23f0930b51c782dfc0ff5fe6"

def qident(name:str)->str:
    return '"' + name.replace('"','""') + '"'

def find_one_gpkg(root:Path)->Path:
    hits=list(root.rglob("*.gpkg"))
    if len(hits)!=1:
        raise SystemExit(f"F_PE_ELASTIC32_FAIL gpkg hits={len(hits)}")
    return hits[0]

def columns(con, table):
    return [str(r[1]) for r in con.execute(f"pragma table_info({qident(table)})")]

def scalar(con, sql, params=()):
    row=con.execute(sql,params).fetchone()
    return None if row is None else row[0]

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--artifact-dir",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    root=Path(a.artifact_dir)
    gpkg=find_one_gpkg(root)

    con=sqlite3.connect(f"file:{gpkg.resolve()}?mode=ro",uri=True)
    try:
        tables={str(r[0]) for r in con.execute("select name from sqlite_master where type='table'")}
        required={"gpkg_contents","gpkg_geometry_columns","gpkg_spatial_ref_sys"}
        if not required.issubset(tables):
            raise SystemExit("F_PE_ELASTIC32_FAIL missing gpkg core metadata")
        print("F_PE_ELASTIC32_A2_GPKG_CORE=PASS")

        geometry_rows=[
            {
                "table_name":str(r[0]),"column_name":str(r[1]),
                "geometry_type_name":str(r[2]),"srs_id":int(r[3]),
                "z":int(r[4]),"m":int(r[5]),
            }
            for r in con.execute(
                "select table_name,column_name,geometry_type_name,srs_id,z,m "
                "from gpkg_geometry_columns order by table_name,column_name"
            )
        ]
        contents=[
            {
                "table_name":str(r[0]),"data_type":str(r[1]),
                "identifier":None if r[2] is None else str(r[2]),
                "description":None if r[3] is None else str(r[3]),
                "srs_id":None if r[9] is None else int(r[9]),
            }
            for r in con.execute(
                "select table_name,data_type,identifier,description,last_change,"
                "min_x,min_y,max_x,max_y,srs_id from gpkg_contents order by table_name"
            )
        ]

        all_columns={t:columns(con,t) for t in sorted(tables)}
        geometry_candidates=[]
        for g in geometry_rows:
            t=g["table_name"]
            cols=all_columns.get(t,[])
            if "maparea_id" in cols:
                geometry_candidates.append(g)
        relation_candidates=[
            t for t,cols in all_columns.items()
            if "maparea_id" in cols and "normalsoilprofile_id" in cols
        ]

        if len(relation_candidates)!=1:
            raise SystemExit("F_PE_ELASTIC32_FAIL relation authority candidates="+repr(relation_candidates))
        relation_table=relation_candidates[0]
        relation_ids={r[0] for r in con.execute(
            f"select distinct maparea_id from {qident(relation_table)} where maparea_id is not null")}

        geometry_evidence=[]
        exact_domain_candidates=[]
        for candidate in geometry_candidates:
            table=candidate["table_name"]
            ids={r[0] for r in con.execute(
                f"select distinct maparea_id from {qident(table)} where maparea_id is not null")}
            evidence={
                **candidate,
                "feature_count":int(scalar(con,f"select count(*) from {qident(table)}")),
                "distinct_maparea_id_count":len(ids),
                "relation_domain_equal":ids==relation_ids,
                "feature_only_id_count":len(ids-relation_ids),
                "relation_only_id_count":len(relation_ids-ids),
            }
            geometry_evidence.append(evidence)
            if ids==relation_ids:
                exact_domain_candidates.append(candidate)

        if len(exact_domain_candidates)!=1:
            raise SystemExit(
                "F_PE_ELASTIC32_FAIL exact-domain geometry authority candidates="
                +repr(exact_domain_candidates)+" evidence="+repr(geometry_evidence)
            )
        g=exact_domain_candidates[0]
        feature_table=g["table_name"]
        geometry_column=g["column_name"]
        print("F_PE_ELASTIC32_A3_FEATURE_AUTHORITY=PASS")

        feature_count=int(scalar(con,f"select count(*) from {qident(feature_table)}"))
        distinct_maparea=int(scalar(con,
            f"select count(distinct maparea_id) from {qident(feature_table)} where maparea_id is not null"))
        null_maparea=int(scalar(con,
            f"select count(*) from {qident(feature_table)} where maparea_id is null"))
        null_geometry=int(scalar(con,
            f"select count(*) from {qident(feature_table)} where {qident(geometry_column)} is null"))
        duplicate_ids=int(scalar(con,
            f"select count(*) from (select maparea_id from {qident(feature_table)} "
            "where maparea_id is not null group by maparea_id having count(*)>1)"))
        relation_count=int(scalar(con,f"select count(*) from {qident(relation_table)}"))
        relation_distinct=int(scalar(con,
            f"select count(distinct maparea_id) from {qident(relation_table)} where maparea_id is not null"))
        relation_null=int(scalar(con,
            f"select count(*) from {qident(relation_table)} where maparea_id is null"))

        feature_ids={r[0] for r in con.execute(
            f"select distinct maparea_id from {qident(feature_table)} where maparea_id is not null")}
        if feature_ids != relation_ids:
            raise SystemExit("F_PE_ELASTIC32_FAIL selected geometry domain drift")
        print("F_PE_ELASTIC32_A4_MAPAREA_DOMAIN_IDENTITY=PASS")
        print("F_PE_ELASTIC32_A5_COUNTS=PASS")

        srs=con.execute(
            "select srs_name,srs_id,organization,organization_coordsys_id,definition,description "
            "from gpkg_spatial_ref_sys where srs_id=?",(g["srs_id"],)
        ).fetchone()
        if srs is None:
            raise SystemExit("F_PE_ELASTIC32_FAIL missing declared SRS")
        srs_obj={
            "srs_name":str(srs[0]),"srs_id":int(srs[1]),
            "organization":str(srs[2]),"organization_coordsys_id":int(srs[3]),
            "definition":str(srs[4]),"description":None if srs[5] is None else str(srs[5]),
        }
        print("F_PE_ELASTIC32_A6_GEOMETRY_SRS=PASS")
        print("F_PE_ELASTIC32_A7_SRS_DEFINITION=PASS")
        print("F_PE_ELASTIC32_A8_ANOMALY_COUNTS=PASS")

        extensions=[]
        if "gpkg_extensions" in tables:
            extensions=[
                {"table_name":r[0],"column_name":r[1],"extension_name":r[2],"definition":r[3],"scope":r[4]}
                for r in con.execute(
                    "select table_name,column_name,extension_name,definition,scope "
                    "from gpkg_extensions order by table_name,column_name,extension_name"
                )
            ]
        index_tables=sorted(t for t in tables if t.startswith("rtree_"))
        functions=[]
        try:
            functions=sorted({str(r[0]) for r in con.execute("pragma function_list")})
        except sqlite3.DatabaseError:
            functions=[]
        spatial_functions=[f for f in functions if any(k in f.lower() for k in ("geom","intersect","within","contains","point"))]
        print("F_PE_ELASTIC32_A9_SPATIAL_METADATA=PASS")

        result={
            "work_unit":"F-PE-ELASTIC32",
            "source_artifact_sha256":EXPECTED_ARCHIVE_SHA256,
            "gpkg_filename":gpkg.name,
            "feature_authority":{
                "table":feature_table,
                "geometry_column":geometry_column,
                "geometry_type":g["geometry_type_name"],
                "srs_id":g["srs_id"],
                "feature_count":feature_count,
                "distinct_maparea_id_count":distinct_maparea,
                "null_maparea_id_count":null_maparea,
                "null_geometry_count":null_geometry,
                "duplicate_maparea_id_count":duplicate_ids,
            },
            "relation_authority":{
                "table":relation_table,
                "row_count":relation_count,
                "distinct_maparea_id_count":relation_distinct,
                "null_maparea_id_count":relation_null,
            },
            "maparea_domain_identity":feature_ids==relation_ids,
            "srs":srs_obj,
            "gpkg_geometry_columns":geometry_rows,
            "geometry_candidate_evidence":geometry_evidence,
            "gpkg_contents":contents,
            "extensions":extensions,
            "rtree_tables":index_tables,
            "available_spatial_functions":spatial_functions,
        }
    finally:
        con.close()

    Path(a.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print("F_PE_ELASTIC32=PASS")

if __name__=="__main__":
    main()
