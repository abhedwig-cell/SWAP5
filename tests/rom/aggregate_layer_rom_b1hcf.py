#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib

MATERIALS=("B02","B05","B06","B11","B12","B16")
MEMBERS=("L4","L6","R8")
PLACEMENT=(("dimension4","L4","U4"),("dimension8","R8","U8"))
GW=(
 "storage_rmse_cm","cumulative_bottom_rmse_cm","qavg_rmse_cm_per_day","qavg_sign_errors",
 "abs_mean_signed_qavg_error_cm_per_day","qend_rmse_cm_per_day","qend_sign_errors",
 "abs_mean_signed_qend_error_cm_per_day","max_abs_final_cumulative_bottom_error_cm"
)
PROFILE=("upper_storage_rmse_cm","lower_storage_rmse_cm","mapped_theta_rmse")

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    p=json.loads(a.prereg.read_text())
    if p["phase"]!="PREREGISTERED_BEFORE_CORRECTED_FIXED_HEAD_FLUX_METRICS":
        raise SystemExit("wrong B1HCF preregistration")

    rows={}
    for f in a.input_dir.rglob("LAYER_ROM_B1HCF_*_RESULT.json"):
        r=json.loads(f.read_text())
        if r.get("schema")!="swap5.layer-rom.phase-b1hcf.material-result.v1": continue
        m=r["material"]
        if m in rows: raise SystemExit(f"duplicate material {m}")
        rows[m]=r
    if set(rows)!=set(MATERIALS):
        raise SystemExit(f"material set mismatch {sorted(rows)}")
    if not all(r["integrity"]["pass"] for r in rows.values()):
        raise SystemExit("material integrity failure")

    placement={}
    for label,_,_ in PLACEMENT:
        placement[label]={
          "GW":{m:rows[m]["corrected_placement"][label]["GW"]["vector_relation"] for m in MATERIALS},
          "PROFILE":{m:rows[m]["corrected_placement"][label]["PROFILE"]["vector_relation"] for m in MATERIALS},
        }

    same_partition={member:{
      "GW":{m:rows[m]["corrected_same_partition"][member]["GW"]["vector_relation"] for m in MATERIALS},
      "PROFILE":{m:rows[m]["corrected_same_partition"][member]["PROFILE"]["vector_relation"] for m in MATERIALS},
    } for member in MEMBERS}

    same_counts={}
    for member in MEMBERS:
      same_counts[member]={}
      for vector in ("GW","PROFILE"):
        vals=list(same_partition[member][vector].values())
        same_counts[member][vector]={x:vals.count(x) for x in (
          "A_COMPONENTWISE_NO_WORSE","B_COMPONENTWISE_NO_WORSE","NUMERICALLY_EQUIVALENT","TRADEOFF"
        )}

    dimorder={}
    for route in ("LayerROM","CoRichards"):
      dimorder[route]={k:{
        "all_six_materials_nonincreasing":all(rows[m]["day1_dimension_order"][route][k]["nonincreasing"] for m in MATERIALS),
        "materials_nonincreasing":[m for m in MATERIALS if rows[m]["day1_dimension_order"][route][k]["nonincreasing"]],
        "materials_nonmonotone":[m for m in MATERIALS if not rows[m]["day1_dimension_order"][route][k]["nonincreasing"]],
      } for k in GW+PROFILE}

    r16={m:rows[m]["R16_OP_day1"] for m in MATERIALS}
    tol=float(p["adjudication_rules"]["relation_tolerance"])
    qavg_nonzero=[m for m in MATERIALS if float(r16[m]["qavg_rmse_cm_per_day"])>tol or int(r16[m]["qavg_sign_errors"])>0]
    qend_nonzero=[m for m in MATERIALS if float(r16[m]["qend_rmse_cm_per_day"])>tol or int(r16[m]["qend_sign_errors"])>0]
    temporal_signal=bool(qavg_nonzero or qend_nonzero)

    impact={m:rows[m]["old_to_corrected_flux_metric_impact"] for m in MATERIALS}
    result={
      "schema":"swap5.layer-rom.phase-b1hcf.aggregate-result.v1",
      "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1HCF",
      "decision":"B1HCF_CORRECTED_FIXED_HEAD_METRICS_RECONCILED",
      "materials":list(MATERIALS),
      "corrected_placement_relations":placement,
      "corrected_same_partition_relations":same_partition,
      "corrected_same_partition_relation_counts":same_counts,
      "day1_dimension_order":dimorder,
      "R16_OP_day1":r16,
      "R16_OP_numerical_residual_diagnostic":{
        "relation_tolerance":tol,
        "qavg_nonzero_materials":qavg_nonzero,
        "qend_nonzero_materials":qend_nonzero,
        "temporal_state_evolution_diagnosis_authorized":temporal_signal,
        "meaning":"Above numerical relation tolerance only; this is not an application tolerance."
      },
      "old_to_corrected_flux_metric_impact":impact,
      "supersession":{
        "superseded":["mixed-semantics bottom_flux_rmse_cm_per_day","mixed-semantics bottom_flux_sign_errors"],
        "retained":["storage","cumulative bottom exchange","upper/lower storage","mapped profile"],
        "prior_fixed_head_multicomponent_frontiers":"HELD_UNTIL_REBUILT_WITH_QAVG_QEND"
      },
      "scientific_adjudication":[
        "QAVG and QEND are now commensurate by construction; the prior terminal-candidate versus interval-average Reference flux comparison is superseded.",
        "Same-partition comparisons remain descriptive decompositions, not additive closure-error estimates.",
        "Any R16_OP residual above the numerical relation tolerance is evidence that fixed-grid Layer-ROM time/state evolution still differs from the Reference route even when spatial resolution is removed; its hydrological materiality is not adjudicated here.",
        "No weighted score, application threshold, runtime claim or production-ROM decision is made."
      ],
      "next":(
        "Preregister corrected temporal/state-evolution diagnosis using QAVG/QEND and immutable six-material evidence; separately rebuild B01 B1/B2 fixed-head frontier authority."
        if temporal_signal else
        "Rebuild B01 B1/B2 fixed-head frontier authority and then reassess closure localization without temporal refinement."
      ),
      "application_acceptance_adjudicated":False,
      "performance_measurement_performed":False,
      "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "decision":result["decision"],
      "same_partition_counts":same_counts,
      "placement":placement,
      "R16_OP_nonzero":{"QAVG":qavg_nonzero,"QEND":qend_nonzero},
      "next":result["next"]
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
