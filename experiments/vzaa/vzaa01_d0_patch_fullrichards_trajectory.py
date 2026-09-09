from __future__ import annotations

import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: vzaa01_d0_patch_fullrichards_trajectory.py INPUT_F90 OUTPUT_F90")
    src = Path(sys.argv[1]).read_text()

    old_loop = "  do case_id = 1, 6\n"
    if old_loop not in src:
        raise SystemExit("expected F-LMFP04 case loop not found")
    src = src.replace(old_loop, "  do case_id = 1, 4\n", 1)

    needle = (
        "       iter_total = iter_total + result%diagnostics%nonlinear_iterations\n"
        "       iter_max = max(iter_max, result%diagnostics%nonlinear_iterations)\n"
        "       request%base_state%pressure_head = result%candidate_state%pressure_head\n"
    )
    if needle not in src:
        raise SystemExit("expected F-LMFP04 accepted-step commit seam not found")

    replacement = (
        "       iter_total = iter_total + result%diagnostics%nonlinear_iterations\n"
        "       iter_max = max(iter_max, result%diagnostics%nonlinear_iterations)\n"
        "       write(*,'(A,1X,I0,1X,I0,1X,I0,1X,ES24.16,1X,ES24.16,1X,ES24.16,1X,ES24.16,1X,I0)') &\n"
        "            'D0STEP', case_id, refinement, step, step_dt, result%top_flux, result%bottom_flux, residual, &\n"
        "            result%diagnostics%nonlinear_iterations\n"
        "       do i = 1, numnod\n"
        "          write(*,'(A,1X,I0,1X,I0,1X,I0,1X,I0,1X,ES24.16,1X,ES24.16,1X,ES24.16)') &\n"
        "               'D0NODE', case_id, refinement, step, i, request%base_state%water_content(i), &\n"
        "               result%candidate_state%water_content(i), result%candidate_state%pressure_head(i)\n"
        "       end do\n"
        "       request%base_state%pressure_head = result%candidate_state%pressure_head\n"
    )
    src = src.replace(needle, replacement, 1)
    Path(sys.argv[2]).write_text(src)


if __name__ == "__main__":
    main()
