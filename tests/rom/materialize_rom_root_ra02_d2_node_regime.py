#!/usr/bin/env python3
"""Materialize ROM-ROOT-RA02-D2 node-level Feddes diagnostics.

Input is an already materialized RA01 Reference harness, base or segmented.
This patch only accumulates diagnostics that were already produced by the
unchanged root-water-uptake process. It does not alter hydraulic state, root
sink, Feddes parameters, numerical policy, transaction semantics, or output
acceptance gates.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

MARKER="ROM_ROOT_RA02_D2_NODE_REGIME_DIAGNOSTIC"

def one(text:str,old:str,new:str,label:str)->str:
    n=text.count(old)
    if n!=1:
        raise SystemExit(f"{label}: expected exactly one occurrence, found {n}")
    return text.replace(old,new,1)

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True,type=Path)
    ap.add_argument("--output",required=True,type=Path)
    ap.add_argument("--manifest",type=Path)
    args=ap.parse_args()

    text=args.input.read_text()
    if MARKER in text:
        raise SystemExit("RA02-D2 diagnostic already materialized")

    text=one(
      text,
      "  real(real64) :: max_abs_mass\n",
      "  real(real64) :: max_abs_mass\n"
      "  real(real64) :: d2_min_alpha,d2_min_h_minus_h3\n"
      "  integer(int64) :: d2_root_node_evals,d2_stressed_node_evals\n",
      "program diagnostic declarations"
    )

    text=one(
      text,
      "    observation_root=0.0_real64\n",
      "    observation_root=0.0_real64\n"
      "    d2_root_node_evals=0_int64; d2_stressed_node_evals=0_int64\n"
      "    d2_min_alpha=1.0_real64; d2_min_h_minus_h3=huge(0.0_real64)\n",
      "history diagnostic reset"
    )

    text=one(
      text,
      "    total_rate=fluxes%actual_uptake_total\n",
      "    total_rate=fluxes%actual_uptake_total\n"
      "    d2_root_node_evals=d2_root_node_evals+int(rooted,int64)\n"
      "    d2_stressed_node_evals=d2_stressed_node_evals+int(count(diagnostics%drought_reduction_factor(1:rooted)<1.0_real64),int64)\n"
      "    d2_min_alpha=min(d2_min_alpha,minval(diagnostics%drought_reduction_factor(1:rooted)))\n"
      "    d2_min_h_minus_h3=min(d2_min_h_minus_h3,minval(view%pressure_head(1:rooted)-diagnostics%critical_pressure_head))\n",
      "node-level diagnostic accumulation"
    )

    anchor="    write(*,'(*(g0))') 'LAREDYN0R_HISTORY_PASS|CASE=',trim(case_label(ih))"
    replacement=(
      "    write(*,'(*(g0))') 'ROM_ROOT_RA02_D2_HISTORY|CASE=',trim(case_label(ih)),"
      "'|ROOT_NODE_EVALS=',d2_root_node_evals,'|STRESSED_NODE_EVALS=',d2_stressed_node_evals,"
      "'|MIN_ALPHA=',d2_min_alpha,'|MIN_H_MINUS_H3=',d2_min_h_minus_h3\n"
      +anchor
    )
    text=one(text,anchor,replacement,"history diagnostic emission")

    text=one(
      text,
      "  write(*,'(A)') 'LAREDYN0R_EXECUTION_COMPLETE=PASS'",
      "  write(*,'(A)') 'ROM_ROOT_RA02_D2_NODE_REGIME_DIAGNOSTIC=TRUE'\n"
      "  write(*,'(A)') 'LAREDYN0R_EXECUTION_COMPLETE=PASS'",
      "diagnostic completion marker"
    )

    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(text)
    manifest={
      "schema":"swap5.rom_root.ra02_d2.materialization.v1",
      "state":"MATERIALIZED_OUTPUT_ONLY_NODE_REGIME_DIAGNOSTIC",
      "marker":MARKER,
      "input_sha256":hashlib.sha256(args.input.read_bytes()).hexdigest(),
      "output_sha256":hashlib.sha256(args.output.read_bytes()).hexdigest(),
      "diagnostics":[
        "root_node_evaluations",
        "stressed_node_evaluations_exact_alpha_lt_1",
        "minimum_exact_drought_reduction_factor",
        "minimum_pressure_head_minus_critical_h3"
      ],
      "root_sink_changed":False,
      "feddes_changed":False,
      "hydraulic_state_changed":False,
      "numerical_policy_changed":False,
      "transaction_semantics_changed":False,
      "production_source_changed":False,
      "response_based":False
    }
    if args.manifest:
        args.manifest.parent.mkdir(parents=True,exist_ok=True)
        args.manifest.write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n")
    print(json.dumps(manifest,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
