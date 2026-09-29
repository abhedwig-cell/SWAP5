#!/usr/bin/env python3
"""Prepare F-PE-ELASTIC35 frozen-profile interchange fixtures."""
from __future__ import annotations
import argparse, importlib.util, sqlite3
from pathlib import Path

def load_module(path:Path,name:str):
    spec=importlib.util.spec_from_file_location(name,path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"F_PE_ELASTIC35_FAIL cannot load {path}")
    mod=importlib.util.module_from_spec(spec); spec.loader.exec_module(mod); return mod

def find_one_gpkg(root:Path):
    hits=list(root.rglob("*.gpkg"))
    if len(hits)!=1:
        raise SystemExit(f"F_PE_ELASTIC35_FAIL gpkg hits={len(hits)}")
    return hits[0]

def mutate_line(text:str,index:int,new_line:str)->str:
    lines=text.splitlines()
    lines[index]=new_line
    return "\n".join(lines)+"\n"

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--repo-root",required=True)
    ap.add_argument("--artifact-dir",required=True)
    ap.add_argument("--output-dir",required=True)
    a=ap.parse_args()
    root=Path(a.repo_root); out=Path(a.output_dir); out.mkdir(parents=True,exist_ok=True)
    e24=load_module(root/"tools/fpe_elastic24_profile_retrieval.py","elastic24")
    e33=load_module(root/"tools/fpe_elastic33_profile_row_interchange.py","elastic33")
    gpkg=find_one_gpkg(Path(a.artifact_dir))

    con=sqlite3.connect(f"file:{gpkg.resolve()}?mode=ro",uri=True)
    try:
        ids=[int(r[0]) for r in con.execute("select normalsoilprofile_id from normalsoilprofiles order by normalsoilprofile_id")]
    finally:
        con.close()
    if len(ids)!=368 or len(set(ids))!=368:
        raise SystemExit(f"F_PE_ELASTIC35_FAIL profile count={len(ids)}")

    manifest=[]
    total=0
    first_text=None
    for pid in ids:
        profile=e24.retrieve_profile(gpkg,pid)
        text=e33.materialize_interchange(profile)
        path=out/f"profile_{pid}.rows"
        path.write_text(text,encoding="utf-8")
        manifest.append(f"{pid}|{path}|{profile['horizon_count']}")
        total+=profile["horizon_count"]
        if first_text is None:
            first_text=text
    if total!=1568:
        raise SystemExit(f"F_PE_ELASTIC35_FAIL row total={total}")
    (out/"manifest.txt").write_text("\n".join(manifest)+"\n",encoding="utf-8")
    print("F_PE_ELASTIC35_PREP_A2_ALL_PROFILES=PASS")
    print("F_PE_ELASTIC35_PREP_A3_ALL_ROWS=PASS")

    assert first_text is not None
    lines=first_text.splitlines()
    # Header/provenance/schema failures.
    (out/"bad_magic.rows").write_text(mutate_line(first_text,0,"BAD_MAGIC"),encoding="utf-8")
    (out/"bad_hash.rows").write_text(mutate_line(first_text,1,"source_artifact_sha256="+"0"*64),encoding="utf-8")
    (out/"bad_columns.rows").write_text(mutate_line(first_text,4,"columns=wrong"),encoding="utf-8")
    count=int(lines[3].split("=",1)[1])
    (out/"bad_count.rows").write_text(mutate_line(first_text,3,f"row_count={count+1}"),encoding="utf-8")

    # Row/data failures based on first row.
    row=lines[5].split("|")
    bad=row[:-1]
    (out/"bad_width.rows").write_text(mutate_line(first_text,5,"|".join(bad)),encoding="utf-8")
    r=row.copy(); r[0]=str(int(r[0])+1)
    (out/"bad_profile.rows").write_text(mutate_line(first_text,5,"|".join(r)),encoding="utf-8")
    r=row.copy(); r[1]="2"
    (out/"bad_layer.rows").write_text(mutate_line(first_text,5,"|".join(r)),encoding="utf-8")
    r=row.copy(); r[3]=r[2]
    (out/"bad_geometry.rows").write_text(mutate_line(first_text,5,"|".join(r)),encoding="utf-8")
    r=row.copy(); r[5]="-1"
    (out/"bad_density.rows").write_text(mutate_line(first_text,5,"|".join(r)),encoding="utf-8")
    r=row.copy(); r[6]="2"
    (out/"bad_flag.rows").write_text(mutate_line(first_text,5,"|".join(r)),encoding="utf-8")
    (out/"extra_record.rows").write_text(first_text+"EXTRA\n",encoding="utf-8")

    print("F_PE_ELASTIC35_PREP_INVALID_FIXTURES=PASS")

if __name__=="__main__":
    main()
