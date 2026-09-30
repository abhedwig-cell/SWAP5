#!/usr/bin/env python3
from __future__ import annotations
import argparse, subprocess
from pathlib import Path

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--root",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    root=Path(a.root).resolve()
    out=Path(a.output).resolve()
    tmp=out.with_suffix(".elastic53.tmp.f90")
    oracle=out.with_suffix(".unused_oracle.f90")

    cp=subprocess.run([
        "python3",str(root/"tests/fpe/materialize_fpe_elastic53_mode7_indicator.py"),
        "--root",str(root),
        "--indicator-out",str(tmp),
        "--oracle-out",str(oracle),
    ],text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(cp.stdout+"\n"+cp.stderr)

    s=tmp.read_text(encoding="utf-8")
    s=s.replace("module mod_fpe_elastic53_reference_richards_temporal_indicator",
                "module mod_fpe_elastic59_reference_richards_temporal_indicator")
    s=s.replace("end module mod_fpe_elastic53_reference_richards_temporal_indicator",
                "end module mod_fpe_elastic59_reference_richards_temporal_indicator")
    s=s.replace("evaluate_fpe_elastic53_reference_richards_temporal_indicator",
                "evaluate_fpe_elastic59_reference_richards_temporal_indicator")

    old="""  subroutine evaluate_fpe_elastic59_reference_richards_temporal_indicator(request, solve_result, indicator_request, indicator_result)
"""
    new="""  subroutine evaluate_fpe_elastic59_reference_richards_temporal_indicator(request, solve_result, indicator_request, indicator_result, &
       raw_head_inf, defect_head_inf)
"""
    if old not in s:
        raise SystemExit("F_PE_ELASTIC59_FAIL signature anchor")
    s=s.replace(old,new,1)

    anchor="""    type(soil_water_temporal_indicator_result_t), intent(out) :: indicator_result
"""
    insert="""    real(real64), intent(out) :: raw_head_inf, defect_head_inf
"""
    if anchor not in s:
        raise SystemExit("F_PE_ELASTIC59_FAIL declaration anchor")
    s=s.replace(anchor,anchor+insert,1)

    anchor="""    indicator_result = soil_water_temporal_indicator_result_t()
"""
    insert="""    raw_head_inf = 0.0_real64
    defect_head_inf = 0.0_real64
"""
    if anchor not in s:
        raise SystemExit("F_PE_ELASTIC59_FAIL initialization anchor")
    s=s.replace(anchor,anchor+insert,1)

    anchor="""    raw_norm = sqrt(sum(mass_weight*e_raw*e_raw))
    defect_norm = sqrt(sum(mass_weight*delta*delta))
"""
    new="""    raw_head_inf = maxval(abs(e_raw))
    defect_head_inf = maxval(abs(delta))
    raw_norm = sqrt(sum(mass_weight*e_raw*e_raw))
    defect_norm = sqrt(sum(mass_weight*delta*delta))
"""
    if anchor not in s:
        raise SystemExit("F_PE_ELASTIC59_FAIL norm anchor")
    s=s.replace(anchor,new,1)

    anchor="""    if (.not. ieee_is_finite(indicator_result%head_inf_bound) .or. indicator_result%head_inf_bound < 0.0_real64) then
"""
    new="""    if (.not. ieee_is_finite(raw_head_inf) .or. raw_head_inf < 0.0_real64 .or. &
        .not. ieee_is_finite(defect_head_inf) .or. defect_head_inf < 0.0_real64) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
       indicator_result%route = 'nonfinite-direct-head-observable'
       return
    end if
    if (.not. ieee_is_finite(indicator_result%head_inf_bound) .or. indicator_result%head_inf_bound < 0.0_real64) then
"""
    if anchor not in s:
        raise SystemExit("F_PE_ELASTIC59_FAIL finite anchor")
    s=s.replace(anchor,new,1)

    out.write_text(s,encoding="utf-8")
    try:
        tmp.unlink()
        oracle.unlink()
    except FileNotFoundError:
        pass
    print("F_PE_ELASTIC59_MATERIALIZE=PASS")

if __name__=="__main__":
    main()
