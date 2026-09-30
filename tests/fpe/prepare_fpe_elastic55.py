#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, re, sqlite3, subprocess, sys
from pathlib import Path

EXCLUDE=90116260
SOURCE_SHA="f96bea1e9efdd0326ae1ca0d72684cd7928c90fd23f0930b51c782dfc0ff5fe6"

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    if spec is None or spec.loader is None: raise SystemExit(f"F_PE_ELASTIC55_FAIL load {path}")
    mod=importlib.util.module_from_spec(spec); sys.modules[spec.name]=mod; spec.loader.exec_module(mod); return mod

def gpkg_one(d):
    hits=list(Path(d).rglob("*.gpkg"))
    if len(hits)!=1: raise SystemExit(f"F_PE_ELASTIC55_FAIL gpkg hits={len(hits)}")
    return hits[0].resolve()

def select_profiles(gpkg:Path):
    con=sqlite3.connect(f"file:{gpkg}?mode=ro",uri=True)
    try:
        pids=[int(r[0]) for r in con.execute("select normalsoilprofile_id from normalsoilprofiles order by normalsoilprofile_id")]
        eligible=[]
        for pid in pids:
            if pid<=0 or pid==EXCLUDE: continue
            prow=con.execute("select soilunit from normalsoilprofiles where normalsoilprofile_id=?",(pid,)).fetchone()
            rows=list(con.execute(
                "select layernumber,lowervalue,uppervalue,staringseriesblock,organicmattercontent,peattype,density "
                "from soilhorizon where normalsoilprofile_id=? order by layernumber",(pid,)))
            if not rows or len(rows)>16: continue
            ok=True; prev=None; blocks=[]
            for idx,(layer,low,up,block,om,peat,density) in enumerate(rows,1):
                if int(layer)!=idx: ok=False; break
                low=float(low); up=float(up)
                if up<=low or (idx==1 and abs(low)>1e-10) or (prev is not None and abs(low-prev)>1e-10): ok=False; break
                prev=up
                ib=int(block)
                if not (101<=ib<=118 or 201<=ib<=218): ok=False; break
                if peat is not None: ok=False; break
                if density is None or float(density)<=0: ok=False; break
                if om is not None and float(om)>20.0: ok=False; break
                blocks.append(ib)
            if ok:
                eligible.append({"profile_id":pid,"soilunit":None if prow is None else prow[0],
                                 "horizon_count":len(rows),"blocks":blocks})
    finally:
        con.close()
    uniq=[]; seen=set()
    for p in eligible:
        key=(p["soilunit"],p["horizon_count"],tuple(p["blocks"]))
        if key in seen: continue
        seen.add(key); uniq.append(p)
    classes=sorted({p["horizon_count"] for p in uniq})
    if len(classes)<4: raise SystemExit(f"F_PE_ELASTIC55_FAIL horizon classes={classes}")
    selected=[]
    for hc in classes[:4]:
        candidates=[p for p in uniq if p["horizon_count"]==hc]
        selected.append(min(candidates,key=lambda x:x["profile_id"]))
    return selected

def parse_catalog(root:Path):
    text=(root/"src/adapter/mod_fmr_elastic_storage_staringreeks_catalog.f90").read_text(encoding="utf-8")
    out={}
    for name in ("WCR","WCS","ALPHA","NPAR"):
        m=re.search(rf"{name}\(FMR_STARINGREEKS_CATALOG_COUNT\)\s*=\s*\[\s*&(?P<body>.*?)\]",text,re.S)
        if not m: raise SystemExit(f"F_PE_ELASTIC55_FAIL catalog {name}")
        vals=[float(x) for x in re.findall(r"([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[Ee][+-]?\d+)?)_real64",m.group("body"))]
        if len(vals)!=36: raise SystemExit(f"F_PE_ELASTIC55_FAIL catalog {name} count={len(vals)}")
        out[name]=vals
    return out

def f64(x):
    s=format(float(x),".17g")
    if "." not in s and "e" not in s.lower(): s+=".0"
    return s+"_real64"

