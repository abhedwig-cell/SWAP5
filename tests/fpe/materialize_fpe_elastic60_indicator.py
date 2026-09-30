#!/usr/bin/env python3
from __future__ import annotations
import argparse, subprocess
from pathlib import Path

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--root",required=True)
    ap.add_argument("--output",required=True)
    ap.add_argument("--scratch-oracle",required=True)
    a=ap.parse_args()
    root=Path(a.root).resolve()
    out=Path(a.output).resolve()
    cp=subprocess.run([
        "python3",str(root/"tests/fpe/materialize_fpe_elastic53_mode7_indicator.py"),
        "--root",str(root),
        "--indicator-out",str(out),
        "--oracle-out",str(Path(a.scratch_oracle).resolve()),
    ],text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(cp.stdout+"\n"+cp.stderr)
    s=out.read_text(encoding="utf-8")
    old_sig="""  subroutine evaluate_fpe_elastic53_reference_richards_temporal_indicator(request, solve_result, indicator_request, indicator_result)
"""
    new_sig="""  subroutine evaluate_fpe_elastic53_reference_richards_temporal_indicator(request, solve_result, indicator_request, indicator_result, direct_head_inf)
"""
    if old_sig not in s: raise SystemExit("F_PE_ELASTIC60_FAIL indicator signature anchor")
    s=s.replace(old_sig,new_sig,1)
    old_decl="""    type(soil_water_temporal_indicator_result_t), intent(out) :: indicator_result

    integer :: n, i, ierr
"""
    new_decl="""    type(soil_water_temporal_indicator_result_t), intent(out) :: indicator_result
    real(real64), intent(out), optional :: direct_head_inf

    integer :: n, i, ierr
"""
    if old_decl not in s: raise SystemExit("F_PE_ELASTIC60_FAIL declaration anchor")
    s=s.replace(old_decl,new_decl,1)
    old_init="""    indicator_result = soil_water_temporal_indicator_result_t()
"""
    new_init="""    indicator_result = soil_water_temporal_indicator_result_t()
    if (present(direct_head_inf)) direct_head_inf = 0.0_real64
"""
    if old_init not in s: raise SystemExit("F_PE_ELASTIC60_FAIL init anchor")
    s=s.replace(old_init,new_init,1)
    old_success="""    raw_norm = sqrt(sum(mass_weight*e_raw*e_raw))
"""
    new_success="""    if (present(direct_head_inf)) direct_head_inf = maxval(abs(delta))
    raw_norm = sqrt(sum(mass_weight*e_raw*e_raw))
"""
    if old_success not in s: raise SystemExit("F_PE_ELASTIC60_FAIL delta anchor")
    s=s.replace(old_success,new_success,1)
    out.write_text(s,encoding="utf-8")
    print("F_PE_ELASTIC60_INDICATOR_MATERIALIZE=PASS")

if __name__=="__main__":
    main()
