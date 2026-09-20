#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib

import numpy as np

HISTS=("R01","R02","R03","R04")
DEPTHS=np.asarray([70.,80.,90.,100.,110.,120.,130.,140.,150.,155.,157.5])
PRIMARY={150.0,155.0,157.5}
EQ=1e-10


def qstats(err,ref,cand):
    e=np.asarray(err,dtype=float); r=np.asarray(ref,dtype=float); c=np.asarray(cand,dtype=float)
    return {
      "rmse_cm_per_day":float(np.sqrt(np.mean(e*e))),
      "signed_mean_cm_per_day":float(np.mean(e)),
      "mean_abs_cm_per_day":float(np.mean(np.abs(e))),
      "max_abs_cm_per_day":float(np.max(np.abs(e))),
      "sign_mismatch_count":int(np.count_nonzero(np.sign(c)!=np.sign(r))),
    }


def mean_abs_group_bias(records,operator):
    vals=[]
    for h in HISTS:
        for dep in sorted(PRIMARY):
            x=[r for r in records if r["history"]==h and r["depth"]==dep]
            if x:
                vals.append(abs(float(np.mean([r[f"e_{operator}"] for r in x]))))
    return float(np.mean(vals)) if vals else 0.0


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--history-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    p=json.loads(a.prereg.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_C6D_INSTRUMENTED_RESPONSE_OR_OPERATOR_METRICS"
    files=sorted(a.history_dir.glob("**/LARE_BC2_C6D_HISTORY_*.json"))
    rows=[json.loads(f.read_text()) for f in files]
    if sorted(x["history"] for x in rows)!=list(HISTS):
        raise RuntimeError(f"expected exact histories {HISTS}, got {[x['history'] for x in rows]}")

    identity_ok=all(all(x["identity"][k] for k in ("state","profile","layer","face")) for x in rows)
    numerical_ok=all(x["numerical_qualification_pass"] for x in rows)
    total_realizable=sum(x["strict_state_moment_realizable_count"] for x in rows)
    total_qualified=sum(x["numerically_qualified_observation_count"] for x in rows)
    failures=[{"history":x["history"],**f} for x in rows for f in x["failures"]]
    records=[r for x in rows for r in x["records"]]

    extrema={
      "min_Se":min(x["diagnostic_extrema"]["min_Se"] for x in rows),
      "max_Se":max(x["diagnostic_extrema"]["max_Se"] for x in rows),
      "max_branch_theta":max(x["diagnostic_extrema"]["max_branch_theta"] for x in rows),
      "max_branch_pressure_cm":max(x["diagnostic_extrema"]["max_branch_pressure_cm"] for x in rows),
      "max_branch_flux_cm_per_day":max(x["diagnostic_extrema"]["max_branch_flux_cm_per_day"] for x in rows),
      "max_interface_pressure_jump_cm":max(x["diagnostic_extrema"]["max_interface_pressure_jump_cm"] for x in rows),
      "max_interface_flux_jump_cm_per_day":max(x["diagnostic_extrema"]["max_interface_flux_jump_cm_per_day"] for x in rows),
      "max_storage_recovery_cm":max(x["diagnostic_extrema"]["max_storage_recovery_cm"] for x in rows),
      "max_moment_recovery_cm2":max(x["diagnostic_extrema"]["max_moment_recovery_cm2"] for x in rows),
    }

    per={}
    primary={}
    secondary={}
    adjudication={
      "BEMR_ALL_MOVING_POINTS_NUMERICALLY_QUALIFIED":False,
      "BEMR_PRIMARY_MOVING_COMPONENTWISE_NO_WORSE":False,
      "BEMR_EACH_PRIMARY_MOVING_RMSE_NO_WORSE":False,
      "BEMR_PRIMARY_MOVING_RMSE_STRICTLY_IMPROVED":False,
      "BEMR_SUPPORTED_FOR_BOUNDARY_EXTENSION_QUALIFICATION":False
    }

    if numerical_ok and identity_ok and total_qualified==2304 and len(records)==2304*11:
        for dep in DEPTHS:
            per[str(float(dep))]={}
            for ph in ("PHASE1","PHASE2","MOVING"):
                sel=[r for r in records if r["depth"]==float(dep) and
                     ((r["phase"] in ("PHASE1","PHASE2")) if ph=="MOVING" else r["phase"]==ph)]
                per[str(float(dep))][ph]={
                  "CURRENT_LAYER_FACE":qstats([r["e_current"] for r in sel],[r["q_ref"] for r in sel],[r["q_current"] for r in sel]),
                  "BEMR":qstats([r["e_bemr"] for r in sel],[r["q_ref"] for r in sel],[r["q_bemr"] for r in sel])
                }

        mov=[r for r in records if r["depth"] in PRIMARY]
        primary={
          "CURRENT_LAYER_FACE":qstats([r["e_current"] for r in mov],[r["q_ref"] for r in mov],[r["q_current"] for r in mov]),
          "BEMR":qstats([r["e_bemr"] for r in mov],[r["q_ref"] for r in mov],[r["q_bemr"] for r in mov])
        }
        primary["CURRENT_LAYER_FACE"]["mean_abs_interface_history_signed_bias_cm_per_day"]=mean_abs_group_bias(records,"current")
        primary["BEMR"]["mean_abs_interface_history_signed_bias_cm_per_day"]=mean_abs_group_bias(records,"bemr")

        secondary={
          "CURRENT_LAYER_FACE":qstats([r["e_current"] for r in records],[r["q_ref"] for r in records],[r["q_current"] for r in records]),
          "BEMR":qstats([r["e_bemr"] for r in records],[r["q_ref"] for r in records],[r["q_bemr"] for r in records])
        }

        b=primary["CURRENT_LAYER_FACE"]; d=primary["BEMR"]
        componentwise=(
          d["rmse_cm_per_day"]<=b["rmse_cm_per_day"]+EQ and
          d["mean_abs_interface_history_signed_bias_cm_per_day"]<=b["mean_abs_interface_history_signed_bias_cm_per_day"]+EQ and
          d["sign_mismatch_count"]<=b["sign_mismatch_count"]
        )
        interface_ok=all(
          per[str(dep)]["MOVING"]["BEMR"]["rmse_cm_per_day"]<=per[str(dep)]["MOVING"]["CURRENT_LAYER_FACE"]["rmse_cm_per_day"]+EQ
          for dep in sorted(PRIMARY)
        )
        strict=d["rmse_cm_per_day"]<b["rmse_cm_per_day"]-EQ
        supported=componentwise and interface_ok and strict
        adjudication={
          "BEMR_ALL_MOVING_POINTS_NUMERICALLY_QUALIFIED":True,
          "BEMR_PRIMARY_MOVING_COMPONENTWISE_NO_WORSE":componentwise,
          "BEMR_EACH_PRIMARY_MOVING_RMSE_NO_WORSE":interface_ok,
          "BEMR_PRIMARY_MOVING_RMSE_STRICTLY_IMPROVED":strict,
          "BEMR_SUPPORTED_FOR_BOUNDARY_EXTENSION_QUALIFICATION":supported
        }
        any_improve=(
          d["rmse_cm_per_day"]<b["rmse_cm_per_day"]-EQ or
          d["mean_abs_interface_history_signed_bias_cm_per_day"]<b["mean_abs_interface_history_signed_bias_cm_per_day"]-EQ or
          d["sign_mismatch_count"]<b["sign_mismatch_count"]
        )
        any_worse=(not componentwise) or (not interface_ok)
        if supported:
            status="C6D_BEMR_SUPPORTED_FOR_BOUNDARY_EXTENSION_QUALIFICATION"
        elif any_improve and any_worse:
            status="C6D_BEMR_MIXED_NO_FREE_RUNNING"
        else:
            status="C6D_BEMR_NOT_SUPPORTED"
    else:
        status="C6D_BEMR_NOT_SUPPORTED_NUMERICAL_QUALIFICATION_FAILED"

    out={
      "schema":"swap5.lare.bc2.c6d.result.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C6D",
      "status":status,
      "role":"EXPOSED_FROZEN_STATE_MECHANISM_DIAGNOSTIC",
      "instrumentation_identity_pass":identity_ok,
      "history_identity":{x["history"]:x["identity"] for x in rows},
      "moving_observation_count":2304,
      "strict_state_moment_realizable_count":total_realizable,
      "numerically_qualified_observation_count":total_qualified,
      "numerical_qualification_pass":numerical_ok,
      "failure_count":len(failures),
      "failures":failures[:100],
      "diagnostic_extrema":extrema,
      "primary_interfaces_cm":sorted(PRIMARY),
      "primary_moving":primary,
      "per_interface_phase":per,
      "all_interface_moving":secondary,
      "adjudication":adjudication,
      "interpretation_boundaries":[
        "R01-R04 were exposed in C5R; C6D is mechanism evidence, not blind validation.",
        "Reference storage and centered moment are projected directly from immutable fine Reference water-content state; no moment is fitted.",
        "BEMR and CURRENT_LAYER_FACE are evaluated on the same Reference-projected coarse states and neither feeds back into Reference.",
        "C6D adjudicates prescribed-head moving phases only. HOLD is deliberately excluded because BEMR prescribed-flux external boundary semantics have not yet been mathematically qualified.",
        "A positive C6D authorizes only response-free prescribed-flux/HOLD boundary qualification before any fresh blind free-running test."
      ],
      "scientific_firewall":{
        "blind_validation":False,"candidate_feedback":False,
        "production_reference_changed":False,"free_running_bemr_implemented":False,
        "moment_fitting":False,"moment_localization":False,"c6c_retuning":False,
        "application_acceptance_adjudicated":False,
        "performance_comparison_authorized":False,"speed_claim_authorized":False,
        "production_rom_authorized":False
      }
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "status":status,
      "identity":identity_ok,
      "numerical_ok":numerical_ok,
      "realizable":total_realizable,
      "qualified":total_qualified,
      "primary":primary,
      "adjudication":adjudication,
      "all_interface":secondary,
      "extrema":extrema
    },sort_keys=True))


if __name__=="__main__":
    main()
