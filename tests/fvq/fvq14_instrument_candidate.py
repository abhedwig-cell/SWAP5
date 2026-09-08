#!/usr/bin/env python3
"""Create a qualification-only instrumented copy of the exact F-MR04 test driver.

The production candidate tree is never modified. This script requires the exact
known test-driver blob and injects read-only dumps plus additional F-VQ14
fail-closed checks into a temporary qualification driver.
"""
from pathlib import Path
import subprocess
import sys

EXPECTED_BLOB = "11981391d0a504a66473c0281bf51defa6d1eac8"

if len(sys.argv) != 3:
    raise SystemExit("usage: fvq14_instrument_candidate.py <candidate-root> <output.F90>")
root = Path(sys.argv[1]).resolve()
out = Path(sys.argv[2]).resolve()
src = root / "tests/fmr/test_fmr04_serialized_physical.F90"
blob = subprocess.check_output(["git", "-C", str(root), "hash-object", str(src)], text=True).strip()
if blob != EXPECTED_BLOB:
    raise SystemExit(f"F-VQ14 fail closed: F-MR04 driver blob mismatch expected={EXPECTED_BLOB} actual={blob}")
text = src.read_text()

needle = "  endpoint_storage = candidate_storage(candidate, parameters%dz)\n"
insert = needle + "  call fvq14_dump_candidate(candidate, observation, result, diagnostics, forcing, endpoint_storage)\n"
if text.count(needle) != 1:
    raise SystemExit("F-VQ14 fail closed: candidate instrumentation anchor not unique")
text = text.replace(needle, insert, 1)

unsupported_anchor = "  bad_parameters%swkimpl = 1\n  call expect_not_admitted('swkimpl1', bad_parameters)\n"
unsupported_insert = unsupported_anchor + "  bad_parameters = parameters\n  bad_parameters%bottom_mode = 1\n  call expect_not_admitted('unqualified-bottom-mode', bad_parameters)\n"
if text.count(unsupported_anchor) != 1:
    raise SystemExit("F-VQ14 fail closed: unsupported-scope anchor not unique")
text = text.replace(unsupported_anchor, unsupported_insert, 1)

qrot_anchor = "  call require(committed_fingerprint(committed) == committed_fp0, 'qrot rejection leaves committed state unchanged')\n"
qrot_insert = qrot_anchor + "  write(*,'(A)') 'VQ14_CAND_QROT_FAIL_CLOSED=PASS'\n"
if text.count(qrot_anchor) != 1:
    raise SystemExit("F-VQ14 fail closed: qrot anchor not unique")
text = text.replace(qrot_anchor, qrot_insert, 1)

stale_anchor = "  call require(rejected_diagnostics%checkpoint_revision_rejections == 1, 'stale revision diagnosed')\n"
stale_insert = stale_anchor + "  write(*,'(A)') 'VQ14_CAND_STALE_CHECKPOINT=PASS'\n"
if text.count(stale_anchor) != 1:
    raise SystemExit("F-VQ14 fail closed: stale-checkpoint anchor not unique")
text = text.replace(stale_anchor, stale_insert, 1)

