#!/usr/bin/env python3
from pathlib import Path

SRC = Path('tests/fmr/test_fmr06_snow_multiswap.f90')
OUT = Path(__import__('sys').argv[1])
text = SRC.read_text()

assert_anchor = "      call require(results(j)%solver_executed, trim(label)//':real solver executed')\n"
assert_insert = assert_anchor + """      call require(results(j)%accepted_substeps > 0, trim(label)//':accepted substeps diagnostic')
      call require(results(j)%solver_nonlinear_iterations >= 0, trim(label)//':nonlinear diagnostic nonnegative')
      call require(results(j)%solver_internal_retries >= 0, trim(label)//':internal retry diagnostic nonnegative')
      call require(results(j)%solver_headcalc_calls >= 3*results(j)%accepted_substeps, &
           trim(label)//':headcalc diagnostic covers full plus two-half trials')
      call require(results(j)%solver_jacobian_builds >= 0, trim(label)//':jacobian diagnostic nonnegative')
      call require(results(j)%solver_linear_solves >= 0, trim(label)//':linear-solve diagnostic nonnegative')
      call require(results(j)%solver_backtracking_attempts >= 0, trim(label)//':backtracking diagnostic nonnegative')
      call require(results(j)%solver_alternative_solver_calls >= 0, trim(label)//':alternative-solver diagnostic nonnegative')
      write(*,'(A,1X,A,1X,I0,8(1X,I0))') 'FPE05_COST', trim(label), results(j)%column_id, &
           results(j)%accepted_substeps, results(j)%solver_nonlinear_iterations, &
           results(j)%solver_internal_retries, results(j)%solver_headcalc_calls, &
           results(j)%solver_jacobian_builds, results(j)%solver_linear_solves, &
           results(j)%solver_backtracking_attempts, results(j)%solver_alternative_solver_calls
"""
if text.count(assert_anchor) != 1:
    raise SystemExit(f'expected exactly one run-matrix assertion anchor, got {text.count(assert_anchor)}')
text = text.replace(assert_anchor, assert_insert, 1)

identity_anchor = "         trim(a%solver_route)==trim(b%solver_route) .and. a%final_revision==b%final_revision .and. &\n"
identity_insert = """         trim(a%solver_route)==trim(b%solver_route) .and. &
         a%accepted_substeps==b%accepted_substeps .and. &
         a%solver_nonlinear_iterations==b%solver_nonlinear_iterations .and. &
         a%solver_internal_retries==b%solver_internal_retries .and. &
         a%solver_headcalc_calls==b%solver_headcalc_calls .and. &
         a%solver_jacobian_builds==b%solver_jacobian_builds .and. &
         a%solver_linear_solves==b%solver_linear_solves .and. &
         a%solver_backtracking_attempts==b%solver_backtracking_attempts .and. &
         a%solver_alternative_solver_calls==b%solver_alternative_solver_calls .and. &
         a%final_revision==b%final_revision .and. &
"""
if text.count(identity_anchor) != 1:
    raise SystemExit(f'expected exactly one identity anchor, got {text.count(identity_anchor)}')
text = text.replace(identity_anchor, identity_insert, 1)

marker_anchor = "  write(*,'(A)') 'FMR06_SNOW_MULTISWAP_TEST PASS'\n"
marker_insert = marker_anchor + "  write(*,'(A)') 'FPE05_COST_DIAGNOSTICS_PROBE=PASS'\n"
if text.count(marker_anchor) != 1:
    raise SystemExit(f'expected exactly one final marker anchor, got {text.count(marker_anchor)}')
text = text.replace(marker_anchor, marker_insert, 1)

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(text)
print(f'FPE05_PROBE_GENERATED={OUT}')
print('FPE05_IMMUTABLE_FMR06_FIXTURE_TRANSFORM=PASS')
