#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, math, pathlib
import numpy as np

HISTS=("R01","R02","R03","R04")
PRIMARY=(150.0,155.0,157.5)
TOL=1.0e-10

def metrics(ref,cand):
    ref=np.asarray(ref,float);cand=np.asarray(cand,float)
    err=cand-ref
    return {
      "count":int(err.size),
      "flux_error_rmse_cm_per_day":float(np.sqrt(np.mean(err*err))),
      "signed_mean_flux_error_cm_per_day":float(np.mean(err)),
      "mean_abs_flux_error_cm_per_day":float(np.mean(np.abs(err))),
      "max_abs_flux_error_cm_per_day":float(np.max(np.abs(err))),
      "sign_mismatch_count":int(np.count_nonzero(np.sign(cand)!=np.sign(ref)))
    }

def phase_labels(pre,history):
    d=pre["blind_design"]["phase_schedule_observation_steps"][history]
    n1=int(d["phase1_steps"]);n2=int(d["phase2_steps"])
    return np.asarray(["PHASE1" if i<=n1 else "PHASE2" if i<=n1+n2 else "HOLD" for i in range(1,1025)],object)

def pooled_bias(refs,cands,depths,phase_masks):
    vals=[]
    for h in HISTS:
        ref=refs[h];cand=cands[h]
        for dep in depths:
            j=refs["depth_index"][dep]
            mask=phase_masks[h]
            vals.append(abs(float(np.mean(cand[mask,j]-ref[mask,j]))))
    return float(np.mean(vals))

def collect(rows,operator,depths,phase_selector):
    ref_parts=[];cand_parts=[]
    for h in HISTS:
        r=rows[h]
        ref=np.asarray(r["q_reference_cm_per_day"],float)
        cand=np.asarray(r[operator],float)
        phases=phase_labels(rows["prereg"],h)
        mask=phase_selector(phases)
        for dep in depths:
            j=rows["depth_index"][dep]
            ref_parts.append(ref[mask,j]);cand_parts.append(cand[mask,j])
    return np.concatenate(ref_parts),np.concatenate(cand_parts)

