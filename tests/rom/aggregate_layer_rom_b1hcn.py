#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib
from collections import Counter

MATERIALS=("B02","B05","B06","B11","B12","B16")
MEMBERS=("L4","L6","R8")
GW=("storage_rms_cm","cumulative_bottom_rms_cm","qavg_rms_cm_per_day","qavg_sign_mismatch",
    "qend_rms_cm_per_day","qend_sign_mismatch","max_abs_final_cumulative_bottom_error_cm")

def find(root,m,member):
    xs=list(root.rglob(f"LAYER_ROM_B1HCN_{m}_{member}_RESULT.json"))
    if len(xs)!=1: raise SystemExit(f"{m} {member}: expected one result, got {len(xs)}")
    return xs[0]

def nonworse(high,low,tol=1e-12):
    for k in GW:
        if "sign_mismatch" in k:
            if int(high[k])>int(low[k]): return False
        elif float(high[k])>float(low[k])+tol:
            return False
    return True

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    pre=json.loads(a.prereg.read_text())
    if pre["phase"]!="PREREGISTERED_BEFORE_NEW_CORICHARDS_TEMPORAL_RESPONSE": raise SystemExit("wrong prereg")
    rows={}
    for m in MATERIALS:
        rows[m]={}
        for member in MEMBERS:
            r=json.loads(find(a.input_dir,m,member).read_text())
            if r["material"]!=m or r["member"]!=member or not r["integrity"]["pass"]:
                raise SystemExit(f"{m} {member}: identity/integrity drift")
            rows[m][member]=r

    unresolved=[f"{m}:{member}" for m in MATERIALS for member in MEMBERS if not rows[m][member]["integrity"]["temporal_supported"]]
    decision=pre["decisions"]["temporal_unresolved"] if unresolved else pre["decisions"]["complete"]

    relations={member:dict(Counter(rows[m][member]["groundwater_relation"] for m in MATERIALS)) for member in MEMBERS}
    profile={member:dict(Counter(rows[m][member]["profile_relation"]["lower_error_route"] for m in MATERIALS)) for member in MEMBERS}
    material_relations={m:{member:rows[m][member]["groundwater_relation"] for member in MEMBERS} for m in MATERIALS}

    dimension_order={"LayerROM":{},"CoRichards":{}}
    for route in ("LayerROM","CoRichards"):
        for m in MATERIALS:
            l4=rows[m]["L4"]["continuous_time_fidelity"][route]
            l6=rows[m]["L6"]["continuous_time_fidelity"][route]
            r8=rows[m]["R8"]["continuous_time_fidelity"][route]
            dimension_order[route][m]={
              "L4_to_L6_componentwise_nonworse":nonworse(l6,l4),
              "L6_to_R8_componentwise_nonworse":nonworse(r8,l6),
              "full_ladder_componentwise_nonworse":nonworse(l6,l4) and nonworse(r8,l6)
            }

    key={}
    for m in MATERIALS:
        key[m]={}
        for member in MEMBERS:
            r=rows[m][member]
            key[m][member]={
              "LayerROM":r["continuous_time_fidelity"]["LayerROM"],
              "CoRichards":r["continuous_time_fidelity"]["CoRichards"],
              "groundwater_relation":r["groundwater_relation"],
              "profile_relation":r["profile_relation"]["lower_error_route"],
              "temporal_supported":r["integrity"]["temporal_supported"]
            }

    result={
      "schema":"swap5.layer-rom.phase-b1hcn.adjudication.v1","workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1HCN",
      "decision":decision,"unresolved_cells":unresolved,
      "groundwater_relation_counts":relations,
      "groundwater_relations":material_relations,
      "profile_lower_error_route_counts":profile,
      "dimension_order":dimension_order,
      "continuous_time_vectors":key,
      "integrity":{"pass":not unresolved,"all_18_temporal_limits_supported":not unresolved,
                   "new_fine_reference_generated":False,"hydrological_model_changed":False},
      "scientific_adjudication":(
        [
          "Same-partition CoRichards temporal limits are prospectively supported on all 18 material-member cells before Richardson extrapolation is used.",
          "Layer-ROM and CoRichards are therefore compared after removing the dominant outer-step temporal truncation from both routes and against the same B1HCL-qualified fine-Reference temporal limit.",
          "A CoRichards componentwise advantage is evidence of a Layer-ROM-specific model-form/localization burden only in the bounded same-partition comparison; the error difference remains nonadditive.",
          "Dimension ordering is reported separately for both routes and no application-independent minimum dimension is inferred.",
          "Profile reconstruction remains a separate purpose axis from groundwater exchange."
        ] if not unresolved else [
          "At least one CoRichards member/material temporal limit failed the frozen prospective gate.",
          "No continuous-time Layer-ROM-versus-CoRichards model-form attribution is authorized for unresolved cells."
        ]
      ),
      "application_acceptance_adjudicated":False,"performance_measurement_performed":False,"production_rom_authorized":False
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"unresolved_cells":unresolved,
                      "groundwater_relation_counts":relations,"groundwater_relations":material_relations,
                      "profile_lower_error_route_counts":profile,"dimension_order":dimension_order},sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
