#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib

def find_result(root:pathlib.Path,material:str)->pathlib.Path:
    matches=list(root.rglob(f"LAYER_ROM_B1HCL_{material}_RESULT.json"))
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
    if pre["phase"]!="PREREGISTERED_BEFORE_FOURTH_REFERENCE_LEVEL_RESPONSE":
        raise SystemExit("wrong B1HCL preregistration")
    materials=list(pre["scope"]["materials"])
    rows={}
    for m in materials:
        r=json.loads(find_result(a.input_dir,m).read_text())
        if r["material"]!=m or r["work_unit"]!="LAYER-ROM-B1HCL":
            raise SystemExit(f"{m}: identity drift")
        if not r["integrity"]["pass"]:
            raise SystemExit(f"{m}: integrity failed")
        rows[m]=r

    supported_label="B1HCL_MATERIAL_FIRST_ORDER_LIMIT_SUPPORTED"
    decisions={m:r["decision"] for m,r in rows.items()}
    supported=[m for m,d in decisions.items() if d==supported_label]
    all_supported=len(supported)==len(materials)
    decision=pre["decisions"]["supported"] if all_supported else pre["decisions"]["mixed"]

    component_counts={}
    maxima={}
    for comp in ("storage_rms","cumulative_bottom_rms","qavg_rms","qend_rms","mapped_theta_rms"):
        counts={"reference_convergence_pass":0,"candidate_convergence_pass":0,
                "holdout_prediction_pass":0,"richardson_limit_pass":0,"all_gates_pass":0}
        max_pred_ratio=0.0; max_limit_ratio=0.0; min_order=None; max_order=None
        for m,r in rows.items():
            c=r["components"][comp]
            counts["reference_convergence_pass"]+=int(c["continued_reference_convergence"])
            counts["candidate_convergence_pass"]+=int(c["continued_candidate_convergence"])
            counts["holdout_prediction_pass"]+=int(c["holdout_prediction_pass"])
            counts["richardson_limit_pass"]+=int(c["richardson_limit_pass"])
            counts["all_gates_pass"]+=int(c["all_gates_pass"])
            max_pred_ratio=max(max_pred_ratio,float(c["holdout_prediction_to_ultra_rms"])/max(float(c["reference_fine_ultra_rms"]),float(c["floor"])))
            max_limit_ratio=max(max_limit_ratio,float(c["DOP853_to_first_order_Richardson_limit_rms"])/max(float(c["DOP853_to_ultra_rms"]),float(c["floor"])))
            o=c["observed_order_mid_fine_to_fine_ultra"]
            if o is not None:
                o=float(o); min_order=o if min_order is None else min(min_order,o); max_order=o if max_order is None else max(max_order,o)
        component_counts[comp]=counts
        maxima[comp]={"max_prediction_error_over_fine_ultra":max_pred_ratio,
                      "max_richardson_residual_over_candidate_ultra":max_limit_ratio,
                      "observed_order_range":[min_order,max_order]}

    result={
        "schema":"swap5.layer-rom.phase-b1hcl.adjudication.v1",
        "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1HCL",
        "decision":decision,
        "material_decisions":decisions,
        "supported_materials":supported,
        "unsupported_materials":[m for m in materials if m not in supported],
        "component_gate_counts":component_counts,
        "component_diagnostics":maxima,
        "material_components":{m:rows[m]["components"] for m in materials},
        "integrity":{"pass":True,"all_materials_present":len(rows)==len(materials),
                     "hydrological_model_changed":False},
        "interpretation":(
            [
              "The prospectively frozen fourth Reference level confirms the first-order temporal-limit hypothesis across all six materials and all five observables.",
              "The DOP853 equal-grid Layer-ROM oracle lies within the frozen Richardson-limit bound, so the previously observed equal-grid finite-Reference residual is attributed to Reference temporal truncation at the tested finite outer intervals, not to an established closure/model-form floor.",
              "Reduced L4/L6/R8 fixed-head fidelity must therefore be re-evaluated against a temporally qualified Reference before using the former finite-Reference residual as a model-form comparator."
            ] if all_supported else [
              "The first-order temporal-limit hypothesis is not uniformly confirmed across the frozen six-material panel.",
              "Only failing material-component temporal mechanisms may be diagnosed next; closure/state redesign remains held.",
              "No reduced-ladder rebasing or model-form attribution is authorized from a mixed B1HCL result."
            ]
        ),
        "application_acceptance_adjudicated":False,
        "performance_measurement_performed":False,
        "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"material_decisions":decisions,
                      "component_gate_counts":component_counts,
                      "component_diagnostics":maxima},sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
