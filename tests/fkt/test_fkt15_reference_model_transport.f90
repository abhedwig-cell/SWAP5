program test_fkt15_reference_model_transport
  use, intrinsic :: iso_fortran_env, only: real64, error_unit
  use mod_transaction_reference, only: trial_outcome_t
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_initialize_worker
  use mod_b1_10_process_checkpoint, only: b1_10_process_state_t
  use mod_b1_10_physical_interval_executor, only: fkt15_stub_mode
  use mod_b1_10_reference_model, only: b1_10_reference_model_t
  implicit none
  type(a23bu_worker_context_t), target :: worker
  type(b1_10_reference_model_t) :: model
  type(b1_10_process_state_t) :: state
  type(trial_outcome_t) :: outcome

  call a23bu_initialize_worker(worker, 4, 15)
  call model%bind_worker(worker)
  allocate(state%h(4), source=0.0_real64)

  fkt15_stub_mode = 1
  call model%advance(state, 3.0_real64, 4.0_real64, outcome)
  call require(outcome%solver_ok, 'accepted physical interval solver_ok')
  call require(outcome%interface_sensitivity%available, 'accepted sensitivity transported')
  call require(outcome%interface_sensitivity%dh_bottom_dq_bottom == 12.5_real64, 'accepted tangent value')
  call require(trim(outcome%interface_sensitivity%method) == 'same-tridag-factor', 'accepted tangent method')
  write(*,'(A)') 'FKT15_REFERENCE_ACCEPTED_FKT14_TRANSPORT=PASS'

  fkt15_stub_mode = 2
  call model%advance(state, 4.0_real64, 5.0_real64, outcome)
  call require(.not. outcome%solver_ok, 'rejected physical interval solver flag')
  call require(.not. outcome%interface_sensitivity%available, 'rejected stale sensitivity excluded')
  write(*,'(A)') 'FKT15_REFERENCE_REJECTED_STALE_EXCLUSION=PASS'

  fkt15_stub_mode = 3
  call model%advance(state, 5.0_real64, 6.0_real64, outcome)
  call require(outcome%solver_ok, 'direct fallback interval accepted')
  call require(.not. outcome%interface_sensitivity%available, 'direct fallback has no typed sensitivity')
  write(*,'(A)') 'FKT15_REFERENCE_DIRECT_FALLBACK_NO_SENSITIVITY=PASS'
  write(*,'(A)') 'FKT15_REFERENCE_MODEL_TRANSPORT_GATE=PASS'
contains
  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(error_unit,'(A,1X,A)') 'FKT15_REFERENCE_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fkt15_reference_model_transport
