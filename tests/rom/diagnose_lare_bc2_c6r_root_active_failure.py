#!/usr/bin/env python3
"""Diagnostic-only C6R patch.

This tool does not change C6R acceptance semantics. It adds logging around the
already frozen fail-closed root-active first-attempt path and makes the existing
direct Richards failure diagnostic replay the prescribed root sink that caused
the failed attempt.
"""
from __future__ import annotations

import argparse
from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    n = text.count(old)
    if n != 1:
        raise SystemExit(f"{label}: expected exactly one occurrence, found {n}")
    return text.replace(old, new, 1)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True, type=Path)
    ap.add_argument("--output", required=True, type=Path)
    args = ap.parse_args()

    text = args.input.read_text()

    old_fail = """    if(p%root_extraction_active)then
      if(allocated(before))deallocate(before)
      return
    end if
"""
    new_fail = """    if(p%root_extraction_active)then
      write(*,'(*(g0))') 'C6R_DIAG_ROOT_FIRST_FAILURE|STATUS=',status,'|ROUTE=',trim(route), &
           '|NL=',nl,'|IR=',ir,'|BACKTRACK=',back,'|MASS=',mass,'|BEX=',bex,'|BFLUX=',bflux
      if(status==SW_SOLVE_RETRY_ADVISED)then
        failed_nl=nl
        failed_back=back
        call diagnose_failed_interval(p,forcing,state,t0,t1,status,failed_nl,failed_back, &
             failure_class,bal_flags,head_flags,rmax,rsum,imax)
        write(*,'(*(g0))') 'C6R_DIAG_ROOT_FAILURE_CLASS|CLASS=',trim(failure_class), &
             '|BAL_FLAGS=',bal_flags,'|HEAD_FLAGS=',head_flags,'|RMAX=',rmax,'|RSUM=',rsum, &
             '|IMAX=',imax,'|DT=',t1-t0
      end if
      if(allocated(before))deallocate(before)
      return
    end if
"""
    text = replace_once(text, old_fail, new_fail, "root-active fail-closed diagnostic hook")

    old_import = "  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider\n"
    new_import = old_import + "  use mod_b110_root_sink_provider, only: b110_root_sink_provider_t, bind_b110_root_sink_provider\n"
    text = replace_once(text, old_import, new_import, "diagnostic root provider import")

    old_decl = "    type(b110_source_sink_provider_t),target :: source_sink\n"
    new_decl = old_decl + "    type(b110_root_sink_provider_t),target :: diagnostic_root_sink\n"
    text = replace_once(text, old_decl, new_decl, "diagnostic root provider declaration")

    old_arrays = "    real(real64),target :: drainage(1,numnod),irrigation(numnod),root_sink(numnod)\n"
    new_arrays = "    real(real64),target :: drainage(1,numnod),irrigation(numnod),root_sink(numnod),source_sink_root_zero(numnod)\n"
    text = replace_once(text, old_arrays, new_arrays, "diagnostic root zero declaration")

    old_sink = """    drainage=0.0_real64;irrigation=0.0_real64;root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)
"""
    new_sink = """    drainage=0.0_real64;irrigation=0.0_real64;root_sink=0.0_real64;source_sink_root_zero=0.0_real64
    if(allocated(forcing%root_extraction_sink))then
      call require(size(forcing%root_extraction_sink)==numnod,'C6R diagnostic root sink shape')
      root_sink=forcing%root_extraction_sink
    end if
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,source_sink_root_zero)
    call bind_b110_root_sink_provider(diagnostic_root_sink,root_sink)
"""
    text = replace_once(text, old_sink, new_sink, "root sink diagnostic replay binding")

    old_eval = "    request%evaluation%constitutive=>constitutive;request%evaluation%source_sink=>source_sink;request%evaluation%top_boundary=>top\n"
    new_eval = "    request%evaluation%constitutive=>constitutive;request%evaluation%source_sink=>source_sink; &\n         request%evaluation%root_sink=>diagnostic_root_sink;request%evaluation%top_boundary=>top\n"
    text = replace_once(text, old_eval, new_eval, "diagnostic root provider request binding")

    args.output.write_text(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
