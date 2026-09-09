module mod_fkt13_process_support
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t, canonical_mass_accounting_t, &
       CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions
  use mod_fkt05_test_model, only: fkt05_state_t, fkt05_parameters_t, fkt05_forcing_t
  implicit none
  private

  real(real64), parameter, public :: FKT13_T0 = 20.0_real64
  real(real64), parameter, public :: FKT13_T1 = 20.5_real64
  real(real64), parameter, public :: FKT13_T2 = 21.0_real64
  integer(int64), parameter, public :: FKT13_LINEAGE_ID = 130013_int64
  integer(int64), parameter, public :: FKT13_LAYOUT_ID = 13001_int64

  public :: fkt13_new_physical
  public :: fkt13_new_initial_committed
  public :: fkt13_setup
  public :: fkt13_committed_water
  public :: fkt13_committed_time
  public :: fkt13_advance_and_commit
  public :: fkt13_print_endpoint

contains

  subroutine fkt13_new_physical(state, water)
    class(transaction_state_t), allocatable, intent(out) :: state
    real(real64), intent(in) :: water

    allocate(fkt05_state_t :: state)
    select type (state)
    type is (fkt05_state_t)
      state%water = water
    class default
      error stop 'FKT13 unexpected physical allocation type'
    end select
  end subroutine fkt13_new_physical

  subroutine fkt13_new_initial_committed(committed)
    type(kernel_committed_state_t), intent(out) :: committed
    class(transaction_state_t), allocatable :: state
    logical :: initialized

    call fkt13_new_physical(state, 1.0_real64)
    call committed%initialize(FKT13_LINEAGE_ID, state, initialized, FKT13_T0)
    if (.not. initialized) error stop 'FKT13 initial committed state construction failed'
  end subroutine fkt13_new_initial_committed

  subroutine fkt13_setup(parameters, forcing, config)
    type(fkt05_parameters_t), intent(out) :: parameters
    type(fkt05_forcing_t), intent(out) :: forcing
    type(canonical_numerical_config_t), intent(out) :: config

    parameters%rate = 0.1_real64
    forcing%scale = 1.0_real64
    config%transaction%temporal_tolerance = 1.0_real64
    config%transaction%mass_tolerance = 1.0e-12_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 1
    config%max_committed_substeps = 8
    config%progress_tolerance = 0.0_real64
  end subroutine fkt13_setup

  real(real64) function fkt13_committed_water(committed) result(value)
    type(kernel_committed_state_t), intent(in) :: committed
    class(transaction_state_t), allocatable :: state
    logical :: available

    call committed%snapshot(state, available)
    if (.not. available) error stop 'FKT13 committed physical snapshot unavailable'
    select type (state)
    type is (fkt05_state_t)
      value = state%water
    class default
      error stop 'FKT13 committed physical type mismatch'
    end select
  end function fkt13_committed_water

  real(real64) function fkt13_committed_time(committed) result(value)
    type(kernel_committed_state_t), intent(in) :: committed
    logical :: available

    call committed%current_time(value, available)
    if (.not. available) error stop 'FKT13 committed time unavailable'
  end function fkt13_committed_time

  subroutine fkt13_advance_and_commit(kernel, committed, parameters, forcing, config, t0, t1, mass)
    type(kernel_executor_t), intent(inout) :: kernel
    type(kernel_committed_state_t), intent(inout) :: committed
    type(fkt05_parameters_t), intent(in) :: parameters
    type(fkt05_forcing_t), intent(in) :: forcing
    type(canonical_numerical_config_t), intent(in) :: config
    real(real64), intent(in) :: t0, t1
    type(canonical_mass_accounting_t), intent(out) :: mass
    type(kernel_candidate_state_t) :: candidate
    type(kernel_result_t) :: result
    type(kernel_diagnostics_t) :: diagnostics
    logical :: committed_ok
    integer :: commit_status

    call kernel%advance_interval(parameters, committed, forcing, config, t0, t1, result, candidate, diagnostics)
    if (result%status /= CANONICAL_STATUS_COMPLETED) error stop 'FKT13 interval did not complete'
    if (.not. candidate%ready()) error stop 'FKT13 candidate not ready'
    call kernel%commit_candidate(committed, candidate, diagnostics, committed_ok, commit_status, mass)
    if (.not. committed_ok) error stop 'FKT13 candidate commit failed'
    if (commit_status /= KERNEL_COMMIT_STATUS_COMMITTED) error stop 'FKT13 unexpected commit status'
    if (.not. mass%complete) error stop 'FKT13 accepted interval mass ledger incomplete'
  end subroutine fkt13_advance_and_commit

  subroutine fkt13_print_endpoint(committed, mass)
    type(kernel_committed_state_t), intent(in) :: committed
    type(canonical_mass_accounting_t), intent(in) :: mass
    real(real64) :: water, time_value
    integer(int64) :: water_bits, time_bits, residual_bits, storage_start_bits, storage_end_bits

    water = fkt13_committed_water(committed)
    time_value = fkt13_committed_time(committed)
    water_bits = transfer(water, 0_int64)
    time_bits = transfer(time_value, 0_int64)
    residual_bits = transfer(mass%residual, 0_int64)
    storage_start_bits = transfer(mass%storage_start, 0_int64)
    storage_end_bits = transfer(mass%storage_end, 0_int64)
    write(*,'(A,I0,A,I0,A,I0,A,I0,A,I0,A,I0,A,I0,A,I0)') &
         'FKT13_ENDPOINT water_bits=', water_bits, ' lineage=', committed%current_lineage_id(), &
         ' revision=', committed%current_revision(), ' time_bits=', time_bits, &
         ' mass_complete=', merge(1, 0, mass%complete), ' residual_bits=', residual_bits, &
         ' storage_start_bits=', storage_start_bits, ' storage_end_bits=', storage_end_bits
  end subroutine fkt13_print_endpoint

end module mod_fkt13_process_support
