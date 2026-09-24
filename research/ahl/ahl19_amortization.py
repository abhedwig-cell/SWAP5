#!/usr/bin/env python3
"""F-AHL19 amortization analysis from frozen measured evidence.

All constants below are copied from persisted F-AHL16/F-AHL17/F-AHL18
repository evidence. Conservative solve savings use the smallest absolute
paired saving observed per material across wet/mid/dry regimes.
"""
from __future__ import annotations
import json, math

BUILD_S = {
    "B01": 1.10817e-3,
    "B12": 7.11970e-4,
    "O05": 1.11333e-3,
    "O14": 9.76280e-4,
}
CACHE_ACQUIRE_S = 5.006e-7

# Conservative absolute complete-Richards CPU saving per solve, derived from
# the minimum of the wet/mid/dry paired median absolute savings in F-AHL16.
SOLVE_SAVE_S = {
    "B01": 1.2136230469e-6,
    "B12": 1.2667846679e-6,
    "O05": 1.2270507813e-6,
    "O14": 1.1199951172e-6,
}

COLUMN_COUNTS=[1,10,100,1000,10000]
SOLVES_PER_COLUMN=[1,10,100,365,1000,3650]
MATERIALS=["B01","B12","O05","O14"]

def scenario(ncol, mats):
    if ncol < len(mats):
        return None
    # Even the first request pays an acquisition call; this is deliberately
    # conservative because its lookup overhead is partly subsumed by build.
    startup=sum(BUILD_S[m] for m in mats) + ncol*CACHE_ACQUIRE_S
    # Equal column allocation across the selected unique material set.
    mean_save=sum(SOLVE_SAVE_S[m] for m in mats)/len(mats)
    breakeven_total=math.ceil(startup/mean_save)
    breakeven_per_col=math.ceil(breakeven_total/ncol)
    rows=[]
    for ns in SOLVES_PER_COLUMN:
        benefit=ncol*ns*mean_save
        rows.append({
            "solves_per_column":ns,
            "startup_seconds":startup,
            "solve_saving_seconds":benefit,
            "net_seconds":benefit-startup,
            "amortized":benefit>=startup,
        })
    return {
        "columns":ncol,
        "unique_materials":len(mats),
        "materials":mats,
        "startup_seconds":startup,
        "conservative_mean_saving_per_solve_seconds":mean_save,
        "break_even_total_solves":breakeven_total,
        "break_even_solves_per_column":breakeven_per_col,
        "trajectory_examples":rows,
    }

out={
  "work_unit":"F-AHL19",
  "evidence_policy":"conservative minimum per-material solve saving; measured build and cache acquisition costs included",
  "inputs":{
    "build_seconds":BUILD_S,
    "cache_acquisition_seconds_per_column":CACHE_ACQUIRE_S,
    "conservative_solve_saving_seconds":SOLVE_SAVE_S,
  },
  "scenarios":[]
}
for n in COLUMN_COUNTS:
    out["scenarios"].append(scenario(n,["B01"]))
    s=scenario(n,MATERIALS)
    if s is not None:
        out["scenarios"].append(s)

print(json.dumps(out,indent=2,sort_keys=True))
