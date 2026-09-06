program test_a23bn_hupsel_native_adapter
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference
  use mod_a23bn_hupsel_native_adapter
  implicit none
  type(hupsel_native_model_t) :: model
  class(transaction_state_t), allocatable :: committed, checkpoint, reference_endpoint
  type(transaction_policy_t) :: policy
  type(transaction_result_t) :: result
  real(real64) :: ref_storage, retry_storage

  call initialize_hupsel_native(model, committed, 'swap.swp', 'a23bn_native', 37256.0_real64, 37258.0_real64, 37259.0_real64)
  call committed%clone(checkpoint)

  policy%temporal_tolerance = 1.0e-12_real64
  policy%mass_tolerance = 1.0e-6_real64
  policy%retry_scale = 0.5_real64
  policy%max_retries = 0
  call execute_reference_interval(model, committed, 0.0_real64, 2.0_real64, policy, result)
  call require(result%status == TX_STATUS_ACCEPTED, 'reference interval not accepted')
  call require(result%commits == 1 .and. result%rollbacks == 0, 'unexpected commit/rollback counts')
  call require(result%full_trials == 1 .and. result%half_trials == 2, 'always-sampled route missing')
  call require(result%temporal_error <= 1.0e-14_real64, 'full/two-half state mismatch')
  call require(abs(result%full_mass_residual) <= 1.0e-6_real64, 'full mass gate failed')
  call require(abs(result%half_mass_residual) <= 1.0e-6_real64, 'half mass gate failed')
  ref_storage = model%storage(committed)
  call require(abs(ref_storage - 77.01171_real64) < 1.0e-5_real64, 'unexpected B1.6 endpoint storage')
  call committed%clone(reference_endpoint)

  deallocate(committed)
  call checkpoint%clone(committed)
  model%fail_next_advance = .true.
  policy%max_retries = 1
  call execute_reference_interval(model, committed, 0.0_real64, 4.0_real64, policy, result)
  call require(result%status == TX_STATUS_ACCEPTED, 'retry interval not accepted')
  call require(result%retries == 1 .and. result%rollbacks == 1, 'retry/rollback count mismatch')
  call require(result%solver_rejections == 1, 'injected trial did not reject as solver failure')
  call require(abs(result%accepted_t1 - 2.0_real64) < 1.0e-14_real64, 'retry did not accept reduced two-day interval')
  retry_storage = model%storage(committed)
  call require(abs(retry_storage-ref_storage) < 1.0e-13_real64, 'retry endpoint storage mismatch')
  call require(states_equal(committed, reference_endpoint), 'rejected trial contaminated physical state')

  print '(A)', 'A23BN_NATIVE_PHYSICAL_GATE PASS'
  print '(A,ES24.16)', 'reference_storage=', ref_storage
  print '(A,ES24.16)', 'retry_storage=', retry_storage
  print '(A,ES24.16)', 'mass_residual=', result%half_mass_residual
  print '(A,I0)', 'newton_iterations=', result%nonlinear_iterations
  call finalize_hupsel_native()
contains
  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(A)') 'FAIL: '//trim(message)
      error stop 1
    end if
  end subroutine require

  logical function states_equal(a,b)
    class(transaction_state_t), intent(in) :: a,b
    states_equal=.false.
    select type(x=>a)
    type is(hupsel_native_state_t)
      select type(y=>b)
      type is(hupsel_native_state_t)
        states_equal = maxval(abs(x%h-y%h)) <= tiny(0.0_real64) .and. &
          maxval(abs(x%theta-y%theta)) <= tiny(0.0_real64) .and. &
          maxval(abs(x%tsoil-y%tsoil)) <= tiny(0.0_real64) .and. &
          maxval(abs(x%cml-y%cml)) <= tiny(0.0_real64) .and. abs(x%pond-y%pond) <= tiny(0.0_real64) .and. abs(x%gwl-y%gwl) <= tiny(0.0_real64)
      end select
    end select
  end function states_equal
end program
