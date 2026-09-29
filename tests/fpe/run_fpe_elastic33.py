#!/usr/bin/env python3
"""F-PE-ELASTIC33 qualification over frozen ELASTIC24 source authority."""
from __future__ import annotations
import argparse, copy, importlib.util, json, sqlite3, struct
from pathlib import Path

def load_module(path: Path, name: str):
    spec=importlib.util.spec_from_file_location(name,path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"F_PE_ELASTIC33_FAIL cannot load {path}")
    mod=importlib.util.module_from_spec(spec); spec.loader.exec_module(mod); return mod

def find_one_gpkg(root: Path) -> Path:
    hits=list(root.rglob("*.gpkg"))
    if len(hits)!=1:
        raise SystemExit(f"F_PE_ELASTIC33_FAIL gpkg hits={len(hits)}")
    return hits[0]

def bits(x: float) -> bytes:
    return struct.pack(">d",float(x))

def parse_interchange(text: str):
    lines=text.splitlines()
    if len(lines)<5:
        raise SystemExit("F_PE_ELASTIC33_FAIL short interchange")
    if lines[0]!="SWAP5_ELASTIC33_BRO_ROWS_V1":
        raise SystemExit("F_PE_ELASTIC33_FAIL magic")
    meta={}
    for line in lines[1:4]:
        k,v=line.split("=",1); meta[k]=v
    cols=lines[4].split("=",1)[1].split("|")
    rows=[]
    for line in lines[5:]:
        vals=line.split("|")
        if len(vals)!=len(cols):
            raise SystemExit("F_PE_ELASTIC33_FAIL row width")
        rows.append(dict(zip(cols,vals)))
    return meta,cols,rows

def expect_error(tool, profile, label):
    try:
        tool.materialize_interchange(profile)
    except tool.Elastic33Error:
        return
    raise SystemExit(f"F_PE_ELASTIC33_FAIL expected rejection {label}")

def f64_literal(x: float) -> str:
    return format(float(x),".17g")+"_real64"

