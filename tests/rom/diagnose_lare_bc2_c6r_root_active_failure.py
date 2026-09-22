#!/usr/bin/env python3
"""Diagnostic-only C6R patch.

This tool does not change C6R acceptance semantics. It adds logging around the
already frozen fail-closed root-active first-attempt path and makes the existing
direct Richards failure diagnostic replay the prescribed root sink through the
same dedicated b110_root_sink_provider_t separation used by the serialized
Reference runtime.
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

    text = replace_once(
        text,
        "  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider\n",
        "  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider\n"
        "  use mod_b110_root_sink_provider, only: b110_root_sink_provider_t, bind_b110_root_sink_provider\n",
        "root-sink provider diagnostic import",
    )

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

    text = replace_once(
        text,
        "    type(b110_source_sink_provider_t),target :: source_sink\n",
        "    type(b110_source_sink_provider_t),target :: source_sink\n"
        "    type(b110_root_sink_provider_t),target :: root_provider\n",
        "root provider diagnostic declaration",
    )

    text = replace_once(
        text,
        "    real(real64),target :: drainage(1,numnod),irrigation(numnod),root_sink(numnod)\n",
        "    real(real64),target :: drainage(1,numnod),irrigation(numnod),root_sink(numnod),root_zero(numnod)\n",
        "root-zero diagnostic declaration",
    )

    text = replace_once(
        text,
        "    drainage=0.0_real64;irrigation=0.0_real64;root_sink=0.0_real64\n",
        """    drainage=0.0_real64;irrigation=0.0_real64;root_sink=0.0_real64;root_zero=0.0_real64
    if(allocated(forcing%root_extraction_sink))then
      call require(size(forcing%root_extraction_sink)==numnod,'C6R diagnostic root sink shape')
      root_sink=forcing%root_extraction_sink
    end if
""",
        "root sink diagnostic replay binding",
    )

    text = replace_once(
        text,
        "    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)\n",
        "    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_zero)\n"
        "    call bind_b110_root_sink_provider(root_provider,root_sink)\n",
        "separate source/root provider diagnostic binding",
    )

    text = replace_once(
        text,
        "    request%evaluation%constitutive=>constitutive;request%evaluation%source_sink=>source_sink;request%evaluation%top_boundary=>top\n",
        "    request%evaluation%constitutive=>constitutive;request%evaluation%source_sink=>source_sink\n"
        "    request%evaluation%root_sink=>root_provider;request%evaluation%top_boundary=>top\n",
        "root provider diagnostic request binding",
    )

    args.output.write_text(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
