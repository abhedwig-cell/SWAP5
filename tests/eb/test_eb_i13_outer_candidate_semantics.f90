module mod_eb_i13_outer_fixture
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t, transaction_attempt_context_t, trial_outcome_t, &
       TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_physical_model_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_fmr_bottom_thermal_carrier, only: fmr_bottom_thermal_carrier_t
  implicit none
  private

  type, extends(transaction_state_t), public :: outer_state_t
    real(real64) :: storage_value = 1.0_real64
  contains
    procedure :: clone => outer_state_clone
  end type outer_state_t

  type, extends(canonical_forcing_t), public :: outer_forcing_t
  end type outer_forcing_t

  type, extends(transaction_attempt_context_t) :: outer_context_t
    type(fmr_bottom_thermal_carrier_t) :: carrier
  end type outer_context_t

  type, extends(canonical_physical_model_t), public :: outer_model_t
    type(fmr_bottom_thermal_carrier_t) :: carrier
  contains
    procedure :: advance => outer_advance
    procedure :: storage => outer_storage
    procedure :: temporal_error => outer_temporal_error
    procedure :: storage_accounting_status => outer_storage_status
    procedure :: capture_attempt_context => outer_capture
    procedure :: restore_attempt_context => outer_restore
    procedure :: prepare_interval => outer_prepare_interval
  end type outer_model_t