anchor = "  subroutine configure_fixture(column, template, parameters, forcing, state, storage0)\n"
helper = r'''  subroutine fvq14_dump_candidate(state, obs, kres, kdiag, f, endpoint_store)
    type(kernel_candidate_state_t), intent(in) :: state
    type(fmr_serialized_physical_observation_t), intent(in) :: obs
    type(kernel_result_t), intent(in) :: kres
    type(kernel_diagnostics_t), intent(in) :: kdiag
    type(fmr_b110_physical_forcing_t), intent(in) :: f
    real(real64), intent(in) :: endpoint_store
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    integer :: i, level

    call state%snapshot(snapshot, got)
    call require(got, 'F-VQ14 candidate dump snapshot')
    select type (physical => snapshot)
    type is (fmr_b110_physical_state_t)
      write(*,'(A,I0)') 'VQ14_CAND_ACTIVE_NODES=', physical%active_nodes
      do i = 1, physical%active_nodes
        write(*,'(A,I0,A,I0)') 'VQ14_CAND_HEAD_BITS_', i, '=', transfer(physical%pressure_head(i),0_int64)
        write(*,'(A,I0,A,I0)') 'VQ14_CAND_THETA_BITS_', i, '=', transfer(physical%water_content(i),0_int64)
      end do
      write(*,'(A,I0)') 'VQ14_CAND_POND_BITS=', transfer(physical%ponding_depth,0_int64)
      write(*,'(A,I0)') 'VQ14_CAND_GWL_BITS=', transfer(physical%groundwater_level,0_int64)
    class default
      error stop 'F-VQ14 unexpected candidate state type'
    end select
    write(*,'(A,I0)') 'VQ14_CAND_TOP_FLUX_BITS=', transfer(obs%top_flux,0_int64)
    write(*,'(A,I0)') 'VQ14_CAND_BOTTOM_FLUX_BITS=', transfer(obs%bottom_flux,0_int64)
    write(*,'(A,I0)') 'VQ14_CAND_ENDPOINT_STORAGE_BITS=', transfer(endpoint_store,0_int64)
    write(*,'(A,I0)') 'VQ14_CAND_SOLVER_STATUS=', obs%solver_status
    write(*,'(A,A)') 'VQ14_CAND_SOLVER_ROUTE=', trim(obs%solver_diagnostics%route)
    write(*,'(A,I0)') 'VQ14_CAND_NONLINEAR_ITERATIONS=', obs%solver_diagnostics%nonlinear_iterations
    write(*,'(A,I0)') 'VQ14_CAND_JACOBIAN_BUILDS=', obs%solver_diagnostics%jacobian_builds
    write(*,'(A,I0)') 'VQ14_CAND_LINEAR_SOLVES=', obs%solver_diagnostics%linear_solves
    write(*,'(A,I0)') 'VQ14_CAND_BACKTRACKING_ATTEMPTS=', obs%solver_diagnostics%backtracking_attempts
    write(*,'(A,I0)') 'VQ14_CAND_INTERNAL_RETRIES=', obs%solver_diagnostics%internal_retries
    write(*,'(A,I0)') 'VQ14_CAND_ALT_SOLVER_CALLS=', obs%solver_diagnostics%alternative_solver_calls
    write(*,'(A,I0)') 'VQ14_CAND_MASS_COMPLETE=', merge(1,0,kres%mass%complete)
    write(*,'(A,I0)') 'VQ14_CAND_MISSING_MASK=', kres%mass%missing_contribution_mask
    write(*,'(A,I0)') 'VQ14_CAND_STORAGE_START_BITS=', transfer(kres%mass%storage_start,0_int64)
    write(*,'(A,I0)') 'VQ14_CAND_STORAGE_END_BITS=', transfer(kres%mass%storage_end,0_int64)
    write(*,'(A,I0)') 'VQ14_CAND_TOTAL_IN_BITS=', transfer(kres%mass%total_in,0_int64)
    write(*,'(A,I0)') 'VQ14_CAND_TOTAL_OUT_BITS=', transfer(kres%mass%total_out,0_int64)
    write(*,'(A,I0)') 'VQ14_CAND_RESIDUAL_BITS=', transfer(kres%mass%residual,0_int64)
    write(*,'(A,I0)') 'VQ14_CAND_ACCEPTED_TRANSACTIONS=', kres%mass%accepted_transaction_count
    write(*,'(A,I0)') 'VQ14_CAND_MASS_REJECTIONS=', kdiag%mass_rejections
    do i = 1, size(f%subsurface_irrigation_source)
      write(*,'(A,I0,A,I0)') 'VQ14_CAND_QSSDI_BITS_', i, '=', transfer(f%subsurface_irrigation_source(i),0_int64)
      write(*,'(A,I0,A,I0)') 'VQ14_CAND_QROT_BITS_', i, '=', transfer(f%root_extraction_sink(i),0_int64)
    end do
    do level = 1, size(f%drainage_flux_by_level,1)
      do i = 1, size(f%drainage_flux_by_level,2)
        write(*,'(A,I0,A,I0,A,I0)') 'VQ14_CAND_QDRA_BITS_', level, '_', i, '=', &
             transfer(f%drainage_flux_by_level(level,i),0_int64)
      end do
    end do
    write(*,'(A,F0.12)') 'VQ14_CAND_T0=', t0
    write(*,'(A,F0.12)') 'VQ14_CAND_T1=', t1
  end subroutine fvq14_dump_candidate

'''
if text.count(anchor) != 1:
    raise SystemExit("F-VQ14 fail closed: helper insertion anchor not unique")
text = text.replace(anchor, helper + anchor, 1)
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(text)
print(f"F-VQ14 instrumented exact driver blob={blob} output={out}")
