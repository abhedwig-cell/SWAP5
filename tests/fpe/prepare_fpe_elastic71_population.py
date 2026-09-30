#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, math, re, sqlite3, sys
from pathlib import Path

NODES=16
TOTAL=1024

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    if spec is None or spec.loader is None: raise SystemExit(f"F_PE_ELASTIC71_FAIL load {path}")
    mod=importlib.util.module_from_spec(spec); sys.modules[spec.name]=mod; spec.loader.exec_module(mod); return mod

def gpkg_one(root):
    hits=list(Path(root).rglob("*.gpkg"))
    if len(hits)!=1: raise SystemExit(f"F_PE_ELASTIC71_FAIL gpkg hits={len(hits)}")
    return hits[0].resolve()

def eligible(con,pid):
    rows=list(con.execute(
        "select layernumber,lowervalue,uppervalue,staringseriesblock,organicmattercontent,peattype,density "
        "from soilhorizon where normalsoilprofile_id=? order by layernumber",(pid,)))
    if not rows or len(rows)>16: return False
    prev=None
    for i,(layer,low,up,block,om,peat,density) in enumerate(rows,1):
        if int(layer)!=i: return False
        low=float(low); up=float(up)
        if up<=low or (i==1 and abs(low)>1e-10) or (prev is not None and abs(low-prev)>1e-10): return False
        prev=up
        b=int(block)
        if not (101<=b<=118 or 201<=b<=218): return False
        if peat is not None: return False
        if density is None or not math.isfinite(float(density)) or float(density)<=0: return False
        if om is not None and (not math.isfinite(float(om)) or float(om)>20.0): return False
    return True

def select(gpkg):
    con=sqlite3.connect(f"file:{gpkg}?mode=ro",uri=True)
    try:
        counts={int(pid):int(n) for pid,n in con.execute(
            "select normalsoilprofile_id,count(*) from soilarea_normalsoilprofile "
            "where normalsoilprofile_id is not null group by normalsoilprofile_id")}
        rows=[]
        for pid,n in counts.items():
            if pid>0 and eligible(con,pid): rows.append((pid,n))
    finally: con.close()
    rows.sort(key=lambda x:(-x[1],x[0]))
    if len(rows)<4: raise SystemExit("F_PE_ELASTIC71_FAIL eligible profiles")
    return rows[:4]

def allocate(selected,total):
    s=sum(n for _,n in selected)
    raw=[total*n/s for _,n in selected]
    base=[int(math.floor(x)) for x in raw]
    rem=total-sum(base)
    order=sorted(range(len(selected)),key=lambda i:(-(raw[i]-base[i]),selected[i][0]))
    for i in order[:rem]: base[i]+=1
    return base

def split_profile(horizons,n_nodes):
    counts=[1]*len(horizons); remaining=n_nodes-len(horizons)
    thickness=[float(h["bottom_depth_m"])-float(h["top_depth_m"]) for h in horizons]
    while remaining:
        scores=[thickness[i]/counts[i] for i in range(len(horizons))]
        k=max(range(len(scores)),key=lambda i:(scores[i],-i)); counts[k]+=1; remaining-=1
    z=[]; dz=[]
    for h,count in zip(horizons,counts):
        top=float(h["top_depth_m"]); bottom=float(h["bottom_depth_m"]); step=(bottom-top)/count
        for j in range(count):
            a=top+j*step; b=top+(j+1)*step
            z.append(-0.5*(a+b)*100.0); dz.append((b-a)*100.0)
    nd=[abs(z[1]-z[0])]+[abs(z[i]-z[i-1]) for i in range(1,len(z))]
    return z,dz,nd,counts

def parse_catalog(root):
    text=(root/"src/adapter/mod_fmr_elastic_storage_staringreeks_catalog.f90").read_text()
    out={}
    for name in ("WCR","WCS","ALPHA","NPAR"):
        m=re.search(name+r"\(FMR_STARINGREEKS_CATALOG_COUNT\)\s*=\s*\[\s*&(?P<body>.*?)\]",text,re.S)
        if not m: raise SystemExit(f"F_PE_ELASTIC71_FAIL catalog {name}")
        vals=[float(x) for x in re.findall(r"([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[Ee][+-]?\d+)?)_real64",m.group("body"))]
        if len(vals)!=36: raise SystemExit(f"F_PE_ELASTIC71_FAIL catalog count {name}")
        out[name]=vals
    return out

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--repo-root",required=True); ap.add_argument("--artifact-dir",required=True); ap.add_argument("--out",required=True)
    a=ap.parse_args(); root=Path(a.repo_root).resolve(); out=Path(a.out).resolve(); out.mkdir(parents=True,exist_ok=True)
    tools=root/"tools"; sys.path.insert(0,str(tools))
    e24=load("e71_e24",tools/"fpe_elastic24_profile_retrieval.py")
    e33=load("e71_e33",tools/"fpe_elastic33_profile_row_interchange.py")
    gpkg=gpkg_one(a.artifact_dir)
    selected=select(gpkg); alloc=allocate(selected,TOTAL); cat=parse_catalog(root)
    manifest=[]
    for (pid,mapareas),ncols in zip(selected,alloc):
        pdir=out/f"p{pid}"; pdir.mkdir()
        profile=e24.retrieve_profile(gpkg,pid)
        (pdir/"profile.rows").write_text(e33.materialize_interchange(profile))
        (pdir/"request.cfg").write_text("ELASTIC_STORAGE_SOURCE=GENERATED_BOFEK_BRO_PRIOR\n")
        z,dz,nd,counts=split_profile(profile["horizons"],NODES)
        (pdir/"geometry.json").write_text(json.dumps({"z_cm":z,"dz_cm":dz,"node_distance_cm":nd},separators=(",",":"))+"\n")
        node={k:[] for k in cat}
        for h,c in zip(profile["horizons"],counts):
            b=int(h["staringseriesblock"]); idx=(b-101) if 101<=b<=118 else 18+(b-201)
            for k in cat: node[k].extend([cat[k][idx]]*c)
        with (pdir/"retention.txt").open("w") as fh:
            for i in range(NODES):
                fh.write("%.17g %.17g %.17g %.17g\n"%(node["WCR"][i],node["WCS"][i],node["ALPHA"][i],node["NPAR"][i]))
        manifest.append({"profile_id":pid,"maparea_count":mapareas,"columns":ncols,"soilunit":profile["soilunit"]})
    (out/"manifest.json").write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n")
    print("ELASTIC71_SELECTION="+json.dumps(manifest,separators=(",",":"),sort_keys=True))
    print("F_PE_ELASTIC71_PREP=PASS")
if __name__=="__main__": main()
