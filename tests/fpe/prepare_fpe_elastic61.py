#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,sqlite3
from pathlib import Path

EXCLUDE={90116260,11060,10260,8016,3030,11020,8120,4015,3011}

def gpkg_one(d):
    hits=list(Path(d).rglob("*.gpkg"))
    if len(hits)!=1: raise SystemExit(f"F_PE_ELASTIC61_FAIL gpkg hits={len(hits)}")
    return hits[0].resolve()

def select(gpkg):
    con=sqlite3.connect(f"file:{gpkg}?mode=ro",uri=True)
    try:
        pids=[int(r[0]) for r in con.execute("select normalsoilprofile_id from normalsoilprofiles order by normalsoilprofile_id")]
        eligible=[]
        for pid in pids:
            if pid<=0 or pid in EXCLUDE: continue
            soil=con.execute("select soilunit from normalsoilprofiles where normalsoilprofile_id=?",(pid,)).fetchone()
            rows=list(con.execute(
                "select layernumber,lowervalue,uppervalue,staringseriesblock,organicmattercontent,peattype,density "
                "from soilhorizon where normalsoilprofile_id=? order by layernumber",(pid,)))
            if not rows or len(rows)>16: continue
            prev=None; blocks=[]; ok=True
            for i,(layer,low,up,block,om,peat,density) in enumerate(rows,1):
                if int(layer)!=i: ok=False; break
                low=float(low); up=float(up)
                if up<=low or (i==1 and abs(low)>1e-10) or (prev is not None and abs(low-prev)>1e-10): ok=False; break
                prev=up
                ib=int(block)
                if not (101<=ib<=118 or 201<=ib<=218): ok=False; break
                if peat is not None: ok=False; break
                if density is None or float(density)<=0: ok=False; break
                if om is not None and float(om)>20: ok=False; break
                blocks.append(ib)
            if ok:
                eligible.append({"profile_id":pid,"soilunit":None if soil is None else soil[0],
                                 "horizon_count":len(rows),"blocks":blocks})
    finally:
        con.close()
    uniq=[]; seen=set()
    for p in eligible:
        k=(p["soilunit"],p["horizon_count"],tuple(p["blocks"]))
        if k in seen: continue
        seen.add(k); uniq.append(p)
    classes=sorted({p["horizon_count"] for p in uniq})[:4]
    if len(classes)!=4: raise SystemExit(f"F_PE_ELASTIC61_FAIL classes={classes}")
    out=[]
    for hc in classes:
        cand=sorted([p for p in uniq if p["horizon_count"]==hc],key=lambda x:x["profile_id"])
        if not cand: raise SystemExit(f"F_PE_ELASTIC61_FAIL empty class {hc}")
        out.append(cand[0])
    return out

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--artifact-dir",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    out=select(gpkg_one(a.artifact_dir))
    Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print("ELASTIC61_SELECTED="+json.dumps(out,sort_keys=True,separators=(",",":")))
    print("F_PE_ELASTIC61_SELECT=PASS")
if __name__=="__main__": main()
