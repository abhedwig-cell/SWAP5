#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, sqlite3
from pathlib import Path

EXCLUDE_IDS={90116260,11060,10260,8016,3030}
EXCLUDE_SOILUNITS={"Zn30A","Zd30","EZg21","gY30"}

def gpkg_one(d):
    hits=list(Path(d).rglob("*.gpkg"))
    if len(hits)!=1:
        raise SystemExit(f"F_PE_ELASTIC59_FAIL gpkg hits={len(hits)}")
    return hits[0].resolve()

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--artifact-dir",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    gpkg=gpkg_one(a.artifact_dir)
    con=sqlite3.connect(f"file:{gpkg}?mode=ro",uri=True)
    try:
        pids=[int(r[0]) for r in con.execute("select normalsoilprofile_id from normalsoilprofiles order by normalsoilprofile_id")]
        eligible=[]
        for pid in pids:
            if pid<=0 or pid in EXCLUDE_IDS:
                continue
            prow=con.execute("select soilunit from normalsoilprofiles where normalsoilprofile_id=?",(pid,)).fetchone()
            soilunit=None if prow is None else prow[0]
            if soilunit in EXCLUDE_SOILUNITS:
                continue
            rows=list(con.execute(
                "select layernumber,lowervalue,uppervalue,staringseriesblock,organicmattercontent,peattype,density "
                "from soilhorizon where normalsoilprofile_id=? order by layernumber",(pid,)))
            if not rows or len(rows)>16:
                continue
            ok=True; prev=None; blocks=[]
            for idx,(layer,low,up,block,om,peat,density) in enumerate(rows,1):
                try:
                    layer=int(layer); low=float(low); up=float(up); ib=int(block); dens=float(density)
                except Exception:
                    ok=False; break
                if layer!=idx or up<=low:
                    ok=False; break
                if idx==1 and abs(low)>1e-10:
                    ok=False; break
                if prev is not None and abs(low-prev)>1e-10:
                    ok=False; break
                prev=up
                if not (101<=ib<=118 or 201<=ib<=218):
                    ok=False; break
                if peat is not None:
                    ok=False; break
                if dens<=0:
                    ok=False; break
                if om is not None:
                    try: omv=float(om)
                    except Exception:
                        ok=False; break
                    if omv>20.0:
                        ok=False; break
                blocks.append(ib)
            if ok:
                eligible.append({
                    "profile_id":pid,
                    "soilunit":soilunit,
                    "horizon_count":len(rows),
                    "blocks":blocks,
                })
    finally:
        con.close()

    uniq=[]; seen=set()
    for p in eligible:
        key=(p["soilunit"],p["horizon_count"],tuple(p["blocks"]))
        if key in seen:
            continue
        seen.add(key); uniq.append(p)

    classes=sorted({p["horizon_count"] for p in uniq})
    if len(classes)<4:
        raise SystemExit(f"F_PE_ELASTIC59_FAIL horizon classes={classes}")

    selected=[]
    for hc in classes[:4]:
        cand=[p for p in uniq if p["horizon_count"]==hc]
        selected.append(min(cand,key=lambda p:p["profile_id"]))

    ids=[p["profile_id"] for p in selected]
    soils=[p["soilunit"] for p in selected]
    if any(pid in EXCLUDE_IDS for pid in ids) or any(s in EXCLUDE_SOILUNITS for s in soils):
        raise SystemExit("F_PE_ELASTIC59_FAIL prior overlap")
    if len(set(ids))!=4 or len(set((p["soilunit"],p["horizon_count"],tuple(p["blocks"])) for p in selected))!=4:
        raise SystemExit("F_PE_ELASTIC59_FAIL selection diversity")

    Path(a.output).write_text(json.dumps(selected,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print("ELASTIC59_SELECTED="+json.dumps(selected,sort_keys=True,separators=(",",":")))
    print("F_PE_ELASTIC59_SELECT=PASS")

if __name__=="__main__":
    main()
