module mod_rossfast_d3r_model_adapter
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_physical_model_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t, canonical_result_t
  use mod_canonical_interval_runtime, only: run_canonical_interval
  implicit none
  private

  real(real64), parameter, public :: ROSSFAST_D3R_INITIAL_DURATION_DAY = 0.0016_real64
  real(real64), parameter, public :: ROSSFAST_D3R_RETRY_SCALE = 0.5_real64
  integer, parameter, public :: ROSSFAST_D3R_MAX_RETRIES = 8
  integer, parameter, public :: ROSSFAST_D3R_LADDER_COUNT = ROSSFAST_D3R_MAX_RETRIES + 2
  real(real64), parameter, public :: ROSSFAST_D3R_ENDPOINT_ULP_MULTIPLIER = 2.0_real64

  ! Production-facing adapter for the restricted F-ROSS01 D3R duration
  ! semantics. It owns only RossFast-specific transaction-window selection.
  ! Physical advance/storage semantics remain deferred to a concrete RossFast
  ! model, while the canonical runtime retains validation, private working-state
  ! ownership, accepted-only commit and single external publication.
  type, abstract, extends(canonical_physical_model_t), public :: rossfast_d3r_model_adapter_t
  contains
    procedure :: select_transaction_window => rossfast_d3r_select_transaction_window
  end type rossfast_d3r_model_adapter_t

  public :: apply_rossfast_d3r_retry_policy
  public :: rossfast_d3r_duration_for_index
  public :: run_rossfast_d3r_interval

contains

  pure function rossfast_d3r_duration_for_index(index) result(duration)
    integer, intent(in) :: index
    real(real64) :: duration

    if (index < 0 .or. index >= ROSSFAST_D3R_LADDER_COUNT) then
      duration = 0.0_real64
    else
      duration = ROSSFAST_D3R_INITIAL_DURATION_DAY * ROSSFAST_D3R_RETRY_SCALE**index
    end if
  end function rossfast_d3r_duration_for_index

  subroutine apply_rossfast_d3r_retry_policy(config)
    type(canonical_numerical_config_t), intent(inout) :: config

    config%transaction%retry_scale = ROSSFAST_D3R_RETRY_SCALE
    config%transaction%max_retries = ROSSFAST_D3R_MAX_RETRIES
  end subroutine apply_rossfast_d3r_retry_policy

  subroutine run_rossfast_d3r_interval(model, committed, forcing, interval, config, result)
    class(rossfast_d3r_model_adapter_t), intent(inout) :: model
    class(transaction_state_t), allocatable, intent(inout) :: committed
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    type(canonical_result_t), intent(out) :: result

    call run_canonical_interval(model, committed, forcing, interval, config, result, select_window)

  contains

    subroutine select_window(cursor, requested_t1, target_t1, max_retries_cap, valid)
      real(real64), intent(in) :: cursor, requested_t1
      real(real64), intent(out) :: target_t1
      integer, intent(out) :: max_retries_cap
      logical, intent(out) :: valid

      call model%select_transaction_window(cursor, requested_t1, target_t1)
      max_retries_cap = min(config%transaction%max_retries, ROSSFAST_D3R_MAX_RETRIES)
      valid = target_t1 > cursor .and. target_t1 <= requested_t1
    end subroutine select_window

  end subroutine run_rossfast_d3r_interval

  subroutine rossfast_d3r_select_transaction_window(self, cursor, outer_t1, selected_t1)
    class(rossfast_d3r_model_adapter_t), intent(inout) :: self
    real(real64), intent(in) :: cursor, outer_t1
    real(real64), intent(out) :: selected_t1
    real(real64) :: duration, expected_t1, tolerance
    integer :: index

    ! Select only durations admitted by D3R. An outer remainder smaller than
    ! the minimum admitted duration and not equal to a ladder endpoint is
    ! represented as no selection. The canonical selector contract then fails
    ! closed as INVALID_REQUEST before any physical transaction is executed.
    selected_t1 = cursor
    if (outer_t1 <= cursor) return

    do index = 0, ROSSFAST_D3R_LADDER_COUNT - 1
      duration = rossfast_d3r_duration_for_index(index)
      expected_t1 = cursor + duration
      tolerance = ROSSFAST_D3R_ENDPOINT_ULP_MULTIPLIER * &
          max(spacing(cursor), spacing(outer_t1), spacing(expected_t1), spacing(duration))

      if (abs(outer_t1 - expected_t1) <= tolerance) then
        selected_t1 = outer_t1
        return
      end if

      if (expected_t1 < outer_t1 - tolerance) then
        selected_t1 = expected_t1
        return
      end if
    end do

    associate(model => self)
      if (.not. same_type_as(model, model)) error stop 901
    end associate
  end subroutine rossfast_d3r_select_transaction_window

end module mod_rossfast_d3r_model_adapter