def main():
    ap=argparse.ArgumentParser()
    for h in HISTS:
        ap.add_argument(f"--{h.lower()}",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c5s",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    s=json.loads(a.c5s.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_C5T_INSTRUMENTED_RESPONSE_OR_OPERATOR_METRICS"
    assert s["decision"]=="PREREGISTER_FROZEN_STATE_DARCIAN_TWO_POINT_INTERFACE_FLUX_DISCRIMINATOR_BEFORE_FREE_RUNNING_IMPLEMENTATION"
    rows={"prereg":pre}
    numerical={}
    depths=None
    for h in HISTS:
        r=json.loads(getattr(a,h.lower()).read_text())
        assert r["history"]==h
        rows[h]=r
        numerical[h]=r["numerical_qualification"]
        if depths is None: depths=[float(x) for x in r["face_depths_cm"]]
        assert depths==[float(x) for x in r["face_depths_cm"]]
    rows["depth_index"]={d:i for i,d in enumerate(depths)}
    all_num=all(rows[h]["status"]=="QUALIFIED" and numerical[h].get("all_points_qualified") is True for h in HISTS)

    operators={
      "CURRENT_LAYER_FACE":"q_current_layer_face_cm_per_day",
      "DSE2P":"q_dse2p_cm_per_day"
    }
    per_interface_phase={}
    if all_num:
        for opname,key in operators.items():
            per_interface_phase[opname]={}
            for dep in depths:
                per_interface_phase[opname][str(dep)]={}
                j=rows["depth_index"][dep]
                for phase in ("PHASE1","PHASE2","HOLD"):
                    rr=[];cc=[]
                    for h in HISTS:
                        labs=phase_labels(pre,h)
                        mask=labs==phase
                        rr.append(np.asarray(rows[h]["q_reference_cm_per_day"],float)[mask,j])
                        cc.append(np.asarray(rows[h][key],float)[mask,j])
                    per_interface_phase[opname][str(dep)][phase]=metrics(np.concatenate(rr),np.concatenate(cc))

        moving=lambda p:p!="HOLD"
        hold=lambda p:p=="HOLD"
        primary={}
        hold_guard={}
        all_moving={}
        for opname,key in operators.items():
            rr,cc=collect(rows,key,list(PRIMARY),moving)
            pm=metrics(rr,cc)
            masks={h:phase_labels(pre,h)!="HOLD" for h in HISTS}
            refs={h:np.asarray(rows[h]["q_reference_cm_per_day"],float) for h in HISTS}
            cands={h:np.asarray(rows[h][key],float) for h in HISTS}
            pm["mean_abs_interface_history_signed_bias_cm_per_day"]=pooled_bias(refs,cands,list(PRIMARY),masks)
            primary[opname]=pm

            rr,cc=collect(rows,key,list(PRIMARY),hold)
            hold_guard[opname]=metrics(rr,cc)

            rr,cc=collect(rows,key,depths,moving)
            am=metrics(rr,cc)
            masks={h:phase_labels(pre,h)!="HOLD" for h in HISTS}
            am["mean_abs_interface_history_signed_bias_cm_per_day"]=pooled_bias(refs,cands,depths,masks)
            all_moving[opname]=am

        interface_moving={}
        for opname,key in operators.items():
            interface_moving[opname]={}
            for dep in depths:
                rr,cc=collect(rows,key,[dep],moving)
                interface_moving[opname][str(dep)]=metrics(rr,cc)

        cur=primary["CURRENT_LAYER_FACE"];dse=primary["DSE2P"]
        primary_no_worse=(
          dse["flux_error_rmse_cm_per_day"]<=cur["flux_error_rmse_cm_per_day"]+TOL and
          dse["mean_abs_interface_history_signed_bias_cm_per_day"]<=cur["mean_abs_interface_history_signed_bias_cm_per_day"]+TOL and
          dse["sign_mismatch_count"]<=cur["sign_mismatch_count"]
        )
        strict=dse["flux_error_rmse_cm_per_day"]<cur["flux_error_rmse_cm_per_day"]-TOL
        each_primary=all(
          interface_moving["DSE2P"][str(dep)]["flux_error_rmse_cm_per_day"]<=
          interface_moving["CURRENT_LAYER_FACE"][str(dep)]["flux_error_rmse_cm_per_day"]+TOL
          for dep in PRIMARY
        )
        hold_ok=(
          hold_guard["DSE2P"]["sign_mismatch_count"]<=hold_guard["CURRENT_LAYER_FACE"]["sign_mismatch_count"] and
          hold_guard["DSE2P"]["flux_error_rmse_cm_per_day"]<=hold_guard["CURRENT_LAYER_FACE"]["flux_error_rmse_cm_per_day"]+TOL
        )
        supported=primary_no_worse and strict and each_primary and hold_ok
        any_improve=(
          dse["flux_error_rmse_cm_per_day"]<cur["flux_error_rmse_cm_per_day"]-TOL or
          any(interface_moving["DSE2P"][str(dep)]["flux_error_rmse_cm_per_day"]<
              interface_moving["CURRENT_LAYER_FACE"][str(dep)]["flux_error_rmse_cm_per_day"]-TOL for dep in depths)
        )
        if supported:
            status="DSE2P_SUPPORTED_FOR_FREE_RUNNING_TEST"
        elif any_improve:
            status="DSE2P_MIXED_NO_IMPLEMENTATION"
        else:
            status="DSE2P_NOT_SUPPORTED"
        adjudication={
          "all_DSE2P_points_numerically_qualified":True,
          "primary_moving_componentwise_no_worse":primary_no_worse,
          "primary_moving_strict_RMSE_improvement":strict,
          "each_primary_interface_moving_RMSE_no_worse":each_primary,
          "primary_HOLD_guard_passes":hold_ok,
          "supported_for_free_running_test":supported
        }
    else:
        status="DSE2P_NOT_SUPPORTED"
        per_interface_phase={}
        primary={};hold_guard={};all_moving={};interface_moving={}
        adjudication={
          "all_DSE2P_points_numerically_qualified":False,
          "primary_moving_componentwise_no_worse":False,
          "primary_moving_strict_RMSE_improvement":False,
          "each_primary_interface_moving_RMSE_no_worse":False,
          "primary_HOLD_guard_passes":False,
          "supported_for_free_running_test":False
        }

    out={
      "schema":"swap5.lare.bc2.c5t.result.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C5T",
      "role":"EXPOSED_MECHANISM_FROZEN_STATE_INTERFACE_FLUX_DIAGNOSTIC",
      "status":status,
      "blind_validation":False,
      "numerical_qualification":numerical,
      "per_interface_phase":per_interface_phase,
      "primary_moving":primary,
      "primary_hold_guard":hold_guard,
      "all_interface_moving":all_moving,
      "interface_moving":interface_moving,
      "adjudication":adjudication,
      "interpretation_boundaries":[
        "C5T evaluates both operators on exact Reference-projected D12_B2P5 states; neither operator feeds back into the Reference solve.",
        "A supported result authorizes only a separate fresh blind free-running research test, not production use.",
        "A mixed or unsupported result must not be scalar-tuned; the next route is SCAFP theory or representation-family comparison.",
        "R2048_T16 remains a fine numerical mechanism trajectory, not continuum truth."
      ],
      "scientific_firewall":{
        "blind_validation":False,
        "production_reference_changed":False,
        "free_running_closure_implemented":False,
        "dynamic_state_changed":False,
        "scalar_tuning_reopened":False,
        "application_acceptance_adjudicated":False,
        "performance_comparison_authorized":False,
        "speed_claim_authorized":False,
        "production_rom_authorized":False
      }
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    brief={
      "status":status,
      "adjudication":adjudication,
      "primary_moving":primary,
      "primary_hold_guard":hold_guard,
      "primary_interface_moving":{
        op:{str(dep):interface_moving.get(op,{}).get(str(dep)) for dep in PRIMARY}
        for op in operators
      }
    }
    print(json.dumps(brief,sort_keys=True))

if __name__=="__main__":
    main()
