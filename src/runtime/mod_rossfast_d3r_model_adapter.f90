module mod_rossfast_d3r_model_adapter
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_physical_model_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t, canonical_result_t
  use mod_canonical_interval_runtime, only: run_canonical_interval
  use mod_rossfast_d3r_execution_policy, only: apply_rossfast_d3r_retry_policy, &
       rossfast_d3r_full_duration_for_index, rossfast_d3r_select_transaction_window, &
       ROSSFAST_D3R_OUTER_HORIZON_DAY, ROSSFAST_D3R_RETRY_SCALE, ROSSFAST_D3R_MAX_FULL_INDEX, &
       ROSSFAST_D3R_HALF_ONLY_INDEX, ROSSFAST_D3R_MIN_FULL_DURATION_DAY
  implicit none
  private

  type, abstract, extends(canonical_physical_model_t), public :: rossfast_d3r_model_adapter_t
  contains
    procedure :: select_transaction_window => rossfast_d3r_direct_selector_forbidden
  end type rossfast_d3r_model_adapter_t

  public :: apply_rossfast_d3r_retry_policy
  public :: rossfast_d3r_full_duration_for_index
  public :: ROSSFAST_D3R_OUTER_HORIZON_DAY
  public :: ROSSFAST_D3R_RETRY_SCALE
  public :: ROSSFAST_D3R_MAX_FULL_INDEX
  public :: ROSSFAST_D3R_HALF_ONLY_INDEX
  public :: ROSSFAST_D3R_MIN_FULL_DURATION_DAY
  public :: run_rossfast_d3r_interval

contains

  subroutine run_rossfast_d3r_interval(model, committed, forcing, interval, config, result)
    class(rossfast_d3r_model_adapter_t), intent(inout) :: model
    class(transaction_state_t), allocatable, intent(inout) :: committed
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    type(canonical_result_t), intent(out) :: result

    call run_canonical_interval(model, committed, forcing, interval, config, result, &
         rossfast_d3r_select_transaction_window)
  end subroutine run_rossfast_d3r_interval

  subroutine rossfast_d3r_direct_selector_forbidden(self, cursor, outer_t1, selected_t1)
    class(rossfast_d3r_model_adapter_t), intent(inout) :: self
    real(real64), intent(in) :: cursor, outer_t1
    real(real64), intent(out) :: selected_t1

    ! F-CI67 owns both target selection and the segment-specific retry cap.
    ! The three-argument model selector cannot carry that cap, so direct generic
    ! execution is deliberately fail-closed. Production RossFast execution must
    ! enter through run_rossfast_d3r_interval, which supplies the admitted
    ! F-CI67 callback to the canonical runtime.
    selected_t1 = cursor
    if (.not. same_type_as(self, self) .or. outer_t1 < cursor) error stop 901
  end subroutine rossfast_d3r_direct_selector_forbidden

end module mod_rossfast_d3r_model_adapter
