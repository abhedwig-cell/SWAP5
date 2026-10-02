#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib

EXPECTED=("B02","B05","B06","B11","B12","B16")
METRICS=("storage_rmse_cm","cumulative_bottom_rmse_cm","bottom_flux_rmse_cm_per_day",
         "bottom_flux_sign_errors","mapped_theta_rmse")

def no_worse(a,b,tol=1e-12):
    out={}
    for k in METRICS:
        if k=="bottom_flux_sign_errors":
            out[k]=int(a[k])<=int(b[k])
        else:
            out[k]=float(a[k])<=float(b[k])+tol
    return out

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    p=json.loads(a.prereg.read_text())
    if tuple(p["material_roles"]["new_response_materials"])!=EXPECTED:
        raise SystemExit("B1H expected material set drift")

    results={}
    for path in sorted(a.input_dir.rglob("LAYER_ROM_B1H_*_RESULT.json")):
        row=json.loads(path.read_text())
        mid=row["material"]
        if mid in results:
            raise SystemExit(f"duplicate material result {mid}")
        results[mid]=row
    if set(results)!=set(EXPECTED):
        raise SystemExit(f"material result set mismatch: {sorted(results)}")

    placement4={}
    placement8={}
    monotonic={}
    day1={}
    for mid in EXPECTED:
        r=results[mid]
        if r["decision"]!="B1H_MATERIAL_TRANSFER_CHARACTERIZED" or not r["integrity"]["pass"]:
            raise SystemExit(f"blocked material {mid}: {r['decision']}")
        placement4[mid]=bool(r["placement"]["dimension4"].get("day1",{}).get("supported",False))
        placement8[mid]=bool(r["placement"]["dimension8"].get("day1",{}).get("supported",False))
        s=r["summaries"]
        day1[mid]={rid:s[rid]["1024"] if rid in s else None for rid in ("L4","L6","R8","U4","U8","R16_OP")}
        if all(rid in s for rid in ("L4","L6","R8")):
            l4,l6,r8=(s[x]["1024"] for x in ("L4","L6","R8"))
            c46=no_worse(l6,l4)
            c68=no_worse(r8,l6)
            monotonic[mid]={
              "L6_noninferior_to_L4":c46,
              "R8_noninferior_to_L6":c68,
              "all_primary_noninferior_L4_to_L6_to_R8":all(c46.values()) and all(c68.values())
            }
        else:
            monotonic[mid]={"all_primary_noninferior_L4_to_L6_to_R8":False,"reason":"targeted_member_unqualified"}

    out={
      "schema":"swap5.layer-rom.phase-b1h.aggregate-result.v1",
      "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1H",
      "decision":"B1H_TRANSFER_PANEL_CHARACTERIZED",
      "new_materials":list(EXPECTED),
      "all_material_integrity_pass":True,
      "placement_support":{
        "dimension4_by_material":placement4,
        "dimension8_by_material":placement8,
        "dimension4_support_count":sum(placement4.values()),
        "dimension8_support_count":sum(placement8.values()),
        "material_count":len(EXPECTED)
      },
      "targeted_ladder_monotonicity":monotonic,
      "day1_component_vectors":day1,
      "scientific_interpretation_rules":[
        "A support count is descriptive transfer evidence, not an application acceptance rate.",
        "Failure of monotone L4-L6-R8 error reduction on a material is evidence against a universal dimension-order rule, not permission to retune that material's partition.",
        "B01 and B14 remain inherited anchors and are not pooled into the six-material prospective transfer count.",
        "Same-partition CoRichards decomposition remains a separate successor gate."
      ],
      "application_acceptance_adjudicated":False,
      "performance_measurement_performed":False,
      "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "decision":out["decision"],
      "placement_support":out["placement_support"],
      "targeted_ladder_monotonicity":monotonic
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
