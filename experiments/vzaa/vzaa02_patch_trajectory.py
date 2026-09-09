#!/usr/bin/env python3
"""Create an instrumented copy of the qualified LMFP04 FullRichards driver.

The source driver is intentionally not modified in the repository.  This
patcher inserts accepted-step trajectory output into a temporary build copy.
It is fail-closed: both insertion anchors must occur exactly once.
"""

from __future__ import annotations

import argparse
from pathlib import Path


DECL_ANCHOR = """    integer :: codes(numnod), step, nsteps, i, iter_total, iter_max
"""

DECL_REPLACEMENT = """    integer :: codes(numnod), step, nsteps, i, iter_total, iter_max
"""

STEP_ANCHOR = """       iter_total = iter_total + result%diagnostics%nonlinear_iterations
       iter_max = max(iter_max, result%diagnostics%nonlinear_iterations)
       request%base_state%pressure_head = result%candidate_state%pressure_head
"""

STEP_REPLACEMENT = """       iter_total = iter_total + result%diagnostics%nonlinear_iterations
       iter_max = max(iter_max, result%diagnostics%nonlinear_iterations)
       write(*,'(A,3(1X,I0),6(1X,ES24.16))') 'VZAA02_STEP', case_id, refinement, step, &
            real(step - 1, real64) * step_dt, real(step, real64) * step_dt, step_dt, &
            result%top_flux, result%bottom_flux, residual
       do i = 1, numnod
          write(*,'(A,4(1X,I0),5(1X,ES24.16))') 'VZAA02_NODE', case_id, refinement, step, i, &
               dzx(i), request%base_state%pressure_head(i), request%base_state%water_content(i), &
               result%candidate_state%pressure_head(i), result%candidate_state%water_content(i)
       end do
       request%base_state%pressure_head = result%candidate_state%pressure_head
"""


def replace_exactly_once(text: str, anchor: str, replacement: str, label: str) -> str:
    count = text.count(anchor)
    if count != 1:
        raise SystemExit(f"F-VZAA02 patch drift: {label} anchor count is {count}, expected 1")
    return text.replace(anchor, replacement, 1)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()

    source = args.source.read_text(encoding="utf-8")
    patched = replace_exactly_once(source, DECL_ANCHOR, DECL_REPLACEMENT, "declaration")
    patched = replace_exactly_once(patched, STEP_ANCHOR, STEP_REPLACEMENT, "accepted-step")

    if "VZAA02_STEP" in source or "VZAA02_NODE" in source:
        raise SystemExit("F-VZAA02 source driver is already instrumented; refusing nested instrumentation")
    if patched.count("VZAA02_STEP") != 1 or patched.count("VZAA02_NODE") != 1:
        raise SystemExit("F-VZAA02 patch did not produce exactly one trajectory writer of each type")

    args.destination.parent.mkdir(parents=True, exist_ok=True)
    args.destination.write_text(patched, encoding="utf-8")
    print("F-VZAA02_TRAJECTORY_PATCH_PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
