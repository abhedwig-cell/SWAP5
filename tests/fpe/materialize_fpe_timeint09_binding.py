#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()

src=Path(args.source).read_text()

old="""       sensitivity_capture = request%request_interface_sensitivity .and. request%boundary%bottom_mode == 2
       if (sensitivity_capture) call prepare_reference_tridag_factorization_capture(ws%richards)

       call headcalc"""
new="""       sensitivity_capture = request%request_interface_sensitivity .and. request%boundary%bottom_mode == 2
       ! TIMEINT09 test-only: retain the exact final normal TRIDAG
       ! factorization for one post-convergence LTE response backsolve.
       call prepare_reference_tridag_factorization_capture(ws%richards)

       call headcalc"""
if old not in src:
    raise SystemExit("TIMEINT09 factor-capture patch point missing")
src=src.replace(old,new,1)

Path(args.output).write_text(src)
print("F_PE_TIMEINT09_BINDING_MATERIALIZER=PASS")
