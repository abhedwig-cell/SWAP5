#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, sys
from pathlib import Path

PROFILE_ID=8016
NODES=16

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"F_PE_ELASTIC70_FAIL load {path}")
    mod=importlib.util.module_from_spec(spec)
    sys.modules[spec.name]=mod
    spec.loader.exec_module(mod)
    return mod

def split_profile(horizons,n_nodes):
    if len(horizons)>n_nodes:
        raise SystemExit("F_PE_ELASTIC70_FAIL more horizons than nodes")
    counts=[1]*len(horizons)
    remaining=n_nodes-len(horizons)
    thickness=[float(h["bottom_depth_m"])-float(h["top_depth_m"]) for h in horizons]
    while remaining:
        scores=[thickness[i]/counts[i] for i in range(len(horizons))]
        k=max(range(len(scores)),key=lambda i:(scores[i],-i))
        counts[k]+=1
        remaining-=1
    z=[]; dz=[]
    for h,count in zip(horizons,counts):
        top=float(h["top_depth_m"]); bottom=float(h["bottom_depth_m"])
        step=(bottom-top)/count
        for j in range(count):
            a=top+j*step; b=top+(j+1)*step
            z.append(-0.5*(a+b)*100.0)
            dz.append((b-a)*100.0)
    nd=[abs(z[1]-z[0])]+[abs(z[i]-z[i-1]) for i in range(1,len(z))]
    return z,dz,nd

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--repo-root",required=True)
    ap.add_argument("--artifact-dir",required=True)
    ap.add_argument("--work-dir",required=True)
    a=ap.parse_args()
    root=Path(a.repo_root).resolve()
    work=Path(a.work_dir).resolve(); work.mkdir(parents=True,exist_ok=True)
    tools=root/"tools"
    if str(tools) not in sys.path: sys.path.insert(0,str(tools))
    e24=load("elastic70_e24",tools/"fpe_elastic24_profile_retrieval.py")
    e33=load("elastic70_e33",tools/"fpe_elastic33_profile_row_interchange.py")
    hits=list(Path(a.artifact_dir).rglob("*.gpkg"))
    if len(hits)!=1: raise SystemExit(f"F_PE_ELASTIC70_FAIL gpkg hits={len(hits)}")
    profile=e24.retrieve_profile(hits[0].resolve(),PROFILE_ID)
    rows=work/"profile_8016.rows"
    rows.write_text(e33.materialize_interchange(profile),encoding="utf-8")
    cfg=work/"request.cfg"
    cfg.write_text("ELASTIC_STORAGE_SOURCE=GENERATED_BOFEK_BRO_PRIOR\n",encoding="utf-8")
    z,dz,nd=split_profile(profile["horizons"],NODES)
    geom=work/"geometry.json"
    geom.write_text(json.dumps({"z_cm":z,"dz_cm":dz,"node_distance_cm":nd},
                               sort_keys=True,separators=(",",":"))+"\n",encoding="utf-8")
    print(f"ELASTIC70_PROFILE={PROFILE_ID}|horizons={len(profile['horizons'])}|soilunit={profile['soilunit']}")
    print(f"ELASTIC70_CONFIG={cfg}")
    print(f"ELASTIC70_ROWS={rows}")
    print(f"ELASTIC70_GEOMETRY={geom}")
    print("F_PE_ELASTIC70_PROFILE_PREP=PASS")
if __name__=="__main__": main()
