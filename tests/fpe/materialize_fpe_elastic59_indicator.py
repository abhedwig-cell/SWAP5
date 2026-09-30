#!/usr/bin/env python3
from __future__ import annotations
import argparse
from pathlib import Path

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--root",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    root=Path(a.root).resolve()
    src=(root/"src/solver/mod_reference_richards_temporal_indicator.f90").read_text(encoding="utf-8")

    src=src.replace(
        "module mod_reference_richards_temporal_indicator",
        "module mod_fpe_elastic59_reference_richards_temporal_indicator",1)
    src=src.replace(
        "end module mod_reference_richards_temporal_indicator",
        "end module mod_fpe_elastic59_reference_richards_temporal_indicator",1)
    src=src.replace(
        "public :: evaluate_reference_richards_temporal_indicator",
        "public :: evaluate_fpe_elastic59_reference_richards_temporal_indicator",1)
    src=src.replace(
        "subroutine evaluate_reference_richards_temporal_indicator(request, solve_result, indicator_request, indicator_result)",
        "subroutine evaluate_fpe_elastic59_reference_richards_temporal_indicator(request, solve_result, indicator_request, indicator_result, raw_head_inf, defect_head_inf, head_candidate)",1)
    src=src.replace(
        "end subroutine evaluate_reference_richards_temporal_indicator",
        "end subroutine evaluate_fpe_elastic59_reference_richards_temporal_indicator",1)

    old="(request%boundary%bottom_mode /= 5 .and. request%boundary%bottom_mode /= 2)"
    new="(request%boundary%bottom_mode /= 5 .and. request%boundary%bottom_mode /= 2 .and. request%boundary%bottom_mode /= 7)"
    if old not in src: raise SystemExit("F_PE_ELASTIC59_FAIL boundary anchor")
    src=src.replace(old,new,1)

    decl="    type(soil_water_temporal_indicator_result_t), intent(out) :: indicator_result\n"
    add=decl+"    real(real64), intent(out) :: raw_head_inf, defect_head_inf, head_candidate\n"
    if decl not in src: raise SystemExit("F_PE_ELASTIC59_FAIL decl anchor")
    src=src.replace(decl,add,1)

    init="    indicator_result = soil_water_temporal_indicator_result_t()\n"
    init2=init+"    raw_head_inf = 0.0_real64\n    defect_head_inf = 0.0_real64\n    head_candidate = 0.0_real64\n"
    if init not in src: raise SystemExit("F_PE_ELASTIC59_FAIL init anchor")
    src=src.replace(init,init2,1)

    anchor="""    raw_norm = sqrt(sum(mass_weight*e_raw*e_raw))
    defect_norm = sqrt(sum(mass_weight*delta*delta))
    bounded_norm = min(raw_norm, 2.0_real64*defect_norm)
"""
    replacement=anchor+"""    raw_head_inf = maxval(abs(e_raw))
    defect_head_inf = maxval(abs(delta))
    head_candidate = min(raw_head_inf, 2.0_real64*defect_head_inf)
    if (.not. ieee_is_finite(raw_head_inf) .or. raw_head_inf < 0.0_real64 .or. &
        .not. ieee_is_finite(defect_head_inf) .or. defect_head_inf < 0.0_real64 .or. &
        .not. ieee_is_finite(head_candidate) .or. head_candidate < 0.0_real64) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
       indicator_result%route = 'elastic59-nonfinite-headspace'
       return
    end if
"""
    if anchor not in src: raise SystemExit("F_PE_ELASTIC59_FAIL norm anchor")
    src=src.replace(anchor,replacement,1)

    src=src.replace(
        "indicator_result%route = 'reference-richards-raw-bound'",
        "indicator_result%route = 'elastic59-mode7-raw-bound'",1)
    src=src.replace(
        "indicator_result%route = 'reference-richards-defect-bound'",
        "indicator_result%route = 'elastic59-mode7-defect-bound'",1)

    Path(a.output).write_text(src,encoding="utf-8")
    print("F_PE_ELASTIC59_INDICATOR_MATERIALIZE=PASS")

if __name__=="__main__":
    main()
