from pathlib import Path
p = Path('tests/eb/test_eb_i26_outer_substep_sensible_boundary_aggregation.f90')
s = p.read_text()
old = "    call require(output%completed .and. output%committed, 'second outer transaction committed')\n"
new = """    if (.not. output%completed .or. .not. output%committed) then
      write(*,'(A,1X,L1,1X,L1,1X,I0,1X,I0,1X,A,1X,A,1X,I0,1X,I0,1X,I0,1X,I0,1X,I0,1X,L1,1X,ES24.16E3)') &
           'EB_I26_SECOND_OUTER_DIAG', output%completed, output%committed, output%kernel_status, output%commit_status, &
           trim(output%admission_status), trim(diagnostic%failure_classification), output%accepted_substeps, &
           diagnostic%attempts, diagnostic%retries, int(output%initial_revision), int(output%final_revision), &
           output%mass%complete, output%mass%residual
    end if
    call require(output%completed .and. output%committed, 'second outer transaction committed')
"""
if s.count(old) != 1:
    raise SystemExit(f'expected one second-outer require, found {s.count(old)}')
p.write_text(s.replace(old, new, 1))
print('EB_I26_SECOND_OUTER_DIAG_PATCH=READY')
