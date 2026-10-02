#!/usr/bin/env python3
import csv,json,statistics,sys
from pathlib import Path
src=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True)
counts={}
times={}
for line in src.read_text().splitlines():
    p=line.strip().split(",")
    if not p: continue
    if p[0]=="COUNT":
        counts[p[1]]={"evaluate":int(p[2]),"demand":int(p[3]),"point":int(p[4])}
    elif p[0]=="TIME":
        times.setdefault(p[1],[]).append(float(p[4]))
summary={"counts":counts,"timing":{}}
for name,x in times.items():
    summary["timing"][name]={"median_s":statistics.median(x),"min_s":min(x),"max_s":max(x),"batches":len(x),"nrep":2000}
if counts.get("NODE_SORPTIVITY",{}).get("demand") != 65:
    raise SystemExit("PROFILE01 gate: 64-panel node sorptivity demand count is not 65")
summary["zero_waste_candidates"]={
  "unused_mb_wall_hydraulics":{
    "source_semantics":"A26 leading MB is fast-through; production candidate composer does not consume wall-binding MB K/S",
    "cached_wall_demand_calls":counts.get("WALL_CACHED",{}).get("demand"),
    "single_sorptivity_demand_calls":counts.get("NODE_SORPTIVITY",{}).get("demand")
  },
  "zero_supply_surface_hydraulics":{
    "source_semantics":"zero-source activation returns AVAILABLE without using hydraulic threshold values, while binding currently evaluates K/S first",
    "full_dry_cached_demand_calls":counts.get("FULL_DRY_CACHED",{}).get("demand")
  }
}
for num,den,label in [
 ("NODE_SORPTIVITY","FULL_WET_CACHED","node_sorptivity_over_full_wet_cached"),
 ("WALL_CACHED","FULL_WET_CACHED","wall_cached_over_full_wet_cached"),
 ("SURFACE_WET","FULL_WET_CACHED","surface_wet_over_full_wet_cached")
]:
    if num in summary["timing"] and den in summary["timing"] and summary["timing"][den]["median_s"]>0:
        summary[label]=summary["timing"][num]["median_s"]/summary["timing"][den]["median_s"]
(out/"profile01_summary.json").write_text(json.dumps(summary,indent=2)+"\n")
with (out/"profile01_timing.csv").open("w",newline="") as f:
    w=csv.writer(f);w.writerow(["component","median_s","min_s","max_s","nrep"])
    for name,v in summary["timing"].items():w.writerow([name,v["median_s"],v["min_s"],v["max_s"],v["nrep"]])
print(json.dumps(summary,indent=2))
