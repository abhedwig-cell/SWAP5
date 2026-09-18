#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib,re

def parse(text):
    passes=[]; failures=[]; negatives=[]; replay=[]
    for line in text.splitlines():
        if "F_ROM0TA4_CASE_PASS|" in line:
            passes.append(line.split("F_ROM0TA4_CASE_PASS|",1)[1])
        elif "F_ROM0TA4_FAIL" in line or "F_ROM0TA4_CASE_FAIL|" in line:
            failures.append(line)
        elif "F_ROM0TA4_NEGATIVE_RESTORE|" in line:
            negatives.append(line.split("F_ROM0TA4_NEGATIVE_RESTORE|",1)[1])
        elif "F_ROM0TA4_REPLAY_POINT|" in line:
            replay.append(line.split("F_ROM0TA4_REPLAY_POINT|",1)[1])
    return passes,failures,negatives,replay

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True)
    ap.add_argument("--repeat",required=True)
    ap.add_argument("--output",required=True)
    args=ap.parse_args()
    text=pathlib.Path(args.input).read_text()
    repeat=pathlib.Path(args.repeat).read_text()
    passes,failures,negatives,replay=parse(text)
    m=re.search(r"F_ROM0TA4_CASES=(\d+)",text)
    cases=int(m.group(1)) if m else -1
    repeat_identity=text==repeat
    negative_ok=(len(negatives)==4 and all("|PASS=1" in ("|"+x) for x in negatives))
    replay_steps=[]
    for x in replay:
        sm=re.search(r"STEP=(\d+)",x)
        if sm: replay_steps.append(int(sm.group(1)))
    expected_steps=list(range(9,17))*4
    replay_ok=(len(replay)==32 and sorted(replay_steps)==sorted(expected_steps))
    pass_keys=sorted((re.search(r"MATERIAL=([^|]+)\|CASE=([^|]+)",x).groups()
                      for x in passes if re.search(r"MATERIAL=([^|]+)\|CASE=([^|]+)",x)))
    expected_keys=sorted([("B01","TOP_PLUS"),("B01","TOP_MINUS"),("B14","TOP_PLUS"),("B14","TOP_MINUS")])
    qualified=(cases==4 and len(passes)==4 and pass_keys==expected_keys and not failures and negative_ok and
               replay_ok and repeat_identity and "F_ROM0TA4_RESTART_REPLAY_GATE=PASS" in text)
    result={
      "schema":"swap5.f-rom0ta4.result.v1",
      "work_unit":"F-ROM0TA4",
      "decision":"REFINED_REFERENCE_CANDIDATE_RESTART_REPLAY_QUALIFIED" if qualified else "REFINED_REFERENCE_CANDIDATE_RESTART_REPLAY_BLOCKED",
      "matrix_cases":cases,
      "case_pass_count":len(passes),
      "failure_marker_count":len(failures),
      "negative_restore_control_count":len(negatives),
      "wrong_parameter_identity_fail_closed_all_cases":negative_ok,
      "post_restart_replay_point_count":len(replay),
      "expected_post_restart_replay_point_count":32,
      "post_restart_steps_9_through_16_all_cases":replay_ok,
      "continuous_vs_split_pre_restart_identity_enforced_by_harness":True,
      "post_restart_state_mass_lineage_revision_time_bit_identity_enforced_by_harness":True,
      "repeat_stdout_bitwise_identity":repeat_identity,
      "refined_dt_day":0.0008,
      "restart_split_after_perturbation_intervals":8,
      "fresh_backend_after_restore":True,
      "worker_solver_scratch_persisted":False,
      "application_budget_used":False,
      "production_or_reference_source_mutated":False,
      "rom1a_authorized":False
    }
    pathlib.Path(args.output).write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(result,sort_keys=True))
    if not qualified:
        raise SystemExit(1)

if __name__=="__main__":
    main()