def arr(vals): return "["+",".join(f64(v) for v in vals)+"]"

def prepare_profile(root:Path, artifact_dir:Path, work:Path, pid:int, fixture:Path, geometry:Path):
    tools=root/"tools"
    if str(tools) not in sys.path: sys.path.insert(0,str(tools))
    e24=load("elastic55_e24",tools/"fpe_elastic24_profile_retrieval.py")
    e33=load("elastic55_e33",tools/"fpe_elastic33_profile_row_interchange.py")
    p46=load("elastic55_p46",root/"tests/fpe/prepare_fpe_elastic46.py")
    gpkg=gpkg_one(artifact_dir)
    profile=e24.retrieve_profile(gpkg,pid)
    z,dz,counts=p46.split_profile(profile["horizons"],16)
    nd=[abs(z[1]-z[0])]+[abs(z[i]-z[i-1]) for i in range(1,len(z))]
    geometry.write_text(json.dumps({"z_cm":z,"dz_cm":dz,"node_distance_cm":nd},
                                  sort_keys=True,separators=(",",":"))+"\n",encoding="utf-8")

    work.mkdir(parents=True,exist_ok=True)
    target_json=work/f"profile_{pid}.json"
    target_json.write_text(json.dumps(profile,sort_keys=True,indent=2)+"\n",encoding="utf-8")
    row=work/f"profile_{pid}.rows"
    row.write_text(e33.materialize_interchange(profile),encoding="utf-8")
    cfg=work/f"profile_{pid}.cfg"
    cfg.write_text("ELASTIC_STORAGE_SOURCE=GENERATED_BOFEK_BRO_PRIOR\n",encoding="utf-8")

    # Build the already-qualified ELASTIC53 fixture, then alter only profile-owned
    # input materialization.
    base_work=work/"base"
    base_work.mkdir(exist_ok=True)
    cp=subprocess.run([
        "python3",str(root/"tests/fpe/prepare_fpe_elastic53.py"),
        "--repo-root",str(root),"--artifact-dir",str(artifact_dir),
        "--work-dir",str(base_work),"--fixture",str(fixture),
        "--geometry-json",str(work/"base_geometry.json")
    ],text=True,capture_output=True)
    if cp.returncode!=0: raise SystemExit(cp.stdout+"\n"+cp.stderr)
    s=fixture.read_text(encoding="utf-8")

    # Profile geometry.
    lines=s.splitlines()
    repl=f"  call init_base(p_off,{arr(z)},{arr(dz)})"
    found=False
    for i,line in enumerate(lines):
        if line.strip().startswith("call init_base(p_off,"):
            lines[i]=repl; found=True; break
    if not found: raise SystemExit("F_PE_ELASTIC55_FAIL init_base anchor")
    s="\n".join(lines)+"\n"
    s=s.replace(str((base_work/"request.cfg").resolve()),str(cfg.resolve()))
    s=s.replace(str((base_work/"generated.rows").resolve()),str(row.resolve()))

    # Retention materialization by node from admitted ELASTIC20 values.
    cat=parse_catalog(root)
    nodevals={k:[] for k in cat}
    for h,count in zip(profile["horizons"],counts):
        b=int(h["staringseriesblock"])
        idx=(b-101) if 101<=b<=118 else 18+(b-201)
        for k in cat: nodevals[k].extend([cat[k][idx]]*count)
    if any(len(v)!=16 for v in nodevals.values()): raise SystemExit("F_PE_ELASTIC55_FAIL node material count")

    anchor="  integer(int64), parameter :: PARAM_ID=500050_int64\n"
    insert=(
      f"  real(real64), parameter :: EL55_WCR(N)={arr(nodevals['WCR'])}\n"
      f"  real(real64), parameter :: EL55_WCS(N)={arr(nodevals['WCS'])}\n"
      f"  real(real64), parameter :: EL55_ALPHA(N)={arr(nodevals['ALPHA'])}\n"
      f"  real(real64), parameter :: EL55_NPAR(N)={arr(nodevals['NPAR'])}\n"
    )
    if anchor not in s: raise SystemExit("F_PE_ELASTIC55_FAIL PARAM_ID anchor")
    s=s.replace(anchor,anchor+insert,1)
    old=(
"      q%cofgen(1,k)=0.032_real64;q%cofgen(2,k)=0.423_real64;q%cofgen(3,k)=4.75_real64\n"
"      q%cofgen(4,k)=0.0135_real64;q%cofgen(5,k)=0.365_real64;q%cofgen(6,k)=1.455_real64\n"
"      q%cofgen(7,k)=1.0_real64-1.0_real64/q%cofgen(6,k);q%cofgen(8,k)=q%cofgen(4,k)\n")
    new=(
"      q%cofgen(1,k)=EL55_WCR(k);q%cofgen(2,k)=EL55_WCS(k);q%cofgen(3,k)=4.75_real64\n"
"      q%cofgen(4,k)=EL55_ALPHA(k);q%cofgen(5,k)=0.365_real64;q%cofgen(6,k)=EL55_NPAR(k)\n"
"      q%cofgen(7,k)=1.0_real64-1.0_real64/q%cofgen(6,k);q%cofgen(8,k)=q%cofgen(4,k)\n")
    if old not in s: raise SystemExit("F_PE_ELASTIC55_FAIL retention anchor")
    s=s.replace(old,new,1)
    s=s.replace("'ELASTIC53_BANK|regime='",f"'ELASTIC55_BANK|profile={pid}|regime='",1)
    s=s.replace("'F_PE_ELASTIC53_EXEC=PASS'","'F_PE_ELASTIC55_EXEC=PASS'",1)

    # Emit generated Ss span for every invocation; deterministic metadata.
    marker="  select case(trim(regime))\n"
    meta=(f"  write(*,'(*(g0))')'ELASTIC55_META|profile={pid}|soilunit={profile['soilunit']}|horizons={len(profile['horizons'])}"
          "|ss_min=',minval(p_generated%cofgen(24,:)),'|ss_max=',maxval(p_generated%cofgen(24,:))\n\n")
    if marker not in s: raise SystemExit("F_PE_ELASTIC55_FAIL select marker")
    s=s.replace(marker,meta+marker,1)
    fixture.write_text(s,encoding="utf-8")
    return {"profile_id":pid,"soilunit":profile["soilunit"],"horizon_count":len(profile["horizons"]),
            "blocks":[int(h["staringseriesblock"]) for h in profile["horizons"]],"counts":counts}

