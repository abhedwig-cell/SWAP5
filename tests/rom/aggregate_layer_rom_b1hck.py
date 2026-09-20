#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib


def find_result(root:pathlib.Path,material:str)->pathlib.Path:
    matches=list(root.rglob(f"LAYER_ROM_B1HCK_{material}_RESULT.json"))
    if len(matches)!=1:
        raise SystemExit(f"{material}: expected one result, found {len(matches)}")
    return matches[0]


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    if pre["phase"]!="PREREGISTERED_BEFORE_NEW_REFERENCE_TEMPORAL_RESPONSE":
        raise SystemExit("wrong B1HCK preregistration")
    materials=list(pre["scope"]["materials"])
    rows={}
    for m in materials:
        row=json.loads(find_result(a.input_dir,m).read_text())
        if row["material"]!=m or row["work_unit"]!="LAYER-ROM-B1HCK":
            raise SystemExit(f"{m}: identity drift")
        if not row["integrity"]["pass"]:
            raise SystemExit(f"{m}: integrity failed")
        rows[m]=row

    bounded=pre["material_gate"]["label_bounded"]
    not_bounded=pre["material_gate"]["label_not_bounded"]
    unresolved=pre["material_gate"]["label_unresolved"]
    allowed={bounded,not_bounded,unresolved}
    if any(r["decision"] not in allowed for r in rows.values()):
        raise SystemExit("unexpected material decision")

    decisions={m:r["decision"] for m,r in rows.items()}
    all_bounded=all(x==bounded for x in decisions.values())
    any_unresolved=any(x==unresolved for x in decisions.values())
    panel=pre["panel_decisions"]["all_bounded"] if all_bounded else pre["panel_decisions"]["mixed"]

    component_counts={}
    max_ratio={}
    candidate_trend={}
    for comp in ("storage_rms","cumulative_bottom_rms","qavg_rms","qend_rms","mapped_theta_rms"):
        cc={"SATURATED":0,"CONVERGING":0,"NONCONVERGENT":0,"TEMPORAL_BOUNDED":0}
        maxr=0.0
        trend={"residual_decreases":0,"residual_increases":0,"residual_equal":0}
        for m,r in rows.items():
            c=r["components"][comp]
            cc[c["reference_self_classification"]]+=1
            cc["TEMPORAL_BOUNDED"]+=int(c["finest_temporal_bounded"])
            maxr=max(maxr,float(c["mid_fine_over_candidate_fine"]))
            d=float(c["candidate_residual_coarse_to_fine_change"])
            if d<0: trend["residual_decreases"]+=1
            elif d>0: trend["residual_increases"]+=1
            else: trend["residual_equal"]+=1
        component_counts[comp]=cc
        max_ratio[comp]=maxr
        candidate_trend[comp]=trend

    result={
        "schema":"swap5.layer-rom.phase-b1hck.adjudication.v1",
        "workstream":"F-ROM-LAYER",
        "work_unit":"LAYER-ROM-B1HCK",
        "decision":panel,
        "material_decisions":decisions,
        "bounded_materials":[m for m,d in decisions.items() if d==bounded],
        "not_yet_bounded_materials":[m for m,d in decisions.items() if d==not_bounded],
        "nonconvergent_materials":[m for m,d in decisions.items() if d==unresolved],
        "component_classification_counts":component_counts,
        "maximum_mid_fine_over_candidate_fine_ratio":max_ratio,
        "candidate_residual_refinement_direction_counts":candidate_trend,
        "material_components":{
            m:{comp:r["components"][comp] for comp in r["components"]}
            for m,r in rows.items()
        },
        "integrity":{
            "pass":True,
            "all_materials_present":len(rows)==len(materials),
            "any_reference_temporal_nonconvergence":any_unresolved,
            "hydrological_model_changed":False,
        },
        "interpretation":(
            [
                "All six materials satisfy the frozen Reference temporal bound at dt=2.5e-4 d on every primary component.",
                "The remaining equal-grid DOP853 Layer-ROM versus refined Richards residual is therefore not explained by unresolved Reference temporal discretization at the preregistered resolution scale.",
                "The next causal question is the equal-grid closure/operator difference, followed by re-evaluation of reduced L4/L6/R8 transfer metrics only where the refined-Reference shift is non-negligible.",
            ]
            if all_bounded else
            [
                "The finite Reference temporal axis is not uniformly bounded across the frozen six-material panel.",
                "Do not attribute the remaining equal-grid discrepancy to Layer-ROM closure alone on unbounded materials.",
                "Further work must stay on the Reference temporal axis for the affected material/components before hydrological redesign or reduced-ladder re-adjudication."
            ]
        ),
        "application_acceptance_adjudicated":False,
        "performance_measurement_performed":False,
        "production_rom_authorized":False,
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":panel,
        "material_decisions":decisions,
        "component_classification_counts":component_counts,
        "maximum_mid_fine_over_candidate_fine_ratio":max_ratio,
    },sort_keys=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
