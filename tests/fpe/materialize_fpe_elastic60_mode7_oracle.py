#!/usr/bin/env python3
from __future__ import annotations
import argparse
from pathlib import Path

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--root",required=True)
    ap.add_argument("--output",required=True)
    ap.add_argument("--preservation-output",required=True)
    a=ap.parse_args()
    root=Path(a.root).resolve()
    s=(root/"tests/fsi/test_fsi38_prescribed_qbot_temporal_certificate.f90").read_text(encoding="utf-8")

    s=s.replace("program test_fsi38_prescribed_qbot_temporal_certificate","program test_fpe_elastic60_mode7_indicator")
    s=s.replace("end program test_fsi38_prescribed_qbot_temporal_certificate","end program test_fpe_elastic60_mode7_indicator")

    # Mode-7 free-drainage equilibrium: uniform unsaturated head and qtop=-K+q.
    s=s.replace(
"""    heads(1) = h0
    do i = 2, numnod
      heads(i) = heads(i-1) + parameters%node_distance(i)
      call require(abs((heads(i-1)-heads(i))/parameters%node_distance(i)+1.0_real64) <= &
           16.0_real64*epsilon(1.0_real64), 'hydrostatic predecessor gradient')
    end do
""",
"""    heads = h0
""")
    s=s.replace(
"real(real64) :: expected_raw, expected_defect, expected_bounded, expected_binf, wrong_binf",
"real(real64) :: expected_raw, expected_defect, expected_bounded, expected_binf, wrong_binf, qeq")
    s=s.replace(
"""    call require(all(conductivity > 0.0_real64) .and. all(capacity > 0.0_real64), &
         'positive base conductivity and capacity')
""",
"""    call require(all(conductivity > 0.0_real64) .and. all(capacity > 0.0_real64), &
         'positive base conductivity and capacity')
    qeq = -conductivity(1)
""")
    s=s.replace("request%boundary%bottom_mode = 2","request%boundary%bottom_mode = 7")
    s=s.replace("request%boundary%top_flux = q","request%boundary%top_flux = qeq+q")
    s=s.replace("request%boundary%bottom_flux = q","request%boundary%bottom_flux = 0.0_real64")

    # Mode 7 owns qbot; prescribed-qbot identity and solver-native residual are not the oracle.
    s=s.replace(
"""    call require(transfer(result%bottom_flux,0_int64) == transfer(q,0_int64), 'prescribed qbot exact identity')
""","")
    s=s.replace(
"""    solver_mass = result%unrounded_mass_balance_residual
    call require(ieee_is_finite(solver_mass), 'finite solver mass residual')
    call require(max(abs(ledger_residual),abs(solver_mass)) <= hard_mass_gate, 'hard mass gate before certificate')
""",
"""    call require(abs(ledger_residual) <= hard_mass_gate, 'hard ledger mass gate before certificate')
""")

    # Replace production fail-closed assertion for mode7 with swkimpl=1 fail-closed assertion.
    start=s.find("    unsupported_request = request")
    end=s.find("    completed_cases = completed_cases + 1",start)
    if start<0 or end<0: raise SystemExit("F_PE_ELASTIC60_FAIL unsupported block")
    replacement="""    unsupported_request = request
    unsupported_request%numerical%conductivity_implicit_mode = 1
    call solver%evaluate_temporal_indicator(unsupported_request, result, indicator_request, workspace, unsupported)
    call require(unsupported%status == SW_TEMPORAL_INDICATOR_UNAVAILABLE .and. .not. unsupported%available, &
         'mode7 swkimpl1 remains unavailable')
    call require(trim(unsupported%route) == 'conductivity-policy-deferred', &
         'mode7 swkimpl1 fails closed at conductivity policy')
"""
    s=s[:start]+replacement+s[end:]

    # The FSI38 wrong-Dirichlet bounded separation is not required here: direct
    # independent operator equality is the controlling admission oracle.
    s=s.replace(
"  call require(wrong_dirichlet_separations > 0, 'oracle distinguishes Neumann from Dirichlet bottom stiffness')\n","")

    s=s.replace("FSI38_","ELASTIC60_")
    s=s.replace("mode2","mode7").replace("Mode2","Mode7")
    s=s.replace("prescribed-qbot","free-drainage")
    s=s.replace("PRESCRIBED_QBOT_TEMPORAL_CERTIFICATE","MODE7_INDICATOR_ADMISSION")

    Path(a.output).write_text(s,encoding="utf-8")

    # Preservation variant: keep the historical mode-2 independent oracle and
    # move only its "unsupported boundary" probe from newly admitted mode 7 to
    # still-unowned mode 8. The mode-2 mathematics remain byte-derived from
    # F-SI38.
    p=(root/"tests/fsi/test_fsi38_prescribed_qbot_temporal_certificate.f90").read_text(encoding="utf-8")
    p=p.replace("program test_fsi38_prescribed_qbot_temporal_certificate","program test_fpe_elastic60_fsi38_preservation")
    p=p.replace("end program test_fsi38_prescribed_qbot_temporal_certificate","end program test_fpe_elastic60_fsi38_preservation")
    p=p.replace("unsupported_request%boundary%bottom_mode = 7","unsupported_request%boundary%bottom_mode = 8")
    p=p.replace("'unowned bottom mode remains unavailable'","'still-unowned bottom mode remains unavailable'")
    p=p.replace("'unowned bottom mode fails closed at boundary envelope'","'still-unowned bottom mode fails closed at boundary envelope'")
    p=p.replace("FSI38_","ELASTIC60_PRESERVE_")
    Path(a.preservation_output).write_text(p,encoding="utf-8")

    print("F_PE_ELASTIC60_MATERIALIZE=PASS")

if __name__=="__main__":
    main()
