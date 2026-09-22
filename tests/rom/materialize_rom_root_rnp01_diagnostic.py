#!/usr/bin/env python3
"""Materialize ROM-ROOT-RNP01 diagnostic instrumentation.

Input must already contain the C6R diagnostic provider repair. This patch only
adds observability and non-committing 32/64-iteration shadow solves on the exact
failed interval. It does not alter the primary C6R trial or production sources.
"""
from __future__ import annotations

import argparse
from pathlib import Path

START = "  subroutine diagnose_failed_interval"
END = "  end subroutine diagnose_failed_interval"
MARKER = "ROM_ROOT_RNP01_DIAGNOSTIC"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    n = text.count(old)
    if n != 1:
        raise SystemExit(f"{label}: expected one occurrence, found {n}")
    return text.replace(old, new, 1)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True, type=Path)
    ap.add_argument("--output", required=True, type=Path)
    args = ap.parse_args()

    text = args.input.read_text()
    i = text.find(START)
    j = text.find(END, i)
    if i < 0 or j < 0:
        raise SystemExit("diagnose_failed_interval block not found")
    block = text[i:j]
    if MARKER in block:
        raise SystemExit("RNP01 diagnostic already materialized")

    block = replace_once(
        block,
        "    type(soil_water_solve_result_t) :: result\n",
        "    type(soil_water_solve_result_t) :: result, shadow_result32, shadow_result64\n",
        "shadow result declarations",
    )
    block = replace_once(
        block,
        "    type(reference_richards_legacy_workspace_t) :: workspace\n",
        "    type(reference_richards_legacy_workspace_t) :: workspace, shadow_workspace32, shadow_workspace64\n",
        "shadow workspace declarations",
    )
    block = replace_once(
        block,
        "    logical :: got,context_ok\n",
        "    logical :: got,context_ok\n    integer :: i\n",
        "residual index declaration",
    )

    anchor = "    if(allocated(snap))deallocate(snap)\n"
    diagnostic = """    ! ROM_ROOT_RNP01_DIAGNOSTIC: observe the exact failed interval only.
    write(*,'(*(g0))') 'RNP01_PRIMARY|STATUS=',result%status, &
         '|ROUTE=',trim(result%diagnostics%route), &
         '|NL=',result%diagnostics%nonlinear_iterations, &
         '|BACKTRACK=',result%diagnostics%backtracking_attempts, &
         '|NAIVE_SUM=',sum(workspace%richards%residual), &
         '|MAXABS=',maxval(abs(workspace%richards%residual)), &
         '|L1=',sum(abs(workspace%richards%residual)), &
         '|L2=',sqrt(sum(workspace%richards%residual*workspace%richards%residual)), &
         '|BAL_FLAGS=',count(workspace%richards%nonconverged_balance), &
         '|HEAD_FLAGS=',count(workspace%richards%nonconverged_head)
    do i=1,numnod
      write(*,'(*(g0))') 'RNP01_RESIDUAL|I=',i,'|R=',workspace%richards%residual(i)
    end do

    request%numerical%max_iterations=32
    call solver%solve(request,shadow_workspace32,shadow_result32)
    write(*,'(*(g0))') 'RNP01_SHADOW|MAXIT=32|STATUS=',shadow_result32%status, &
         '|ROUTE=',trim(shadow_result32%diagnostics%route), &
         '|NL=',shadow_result32%diagnostics%nonlinear_iterations, &
         '|BACKTRACK=',shadow_result32%diagnostics%backtracking_attempts, &
         '|NAIVE_SUM=',sum(shadow_workspace32%richards%residual), &
         '|MAXABS=',maxval(abs(shadow_workspace32%richards%residual)), &
         '|L1=',sum(abs(shadow_workspace32%richards%residual)), &
         '|BAL_FLAGS=',count(shadow_workspace32%richards%nonconverged_balance), &
         '|HEAD_FLAGS=',count(shadow_workspace32%richards%nonconverged_head)

    request%numerical%max_iterations=64
    call solver%solve(request,shadow_workspace64,shadow_result64)
    write(*,'(*(g0))') 'RNP01_SHADOW|MAXIT=64|STATUS=',shadow_result64%status, &
         '|ROUTE=',trim(shadow_result64%diagnostics%route), &
         '|NL=',shadow_result64%diagnostics%nonlinear_iterations, &
         '|BACKTRACK=',shadow_result64%diagnostics%backtracking_attempts, &
         '|NAIVE_SUM=',sum(shadow_workspace64%richards%residual), &
         '|MAXABS=',maxval(abs(shadow_workspace64%richards%residual)), &
         '|L1=',sum(abs(shadow_workspace64%richards%residual)), &
         '|BAL_FLAGS=',count(shadow_workspace64%richards%nonconverged_balance), &
         '|HEAD_FLAGS=',count(shadow_workspace64%richards%nonconverged_head)

"""
    block = replace_once(block, anchor, diagnostic + anchor, "diagnostic insertion")

    text = text[:i] + block + text[j:]
    args.output.write_text(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
