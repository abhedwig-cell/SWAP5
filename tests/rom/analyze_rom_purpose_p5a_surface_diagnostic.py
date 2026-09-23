#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib,math

MEMBERS=("S8","S12","S16")
MATERIALS=("B01","B14")
FACTORS=(8,16,32)
ALLOW=1.6e-15

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--p4-matched-result",required=True,type=pathlib.Path)
    ap.add_argument("--root",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    pre=json.loads(a.prereg.read_text())
    p4=json.loads(a.p4_matched_result.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_ANY_P5A_DIAGNOSTIC_RESPONSE"

    cases={}; all_same=True; failing=[]; successful=[]; incomplete=[]
    for material in MATERIALS:
      cases[material]={}
      for member in MEMBERS:
        cases[material][member]={}
        for factor in FACTORS:
          path=a.root/f"p5a_SURF_P_{material}_{member}_T{factor}.json"
          x=json.loads(path.read_text())
          p4exec=p4["cases"]["SURF_P"][material][member]["numerical_qualification"]["execution_status"][f"T{factor}"]
          expected_success=(p4exec["return_code_o0"]==0 and p4exec["return_code_o2"]==0 and
                            p4exec["trace_complete"] and p4exec["scientific_trace_identity"])
          current_success=all(x["runs"][str(o)]["return_code"]==0 and
                              x["runs"][str(o)]["execution_complete"] for o in (0,2))
          topology_match=(expected_success==current_success)
          all_same=all_same and topology_match
          opt_records={}
          for o in (0,2):
            r=x["runs"][str(o)]; tm=r["terminal_marker"]
            ratio=None if tm is None else float(tm["RATIO"])
            rec={
              "return_code":r["return_code"],"execution_complete":r["execution_complete"],
              "marker_count":r["diagnostic_marker_count"],"max_ratio_to_allowance":r["max_ratio_to_allowance"],
              "terminal_ratio_to_allowance":ratio,
              "terminal_class":None if tm is None else tm.get("CLASS"),
              "terminal_bal_flags":None if tm is None else int(tm["BAL_FLAGS"]),
              "terminal_head_flags":None if tm is None else int(tm["HEAD_FLAGS"]),
              "terminal_local_integrated_cm":None if tm is None else float(tm["LOCAL_INTEGRATED_CM"]),
              "terminal_rep_bound_cm":None if tm is None else float(tm["REP_BOUND_CM"]),
              "terminal_abs_total_residual_cm":None if tm is None else float(tm["ABS_TOTAL_RESIDUAL_CM"]),
              "failure_label_seen":r["local_allowance_failure_label_seen"],
              "last_accepted_case":r["last_accepted_case"],"last_accepted_step":r["last_accepted_step"]
            }
            opt_records[f"O{o}"]=rec
          route={
            "p4_expected_success":expected_success,"p5a_success":current_success,
            "p4_pass_fail_topology_reproduced":topology_match,
            "o0_o2_terminal_diagnostic_identity":x["o0_o2_terminal_diagnostic_identity"],
            "optimization":opt_records
          }
          if current_success:
            ok=True
            for o in ("O0","O2"):
              mr=opt_records[o]["max_ratio_to_allowance"]
              ok=ok and (mr is None or (math.isfinite(float(mr)) and float(mr)<=1.0))
            route["contract_condition"]="SUCCESS_NEVER_CROSSES_ALLOWANCE" if ok else "SUCCESS_CROSSES_ALLOWANCE"
            successful.append((material,member,factor,ok))
          else:
            ok=x["o0_o2_terminal_diagnostic_identity"]
            for o in ("O0","O2"):
              rr=opt_records[o]
              ok=(ok and rr["return_code"]!=0 and rr["failure_label_seen"] and
                  rr["terminal_class"]=="RETRY_LOCAL_BALANCE" and
                  rr["terminal_bal_flags"] is not None and rr["terminal_bal_flags"]>0 and
                  rr["terminal_head_flags"]==0 and rr["terminal_ratio_to_allowance"] is not None and
                  rr["terminal_ratio_to_allowance"]>1.0 and
                  rr["terminal_abs_total_residual_cm"] is not None and
                  rr["terminal_rep_bound_cm"] is not None and
                  rr["terminal_abs_total_residual_cm"]<=rr["terminal_rep_bound_cm"])
            route["contract_condition"]="LOCAL_ALLOWANCE_BOUNDARY" if ok else "MIXED_OR_UNRESOLVED_FAILURE"
            failing.append((material,member,factor,ok))
            if not ok: incomplete.append((material,member,factor))
          cases[material][member][f"T{factor}"]=route

    fail_ok=bool(failing) and all(x[3] for x in failing)
    pass_ok=all(x[3] for x in successful)
    if not all_same:
      decision="DIAGNOSTIC_INCOMPLETE_PASS_FAIL_TOPOLOGY_CHANGED"
    elif incomplete:
      decision="MIXED_NUMERICAL_FAILURE"
    elif fail_ok and pass_ok:
      decision="CONTRACT_BOUNDARY_SUPPORTED"
    else:
      decision="DIAGNOSTIC_INCOMPLETE"

    out={
      "schema":"swap5.rom-purpose.p5a.surface-numerical-domain-result.v1",
      "workstream":"ROM-PURPOSE","work_unit":"ROM-PURPOSE-P5A-SURF-NUMERICAL-DOMAIN",
      "status":"P5A_CHARACTERIZATION_COMPLETE",
      "decision":decision,
      "allowance_cm":ALLOW,
      "failing_route_count":len(failing),"successful_route_count":len(successful),
      "p4_pass_fail_topology_reproduced":bool(all_same),
      "cases":cases,
      "interpretation":{
        "tolerance_change_authorized":False,
        "solver_policy_change_authorized":False,
        "closure_claim_authorized":False,
        "next_numerical_policy_study_motivated":decision=="CONTRACT_BOUNDARY_SUPPORTED"
      },
      "scientific_firewall":{
        "p4_reopened":False,"tolerance_changed":False,"solver_or_physics_changed":False,
        "failing_routes_continued_after_original_require":False,
        "application_acceptance_adjudicated":False,"production_rom_authorized":False
      }
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"failing_routes":len(failing),"successful_routes":len(successful)},sort_keys=True))

if __name__=="__main__": main()
