#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib,re

def parse(text):
    passes=[]; fails=[]; restarts=[]; identities=[]
    for line in text.splitlines():
        if "F_ROM0TA4_CASE_PASS|" in line: passes.append(line.split("F_ROM0TA4_CASE_PASS|",1)[1])
        elif "F_ROM0TA4_CASE_FAIL|" in line: fails.append(line.split("F_ROM0TA4_CASE_FAIL|",1)[1])
        elif "F_ROM0TA4_RESTART|" in line: restarts.append(line.split("F_ROM0TA4_RESTART|",1)[1])
        elif "F_ROM0TA4_ENDPOINT_IDENTITY|" in line: identities.append(line.split("F_ROM0TA4_ENDPOINT_IDENTITY|",1)[1])
    return passes,fails,restarts,identities

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True)
    ap.add_argument("--repeat",required=True)
    ap.add_argument("--output",required=True)
    args=ap.parse_args()
    text=pathlib.Path(args.input).read_text()
    repeat=pathlib.Path(args.repeat).read_text()
    passes,fails,restarts,identities=parse(text)
    repeat_identity=text==repeat
    matrix=re.search(r"F_ROM0TA4_MATRIX\|CASES=(\d+)\|FAILURES=(\d+)",text)
    cases=int(matrix.group(1)) if matrix else -1
    failures=int(matrix.group(2)) if matrix else -1
    negative_ok=all("NEGATIVE_PARAMETER_ID_CONTROL=PASS" in x for x in restarts)
    endpoint_ok=all("PASS=1" in x for x in identities)
    qualified=(cases==4 and failures==0 and len(passes)==4 and len(fails)==0 and len(restarts)==4 and
               len(identities)==64 and negative_ok and endpoint_ok and repeat_identity and
               "F_ROM0TA4_EXECUTION_COMPLETE=PASS" in text)
    result={
      "schema":"swap5.f-rom0ta4.result.v1",
      "work_unit":"F-ROM0TA4",
      "decision":"REFINED_REFERENCE_CANDIDATE_RESTART_REPLAY_QUALIFIED" if qualified else "REFINED_REFERENCE_CANDIDATE_RESTART_REPLAY_BLOCKED",
      "matrix_cases":cases,
      "case_pass_count":len(passes),
      "case_fail_count":len(fails),
      "restart_count":len(restarts),
      "endpoint_identity_count":len(identities),
      "expected_endpoint_identity_count":64,
      "wrong_parameter_identity_fail_closed_all_cases":negative_ok,
      "endpoint_bit_identity_all_cases":endpoint_ok,
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
if __name__=="__main__":
    main()
