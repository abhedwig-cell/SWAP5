#!/usr/bin/env python3
from __future__ import annotations
import argparse
from pathlib import Path

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--root",required=True)
    ap.add_argument("--indicator-out",required=True)
    ap.add_argument("--oracle-out",required=True)
    a=ap.parse_args()
    root=Path(a.root).resolve()

    src=(root/"src/solver/mod_reference_richards_temporal_indicator.f90").read_text(encoding="utf-8")
    original=src
    src=src.replace(
        "module mod_reference_richards_temporal_indicator",
        "module mod_fpe_elastic53_reference_richards_temporal_indicator",1)
    src=src.replace(
        "end module mod_reference_richards_temporal_indicator",
        "end module mod_fpe_elastic53_reference_richards_temporal_indicator",1)
    src=src.replace(
        "public :: evaluate_reference_richards_temporal_indicator",
        "public :: evaluate_fpe_elastic53_reference_richards_temporal_indicator",1)
    src=src.replace(
        "subroutine evaluate_reference_richards_temporal_indicator(",
        "subroutine evaluate_fpe_elastic53_reference_richards_temporal_indicator(",1)
    src=src.replace(
        "end subroutine evaluate_reference_richards_temporal_indicator",
        "end subroutine evaluate_fpe_elastic53_reference_richards_temporal_indicator",1)
    old="(request%boundary%bottom_mode /= 5 .and. request%boundary%bottom_mode /= 2)"
    new="(request%boundary%bottom_mode /= 5 .and. request%boundary%bottom_mode /= 2 .and. request%boundary%bottom_mode /= 7)"
    if old not in src:
        raise SystemExit("F_PE_ELASTIC53_FAIL boundary anchor")
    src=src.replace(old,new,1)
    src=src.replace(
        "indicator_result%route = 'reference-richards-raw-bound'",
        "indicator_result%route = 'elastic53-mode7-raw-bound'",1)
    src=src.replace(
        "indicator_result%route = 'reference-richards-defect-bound'",
        "indicator_result%route = 'elastic53-mode7-defect-bound'",1)
    Path(a.indicator_out).write_text(src,encoding="utf-8")

    # Guard that the substantive research delta is only the mode-7 envelope
    # plus names/routes needed to coexist with production.
    if "bottom_mode /= 7" not in src or "if (request%boundary%bottom_mode == 5) then" not in src:
        raise SystemExit("F_PE_ELASTIC53_FAIL research indicator structure")
    if "bottom_mode == 7" in original:
        raise SystemExit("F_PE_ELASTIC53_FAIL canonical unexpectedly already admits mode7")

    oracle=(root/"tests/fsi/test_fsi38_prescribed_qbot_temporal_certificate.f90").read_text(encoding="utf-8")
    oracle=oracle.replace(
        "program test_fsi38_prescribed_qbot_temporal_certificate",
        "program test_fpe_elastic53_mode7_oracle",1)
    oracle=oracle.replace(
        "end program test_fsi38_prescribed_qbot_temporal_certificate",
        "end program test_fpe_elastic53_mode7_oracle",1)
    oracle=oracle.replace(
        "use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &",
        "use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &",1)
    # Use the research indicator directly rather than solver's production method.
    insert="""  use mod_fpe_elastic53_reference_richards_temporal_indicator, only: &
       evaluate_fpe_elastic53_reference_richards_temporal_indicator
"""
    anchor="  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t\n"
    if anchor not in oracle: raise SystemExit("F_PE_ELASTIC53_FAIL oracle use anchor")
    oracle=oracle.replace(anchor,anchor+insert,1)
    oracle=oracle.replace("request%boundary%bottom_mode = 2","request%boundary%bottom_mode = 7")
    oracle=oracle.replace(
        "call solver%evaluate_temporal_indicator(request, result, indicator_request, workspace, indicator)",
        "call evaluate_fpe_elastic53_reference_richards_temporal_indicator(request, result, indicator_request, indicator)")
    # free drainage owns bottom flux, so remove prescribed-qbot identity requirement.
    oracle=oracle.replace(
        """    call require(transfer(result%bottom_flux,0_int64) == transfer(q,0_int64), 'prescribed qbot exact identity')
""","")
    # Mass ledger already uses result%bottom_flux and remains valid.
    # Remove the unsupported-mode-7 fail-closed check; production still owns that check elsewhere.
    start=oracle.find("    unsupported_request = request")
    end=oracle.find("    completed_cases = completed_cases + 1",start)
    if start<0 or end<0: raise SystemExit("F_PE_ELASTIC53_FAIL unsupported block")
    oracle=oracle[:start]+oracle[end:]
    # Replace semantic labels only; preserve independent zero-stiffness oracle math.
    oracle=oracle.replace("FSI38_","ELASTIC53_")
    oracle=oracle.replace("mode2","mode7")
    oracle=oracle.replace("Mode2","Mode7")
    oracle=oracle.replace("prescribed-qbot","free-drainage")
    oracle=oracle.replace("PRESCRIBED_QBOT_TEMPORAL_CERTIFICATE","MODE7_TEMPORAL_ORACLE")
    # Remove now-unused unsupported request/result declarations.
    oracle=oracle.replace("type(soil_water_solve_request_t) :: request, unsupported_request","type(soil_water_solve_request_t) :: request")
    oracle=oracle.replace("type(soil_water_temporal_indicator_result_t) :: indicator, unsupported","type(soil_water_temporal_indicator_result_t) :: indicator")
    Path(a.oracle_out).write_text(oracle,encoding="utf-8")
    print("F_PE_ELASTIC53_MATERIALIZE=PASS")

if __name__=="__main__":
    main()