contains

  subroutine outer_state_clone(self, copy)
    class(outer_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy

    allocate(outer_state_t :: copy)
    select type (typed => copy)
    type is (outer_state_t)
      typed%storage_value = self%storage_value
    end select
  end subroutine outer_state_clone

  subroutine outer_capture(self, context)
    class(outer_model_t), intent(inout) :: self
    class(transaction_attempt_context_t), allocatable, intent(out) :: context

    allocate(outer_context_t :: context)
    select type (typed => context)
    type is (outer_context_t)
      call self%carrier%copy_to(typed%carrier)
    class default
      error stop 'EB-I13 outer fixture context allocation mismatch'
    end select
  end subroutine outer_capture

  subroutine outer_restore(self, context)
    class(outer_model_t), intent(inout) :: self
    class(transaction_attempt_context_t), intent(in) :: context

    select type (typed => context)
    type is (outer_context_t)
      call self%carrier%restore_from(typed%carrier)
    class default
      call self%carrier%clear()
    end select
  end subroutine outer_restore

  subroutine outer_prepare_interval(self, forcing, interval, config)
    class(outer_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config

    if (.not. same_type_as(self, self) .or. .not. same_type_as(forcing, forcing)) then
      error stop 'unreachable EB-I13 outer prepare types'
    end if
    if (interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) then
      error stop 'EB-I13 outer fixture received invalid interval/config'
    end if
  end subroutine outer_prepare_interval

  subroutine outer_advance(self, state, t0, t1, outcome)
    class(outer_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    logical :: appended
    real(real64) :: dt

    outcome = trial_outcome_t()
    dt = t1 - t0
    if (dt <= 0.0_real64) return
    select type (typed => state)
    type is (outer_state_t)
      if (typed%storage_value < 0.0_real64) return
    class default
      return
    end select

    ! Append before the deliberate rejection. The transaction core must restore
    ! the exact checkpoint context before retrying, otherwise rejected-route
    ! provenance would leak into the accepted carrier.
    call self%carrier%append_local(t0, t1, dt, 10.0_real64+t0, 10.0_real64+t1, appended)
    if (.not. appended) return
    outcome%headcalc_calls = 1

    ! Force a reduced accepted first transaction for an outer [0,1] interval.
    ! A requested transaction longer than 0.5 is rejected; retry at 0.5 and
    ! subsequent 0.5 transactions are accepted through the two-half route.
    if (dt > 0.5_real64) return

    outcome%solver_ok = .true.
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
  end subroutine outer_advance

  real(real64) function outer_storage(self, state) result(value)
    class(outer_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state

    if (self%carrier%sample_count() < -huge(0)) error stop 'unreachable EB-I13 outer carrier count'
    select type (typed => state)
    type is (outer_state_t)
      value = typed%storage_value
    class default
      value = huge(0.0_real64)
    end select
  end function outer_storage

  real(real64) function outer_temporal_error(self, full_state, half_state) result(value)
    class(outer_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state

    if (.not. same_type_as(self, self) .or. .not. same_type_as(full_state, full_state) .or. &
        .not. same_type_as(half_state, half_state)) error stop 'unreachable EB-I13 outer temporal types'
    value = 0.0_real64
  end function outer_temporal_error

  subroutine outer_storage_status(self, state, complete, missing_mask)
    class(outer_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask

    if (.not. same_type_as(self, self) .or. .not. same_type_as(state, state)) then
      error stop 'unreachable EB-I13 outer storage types'
    end if
    complete = .true.
    missing_mask = TX_MASS_MISSING_NONE
  end subroutine outer_storage_status

end module mod_eb_i13_outer_fixture

program test_eb_i13_outer_candidate_semantics
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_interval_t, canonical_numerical_config_t, canonical_result_t, &
       CANONICAL_STATUS_COMPLETED, CANONICAL_STATUS_SUBSTEP_LIMIT
  use mod_canonical_interval_runtime, only: run_canonical_interval
  use mod_fmr_bottom_thermal_carrier, only: fmr_bottom_thermal_candidate_t, fmr_bottom_thermal_sample_t
  use mod_eb_i13_outer_fixture, only: outer_state_t, outer_forcing_t, outer_model_t
  implicit none

  real(real64), parameter :: tol = 1.0e-12_real64

  call verify_completed_multi_substep_sequence()
  call verify_partial_outer_failure_nonpublication()
  write(*,'(A)') 'EB_I13_OUTER_CANDIDATE_SEMANTICS_GATE PASS'

contains

  subroutine configure(config, max_substeps)
    type(canonical_numerical_config_t), intent(out) :: config
    integer, intent(in) :: max_substeps

    config = canonical_numerical_config_t()
    config%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    config%transaction%temporal_tolerance = 1.0_real64
    config%transaction%mass_tolerance = 1.0e-12_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 2
    config%max_committed_substeps = max_substeps
    config%progress_tolerance = 0.0_real64
  end subroutine configure

  subroutine verify_completed_multi_substep_sequence()
    class(transaction_state_t), allocatable :: committed
    type(outer_model_t) :: model
    type(outer_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result
    type(fmr_bottom_thermal_candidate_t) :: candidate
    type(fmr_bottom_thermal_sample_t) :: sample
    real(real64), parameter :: expected_t0(4) = [0.0_real64, 0.25_real64, 0.50_real64, 0.75_real64]
    real(real64), parameter :: expected_t1(4) = [0.25_real64, 0.50_real64, 0.75_real64, 1.00_real64]
    logical :: ok, available
    integer :: i

    allocate(outer_state_t :: committed)
    call model%carrier%initialize(8, ok)
    call require(ok, 'multi-substep carrier initialization')
    interval%t0 = 0.0_real64
    interval%t1 = 1.0_real64
    call configure(config, 2)

    call run_canonical_interval(model, committed, forcing, interval, config, result)

    call require(result%status == CANONICAL_STATUS_COMPLETED .and. result%completed, &
         'multi-substep outer interval completed')
    call require(result%mass%accepted_transaction_count == 2, 'exactly two internal transactions accepted')
    call require(result%diagnostics%committed_substeps == 2, 'exactly two canonical substeps committed internally')
    call require(model%carrier%sample_count() == 4, 'only four selected half-route samples retained')

    call model%carrier%materialize_candidate(0.0_real64, 1.0_real64, candidate, ok)
    call require(ok .and. candidate%ready() .and. candidate%sample_count() == 4, &
         'full outer candidate materialized from accepted sequence')
    do i = 1, 4
      call candidate%sample_at(i, sample, available)
      call require(available, 'multi-substep sample available')
      call require(abs(sample%t0-expected_t0(i)) <= tol .and. abs(sample%t1-expected_t1(i)) <= tol, &
           'multi-substep accepted sequence ordered exactly')
      call require(abs(sample%bottom_outward_exchange_native-0.25_real64) <= tol, &
           'multi-substep sample transfer belongs to selected half route')
    end do

    write(*,'(A)') 'EB_I13_MULTI_SUBSTEP_ORDERED_SEQUENCE=PASS'
  end subroutine verify_completed_multi_substep_sequence

  subroutine verify_partial_outer_failure_nonpublication()
    class(transaction_state_t), allocatable :: committed
    type(outer_model_t) :: model
    type(outer_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result
    type(fmr_bottom_thermal_candidate_t) :: full_candidate, prefix_candidate
    logical :: ok

    allocate(outer_state_t :: committed)
    call model%carrier%initialize(8, ok)
    call require(ok, 'partial-failure carrier initialization')
    interval%t0 = 0.0_real64
    interval%t1 = 1.0_real64
    call configure(config, 1)

    call run_canonical_interval(model, committed, forcing, interval, config, result)

    call require(result%status == CANONICAL_STATUS_SUBSTEP_LIMIT .and. .not. result%completed, &
         'outer interval fails after accepted internal transaction')
    call require(abs(result%completed_t-0.5_real64) <= tol, 'failure occurs after accepted prefix')
    call require(result%mass%accepted_transaction_count == 1, 'one internal transaction accepted before outer failure')
    call require(model%carrier%sample_count() == 2, 'accepted prefix samples exist internally')

    call model%carrier%materialize_candidate(0.0_real64, 0.5_real64, prefix_candidate, ok)
    call require(ok .and. prefix_candidate%ready() .and. prefix_candidate%sample_count() == 2, &
         'accepted prefix provenance exists')
    call model%carrier%materialize_candidate(0.0_real64, 1.0_real64, full_candidate, ok)
    call require(.not. ok .and. .not. full_candidate%ready(), &
         'failed outer interval cannot materialize requested-interval carrier')
    call require(abs(model%storage(committed)-1.0_real64) <= tol, &
         'externally committed physical state unchanged on outer failure')

    write(*,'(A)') 'EB_I13_PARTIAL_OUTER_FAILURE_NONPUBLIC=PASS'
  end subroutine verify_partial_outer_failure_nonpublication

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label

    if (.not. condition) then
      write(*,'(A,1X,A)') 'EB_I13_OUTER_TEST_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_eb_i13_outer_candidate_semantics
