#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, pathlib

def fields(line: str) -> dict[str,str]:
    out={}
    for part in line.split("|")[1:]:
        if "=" in part:
            k,v=part.split("=",1)
            out[k]=v
    return out

def main() -> int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--o0",required=True)
    ap.add_argument("--o2",required=True)
    ap.add_argument("--output",required=True)
    args=ap.parse_args()

    o0=pathlib.Path(args.o0).read_text()
    o2=pathlib.Path(args.o2).read_text()
    rows=[]
    failclosed=[]
    for line in o2.splitlines():
        if line.startswith("F_ROM1A_I0_ROW|"):
            rows.append(fields(line))
        elif line.startswith("F_ROM1A_I0_FAILCLOSED|"):
            failclosed.append(fields(line))

    expected={("B01","MODE2"),("B01","MODE5"),("B14","MODE2"),("B14","MODE5")}
    observed={(r.get("MATERIAL"),r.get("MODE")) for r in rows}
    positive=(len(rows)==4 and observed==expected and all(r.get("STATUS")=="PASS" for r in rows))
    failure_ok=(len(failclosed)==1 and failclosed[0].get("STATUS")=="PASS" and
                int(failclosed[0].get("PHYSICAL_ADVANCES","-1"))==1)
    identity=(o0==o2)
    gate_marker="F_ROM1A_I0_REFERENCE_OBSERVATION_SEAM_GATE=PASS" in o2

    decision=("CURRENT_CANONICAL_REFERENCE_OBSERVATION_SEAM_QUALIFIED"
              if positive and failure_ok and identity and gate_marker
              else "CURRENT_CANONICAL_REFERENCE_OBSERVATION_SEAM_NO_GO")
    result={
      "schema":"swap5.f-rom1a-i0.result.v1",
      "work_unit":"F-ROM1A-I0",
      "decision":decision,
      "matrix":{
        "expected_rows":4,
        "observed_rows":len(rows),
        "materials":["B01","B14"],
        "bottom_modes":[2,5],
        "all_positive_samples_pass":positive
      },
      "sample_rows":[{
        "material":r.get("MATERIAL"),
        "mode":r.get("MODE"),
        "mass_residual_cm":float(r.get("MASS","nan")),
        "bottom_exchange_cm":float(r.get("BOTTOM_EXCHANGE","nan")),
        "terminal_bottom_flux_cm_per_day":float(r.get("BOTTOM_FLUX","nan")),
        "nonlinear_iterations":int(r.get("NL","-1"))
      } for r in rows],
      "fail_closed_control":{
        "pass":failure_ok,
        "physical_advances":int(failclosed[0]["PHYSICAL_ADVANCES"]) if failclosed else None,
        "nonlinear_iterations":int(failclosed[0]["NL"]) if failclosed else None,
        "backtracking_attempts":int(failclosed[0]["BACKTRACK"]) if failclosed else None,
        "committed_revision_after_failure":int(failclosed[0]["REV"]) if failclosed else None
      },
      "o0_o2_stdout_bitwise_identity":identity,
      "hard_mass_gate_cm":1e-12,
      "ordinary_runtime_semantics_changed":False,
      "production_reference_fallback_admitted":False,
      "rom1a_trajectory_generation_authorized":decision=="CURRENT_CANONICAL_REFERENCE_OBSERVATION_SEAM_QUALIFIED"
    }
    pathlib.Path(args.output).write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(result,sort_keys=True))
    return 0 if decision=="CURRENT_CANONICAL_REFERENCE_OBSERVATION_SEAM_QUALIFIED" else 2

if __name__=="__main__":
    raise SystemExit(main())