def main():
    ap=argparse.ArgumentParser()
    sub=ap.add_subparsers(dest="cmd",required=True)
    sp=sub.add_parser("select"); sp.add_argument("--artifact-dir",required=True); sp.add_argument("--output",required=True)
    pp=sub.add_parser("profile")
    pp.add_argument("--repo-root",required=True); pp.add_argument("--artifact-dir",required=True); pp.add_argument("--work-dir",required=True)
    pp.add_argument("--profile-id",required=True,type=int); pp.add_argument("--fixture",required=True); pp.add_argument("--geometry-json",required=True)
    a=ap.parse_args()
    if a.cmd=="select":
        selected=select_profiles(gpkg_one(a.artifact_dir))
        Path(a.output).write_text(json.dumps(selected,indent=2,sort_keys=True)+"\n",encoding="utf-8")
        print("ELASTIC55_SELECTED="+json.dumps(selected,sort_keys=True,separators=(",",":")))
        print("F_PE_ELASTIC55_SELECT=PASS")
    else:
        info=prepare_profile(Path(a.repo_root).resolve(),Path(a.artifact_dir).resolve(),Path(a.work_dir).resolve(),
                             a.profile_id,Path(a.fixture).resolve(),Path(a.geometry_json).resolve())
        print("ELASTIC55_PROFILE_PREP="+json.dumps(info,sort_keys=True,separators=(",",":")))
        print("F_PE_ELASTIC55_PROFILE_PREP=PASS")

if __name__=="__main__":
    main()
