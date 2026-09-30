#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, re, sys
from pathlib import Path

PROFILE_ID=90210030
NODES=16

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    if spec is None or spec.loader is None: raise SystemExit(f"F_PE_PZG23_04_FAIL load {path}")
    mod=importlib.util.module_from_spec(spec); sys.modules[spec.name]=mod; spec.loader.exec_module(mod); return mod

def parse_catalog(root):
    text=(root/"src/adapter/mod_fmr_elastic_storage_staringreeks_catalog.f90").read_text(encoding="utf-8")
    out={}
    for name in ("WCR","WCS","ALPHA","NPAR"):
        m=re.search(name+r"\(FMR_STARINGREEKS_CATALOG_COUNT\)\s*=\s*\[\s*&(?P<body>.*?)\]",text,re.S)
        if not m: raise SystemExit(f"F_PE_PZG23_04_FAIL catalog {name}")
        vals=[float(x) for x in re.findall(r"([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[Ee][+-]?\d+)?)_real64",m.group("body"))]
        if len(vals)!=36: raise SystemExit(f"F_PE_PZG23_04_FAIL catalog count {name}")
        out[name]=vals
    return out

def split_profile(horizons,n_nodes):
    if len(horizons)>n_nodes: raise SystemExit("F_PE_PZG23_04_FAIL too many horizons")
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

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--repo-root",required=True); ap.add_argument("--artifact-dir",required=True); ap.add_argument("--out",required=True)
    a=ap.parse_args(); root=Path(a.repo_root).resolve(); out=Path(a.out).resolve(); out.mkdir(parents=True,exist_ok=True)
    tools=root/"tools"; sys.path.insert(0,str(tools))
    e24=load("pzg23_04_e24",tools/"fpe_elastic24_profile_retrieval.py")
    e33=load("pzg23_04_e33",tools/"fpe_elastic33_profile_row_interchange.py")
    hits=list(Path(a.artifact_dir).rglob("*.gpkg"))
    if len(hits)!=1: raise SystemExit(f"F_PE_PZG23_04_FAIL gpkg hits={len(hits)}")
    profile=e24.retrieve_profile(hits[0].resolve(),PROFILE_ID)
    (out/"profile.rows").write_text(e33.materialize_interchange(profile),encoding="utf-8")
    (out/"request.cfg").write_text("ELASTIC_STORAGE_SOURCE=GENERATED_BOFEK_BRO_PRIOR\n",encoding="utf-8")
    z,dz,nd,counts=split_profile(profile["horizons"],NODES)
    (out/"geometry.json").write_text(json.dumps({"z_cm":z,"dz_cm":dz,"node_distance_cm":nd},separators=(",",":"))+"\n",encoding="utf-8")
    cat=parse_catalog(root); node={k:[] for k in cat}
    for h,c in zip(profile["horizons"],counts):
        b=int(h["staringseriesblock"]); idx=(b-101) if 101<=b<=118 else 18+(b-201)
        for k in cat: node[k].extend([cat[k][idx]]*c)
    with (out/"retention.txt").open("w",encoding="utf-8") as fh:
        for i in range(NODES):
            fh.write("%.17g %.17g %.17g %.17g\n"%(node["WCR"][i],node["WCS"][i],node["ALPHA"][i],node["NPAR"][i]))
    print(f"PZG23_04_PROFILE={PROFILE_ID}|soilunit={profile['soilunit']}|horizons={len(profile['horizons'])}")
    print("F_PE_PZG23_04_PREP=PASS")
if __name__=="__main__": main()
