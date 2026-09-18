#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib

def fields(s):
    out={}
    for p in s.split("|"):
        if "=" in p:
            k,v=p.split("=",1);out[k]=v
    return out

def b(v): return str(v).strip().upper() in {"T","TRUE",".TRUE.","1"}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True)
    ap.add_argument("--repeat",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    text=pathlib.Path(a.input).read_text()
    repeat=pathlib.Path(a.repeat).read_text()
    controls=[];steps=[];fallbacks=[];passes=[];directions=[]
    complete=None;overlap_complete=None;total_fallback=None
    for line in text.splitlines():
        if "F_ROM0R_R3D4_CONTROL|" in line:
            controls.append(fields(line.split("F_ROM0R_R3D4_CONTROL|",1)[1]))
        elif "F_ROM0R_R3D4_STEP|" in line:
            steps.append(fields(line.split("F_ROM0R_R3D4_STEP|",1)[1]))
        elif "F_ROM0R_R3D4_FALLBACK|" in line:
            fallbacks.append(fields(line.split("F_ROM0R_R3D4_FALLBACK|",1)[1]))
        elif "F_ROM0R_R3D4_POLICY_CASE_PASS|" in line:
            passes.append(fields(line.split("F_ROM0R_R3D4_POLICY_CASE_PASS|",1)[1]))
        elif "F_ROM0R_R3D4_DIRECTION|" in line:
            directions.append(fields(line.split("F_ROM0R_R3D4_DIRECTION|",1)[1]))
        elif "F_ROM0R_R3D4_POLICY_COMPLETE_COUNT=" in line:
            complete=int(line.rsplit("=",1)[1])
        elif "F_ROM0R_R3D4_OVERLAP_COMPLETE_COUNT=" in line:
            overlap_complete=int(line.rsplit("=",1)[1])
        elif "F_ROM0R_R3D4_TOTAL_FALLBACK_COUNT=" in line:
            total_fallback=int(line.rsplit("=",1)[1])

    expected_controls={
      ("B01","BOTTOM_HEAD_RISE"):(10,11),
      ("B01","BOTTOM_HEAD_FALL"):(9,10),
      ("B14","BOTTOM_HEAD_RISE"):(16,0),
      ("B14","BOTTOM_HEAD_FALL"):(16,0),
    }
    control_map={(r["MATERIAL"],r["CASE"]):(int(r["PASS_STEPS"]),int(r["FAIL_STEP"])) for r in controls}
    baseline_ok=control_map==expected_controls

    overlap_rows=[r for r in steps if b(r.get("OVERLAP","F"))]
    overlap_neutral=(len(overlap_rows)==51 and all(b(r.get("NEUTRAL","F")) for r in overlap_rows))

    fallback_rows=[]
    triggers_ok=True
    for r in fallbacks:
        row={
          "material":r["MATERIAL"],"case":r["CASE"],"step":int(r["STEP"]),
          "classification":r["CLASS"],"local_balance_flags":int(r["BAL_FLAGS"]),
          "head_flags":int(r["HEAD_FLAGS"]),"max_abs_local_residual":float(r["RMAX"]),
          "total_residual":float(r["RSUM"]),"representation_bound_cm":float(r["REP_BOUND_CM"]),
          "abs_total_residual_cm":float(r["ABS_TOTAL_RESIDUAL_CM"]),
          "residual_over_bound":float(r["RESIDUAL_OVER_BOUND"]),
          "fallback_total_tolerance":float(r["FALLBACK_TOTAL_TOL"]),
          "failed_nonlinear_iterations":int(r["FAILED_NL"]),
          "failed_backtracking":int(r["FAILED_BACKTRACK"]),
          "accepted_nonlinear_iterations":int(r["ACCEPT_NL"]),
          "accepted_backtracking":int(r["ACCEPT_BACKTRACK"]),
          "accepted_mass_residual_cm":float(r["MASS"]),
        }
        fallback_rows.append(row)
        triggers_ok &= (
          row["classification"]=="RETRY_TOTAL_ONLY"
          and row["local_balance_flags"]==0
          and row["head_flags"]==0
          and row["max_abs_local_residual"]<=1e-12
          and abs(row["total_residual"])>1e-12
          and row["abs_total_residual_cm"]<=row["representation_bound_cm"]
          and row["residual_over_bound"]<=1.0
          and abs(row["accepted_mass_residual_cm"])<=1e-12
          and row["failed_nonlinear_iterations"]==16
        )

    pass_map={(r["MATERIAL"],r["CASE"]):r for r in passes}
    all_cases=(len(pass_map)==4 and complete==4 and overlap_complete==4)
    b14_no_fallback=all(int(pass_map[(m,c)]["FALLBACKS"])==0 for m,c in [
      ("B14","BOTTOM_HEAD_RISE"),("B14","BOTTOM_HEAD_FALL")]) if all_cases else False
    b01_fallback=all(int(pass_map[(m,c)]["FALLBACKS"])>0 for m,c in [
      ("B01","BOTTOM_HEAD_RISE"),("B01","BOTTOM_HEAD_FALL")]) if all_cases else False
    fallback_count_consistent=(total_fallback==len(fallbacks) and total_fallback is not None)

    direction_map={r["MATERIAL"]:r for r in directions}
    direction_ok=(set(direction_map)=={"B01","B14"} and
                  all(b(r["LOWER_ORDER"]) and b(r["EXCHANGE_ORDER"]) for r in direction_map.values()))

    masses=[abs(float(r["MASS"])) for r in steps]+[abs(float(r["MASS"])) for r in fallbacks]
    max_mass=max(masses) if masses else None
    mass_ok=max_mass is not None and max_mass<=1e-12
    repeat_identity=text==repeat

    qualified=all([
      baseline_ok,overlap_neutral,triggers_ok,all_cases,b14_no_fallback,b01_fallback,
      fallback_count_consistent,direction_ok,mass_ok,repeat_identity,
      "F_ROM0R_R3D4_EXECUTION_COMPLETE=PASS" in text
    ])
    decision="R3_FAIL_CLOSED_TOTAL_ONLY_FALLBACK_QUALIFIED" if qualified else "R3_FAIL_CLOSED_TOTAL_ONLY_FALLBACK_NO_GO"

    result={
      "schema":"swap5.f-rom0r.r3d4-result.v1",
      "work_unit":"ROM-0R-R3D4",
      "decision":decision,
      "baseline_provenance_reproduced":baseline_ok,
      "overlap":{
        "expected_original_accepted_steps":51,
        "observed_original_accepted_overlap_steps":len(overlap_rows),
        "all_bit_neutral":overlap_neutral,
      },
      "fallback":{
        "count":len(fallbacks),
        "count_consistent":fallback_count_consistent,
        "B01_positive_both_directions":b01_fallback,
        "B14_zero_both_directions":b14_no_fallback,
        "all_triggers_total_only_within_pre_solve_bound":triggers_ok,
        "rows":fallback_rows,
      },
      "full_horizon":{
        "case_pass_count":len(pass_map),
        "all_four_complete":all_cases,
      },
      "directional_reachability":{
        m:{
          "lower_order":b(r["LOWER_ORDER"]),
          "exchange_order":b(r["EXCHANGE_ORDER"]),
          "rise_lower_storage_cm":float(r["RISE_LOWER"]),
          "fall_lower_storage_cm":float(r["FALL_LOWER"]),
          "rise_bottom_outward_exchange_cm":float(r["RISE_BOTTOM_OUT"]),
          "fall_bottom_outward_exchange_cm":float(r["FALL_BOTTOM_OUT"]),
        } for m,r in direction_map.items()
      },
      "directional_reachability_pass":direction_ok,
      "max_abs_committed_transaction_mass_residual_cm":max_mass,
      "hard_mass_gate_pass":mass_ok,
      "repeat_stdout_bitwise_identity":repeat_identity,
      "representation_bound_formula":"0.5 * sum_i((spacing(theta_s_material) + spacing(theta_base_i)) * dz_i)",
      "fallback_tolerance_formula":"max(1e-12, representation_bound_cm/dt)",
      "observed_failed_residual_used_to_choose_tolerance":False,
      "dt_subdivision_used":False,
      "production_or_reference_source_mutated":False,
      "production_fallback_admitted":False,
      "rom1a_authorized":False,
    }
    pathlib.Path(a.output).write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(result,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