def write_fortran_fixture(path: Path, profile: dict, rows):
    n=len(rows)
    lines=[
"program test_fpe_elastic33_fortran_composition",
"  use, intrinsic :: iso_fortran_env, only: real64",
"  use mod_fmr_elastic_storage_explicit_profile_source, only: &",
"       fmr_elastic_storage_bro_horizon_row_t, fmr_elastic_storage_profile_source_diagnostics_t, &",
"       fmr_build_explicit_bro_profile_horizons, FMR_ELAS_PROFILE_SOURCE_OK",
"  use mod_fmr_elastic_storage_horizon_node_mapper, only: fmr_elastic_storage_horizon_t",
"  implicit none",
f"  type(fmr_elastic_storage_bro_horizon_row_t) :: rows({n})",
"  type(fmr_elastic_storage_horizon_t), allocatable :: horizons(:)",
"  type(fmr_elastic_storage_profile_source_diagnostics_t) :: diag",
"  integer, allocatable :: layers(:), catalog(:)",
]
    for i,(src,row) in enumerate(zip(profile["horizons"],rows),start=1):
        om_av=row["organic_matter_available"]=="1"
        peat=row["peat_type_present"]=="1"
        lines.append(
f"  rows({i})=fmr_elastic_storage_bro_horizon_row_t({profile['normalsoilprofile_id']},{i},"
f"{f64_literal(float(row['top_depth_m']))},{f64_literal(float(row['bottom_depth_m']))},"
f"{int(row['staringseriesblock'])},{f64_literal(float(row['rho_dry_g_cm3']))},"
f"{'.true.' if om_av else '.false.'},{f64_literal(float(row['organic_matter_pct']))},"
f"{'.true.' if peat else '.false.'})")
    lines += [
f"  call fmr_build_explicit_bro_profile_horizons(rows,{profile['normalsoilprofile_id']},horizons,layers,catalog,diag)",
"  if(diag%status/=FMR_ELAS_PROFILE_SOURCE_OK) error stop 1",
f"  if(diag%selected_rows/={n}) error stop 1",
f"  if(size(horizons)/={n}) error stop 1",
"  if(any(layers/=[(" + "i,i=1,"+str(n) + ")])) error stop 1",
"  do i=1,size(horizons)",
"    if(horizons(i)%top_depth_m/=rows(i)%top_depth_m) error stop 1",
"    if(horizons(i)%bottom_depth_m/=rows(i)%bottom_depth_m) error stop 1",
"    if(horizons(i)%rho_dry_g_cm3/=rows(i)%rho_dry_g_cm3) error stop 1",
"  end do",
"  write(*,'(A)')'F_PE_ELASTIC33_A9_FORTRAN_COMPOSITION=PASS'",
"contains",
"  integer function dummy()",
"    dummy=0",
"  end function dummy",
"end program test_fpe_elastic33_fortran_composition",
]
    # insert loop variable declaration cleanly
    lines.insert(11,"  integer :: i")
    path.write_text("\n".join(lines)+"\n",encoding="utf-8")

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--repo-root",required=True)
    ap.add_argument("--artifact-dir",required=True)
    ap.add_argument("--fixture",required=True)
    a=ap.parse_args()
    root=Path(a.repo_root)
    e24=load_module(root/"tools/fpe_elastic24_profile_retrieval.py","elastic24")
    e33=load_module(root/"tools/fpe_elastic33_profile_row_interchange.py","elastic33")
    gpkg=find_one_gpkg(Path(a.artifact_dir))

    con=sqlite3.connect(f"file:{gpkg.resolve()}?mode=ro",uri=True)
    try:
        ids=[int(r[0]) for r in con.execute("select normalsoilprofile_id from normalsoilprofiles order by normalsoilprofile_id")]
    finally:
        con.close()
    if len(ids)!=368 or len(set(ids))!=368:
        raise SystemExit(f"F_PE_ELASTIC33_FAIL profile count={len(ids)}")

    total=0
    mineral_fixture=None
    saw_null_om=False
    saw_present_om=False
    saw_null_peat=False
    saw_present_peat=False

    for pid in ids:
        profile=e24.retrieve_profile(gpkg,pid)
        text=e33.materialize_interchange(profile)
        meta,cols,rows=parse_interchange(text)
        if meta["source_artifact_sha256"]!=e33.SOURCE_ARTIFACT_SHA256:
            raise SystemExit("F_PE_ELASTIC33_FAIL hash projection")
        if int(meta["normalsoilprofile_id"])!=pid or int(meta["row_count"])!=len(profile["horizons"]):
            raise SystemExit(f"F_PE_ELASTIC33_FAIL header identity {pid}")
        if tuple(cols)!=e33.COLUMNS:
            raise SystemExit("F_PE_ELASTIC33_FAIL columns")
        if len(rows)!=len(profile["horizons"]):
            raise SystemExit(f"F_PE_ELASTIC33_FAIL row count {pid}")

        all_mineral=True
        for src,row in zip(profile["horizons"],rows):
            if int(row["normalsoilprofile_id"])!=pid or int(row["layer_number"])!=src["layernumber"]:
                raise SystemExit(f"F_PE_ELASTIC33_FAIL identity {pid}")
            for outkey,inkey in (("top_depth_m","top_depth_m"),("bottom_depth_m","bottom_depth_m"),("rho_dry_g_cm3","dry_density_g_cm3")):
                if bits(float(row[outkey]))!=bits(float(src[inkey])):
                    raise SystemExit(f"F_PE_ELASTIC33_FAIL f64 identity {pid} {outkey}")
            if int(row["staringseriesblock"])!=src["staringseriesblock"]:
                raise SystemExit(f"F_PE_ELASTIC33_FAIL block identity {pid}")
            if src["organic_matter_pct"] is None:
                saw_null_om=True
                if row["organic_matter_available"]!="0" or float(row["organic_matter_pct"])!=0.0:
                    raise SystemExit("F_PE_ELASTIC33_FAIL null organic projection")
                all_mineral=False
            else:
                saw_present_om=True
                if row["organic_matter_available"]!="1" or bits(float(row["organic_matter_pct"]))!=bits(float(src["organic_matter_pct"])):
                    raise SystemExit("F_PE_ELASTIC33_FAIL organic identity")
                if float(src["organic_matter_pct"])>15.0:
                    all_mineral=False
            if src["peat_type"] is None:
                saw_null_peat=True
                if row["peat_type_present"]!="0":
                    raise SystemExit("F_PE_ELASTIC33_FAIL null peat projection")
            else:
                saw_present_peat=True
                if row["peat_type_present"]!="1":
                    raise SystemExit("F_PE_ELASTIC33_FAIL peat presence projection")
                all_mineral=False
        total+=len(rows)
        if mineral_fixture is None and all_mineral:
            mineral_fixture=(profile,rows)

    if total!=1568:
        raise SystemExit(f"F_PE_ELASTIC33_FAIL total rows={total}")
    print("F_PE_ELASTIC33_A1_SOURCE_GATE=PASS")
    print("F_PE_ELASTIC33_A2_ROW_MAPPING=PASS")
    print("F_PE_ELASTIC33_A3_F64_IDENTITY=PASS")
    synthetic=copy.deepcopy(e24.retrieve_profile(gpkg,16160))
    synthetic["horizons"][0]["organic_matter_pct"]=None
    _,_,srows=parse_interchange(e33.materialize_interchange(synthetic))
    if srows[0]["organic_matter_available"]!="0" or float(srows[0]["organic_matter_pct"])!=0.0:
        raise SystemExit("F_PE_ELASTIC33_FAIL synthetic null organic projection")
    synthetic["horizons"][0]["organic_matter_pct"]=7.5
    _,_,srows=parse_interchange(e33.materialize_interchange(synthetic))
    if srows[0]["organic_matter_available"]!="1" or bits(float(srows[0]["organic_matter_pct"]))!=bits(7.5):
        raise SystemExit("F_PE_ELASTIC33_FAIL synthetic present organic projection")
    print("F_PE_ELASTIC33_A4_ORGANIC_PROJECTION=PASS")

    synthetic=copy.deepcopy(e24.retrieve_profile(gpkg,16160))
    synthetic["horizons"][0]["peat_type"]=None
    _,_,srows=parse_interchange(e33.materialize_interchange(synthetic))
    if srows[0]["peat_type_present"]!="0":
        raise SystemExit("F_PE_ELASTIC33_FAIL synthetic null peat projection")
    synthetic["horizons"][0]["peat_type"]="PEAT_PRESENT_SENTINEL"
    _,_,srows=parse_interchange(e33.materialize_interchange(synthetic))
    if srows[0]["peat_type_present"]!="1":
        raise SystemExit("F_PE_ELASTIC33_FAIL synthetic present peat projection")
    print("F_PE_ELASTIC33_A5_PEAT_PROJECTION=PASS")
    print("F_PE_ELASTIC33_A9_ALL_PROFILES=PASS")
    print("F_PE_ELASTIC33_A9_ALL_ROWS=PASS")

    base=e24.retrieve_profile(gpkg,16160)
    cases=[]
    p=copy.deepcopy(base); p["schema"]="bad"; cases.append(("schema",p))
    p=copy.deepcopy(base); p["source_artifact_sha256"]="0"*64; cases.append(("hash",p))
    p=copy.deepcopy(base); p["horizon_count"]+=1; cases.append(("count",p))
    p=copy.deepcopy(base); p["horizons"][0]["layernumber"]=2; cases.append(("order",p))
    p=copy.deepcopy(base); p["horizons"][0]["bottom_depth_m"]=p["horizons"][0]["top_depth_m"]; cases.append(("geometry",p))
    p=copy.deepcopy(base); p["horizons"][0]["dry_density_g_cm3"]=-1.0; cases.append(("density",p))
    p=copy.deepcopy(base); p["horizons"][0]["organic_matter_pct"]=101.0; cases.append(("organic",p))
    for label,p in cases: expect_error(e33,p,label)
    print("F_PE_ELASTIC33_A6_SCHEMA_FAIL_CLOSED=PASS")
    print("F_PE_ELASTIC33_A7_DATA_FAIL_CLOSED=PASS")

    first=e33.materialize_interchange(base)
    second=e33.materialize_interchange(copy.deepcopy(base))
    if first.encode()!=second.encode():
        raise SystemExit("F_PE_ELASTIC33_FAIL nondeterministic bytes")
    print("F_PE_ELASTIC33_A8_BYTE_IDENTITY=PASS")

    if mineral_fixture is None:
        raise SystemExit("F_PE_ELASTIC33_FAIL no mineral fixture profile")
    write_fortran_fixture(Path(a.fixture),*mineral_fixture)
    print("F_PE_ELASTIC33=PASS")

if __name__=="__main__":
    main()
