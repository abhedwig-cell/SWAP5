module mod_fmr_reference_et_demand_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_canonical_contracts, only: canonical_interval_t
  use mod_reference_et_demand_process, only: reference_et_demand_parameters_t, reference_et_demand_forcing_t, &
       reference_et_demand_canopy_view_t, reference_et_demand_result_t, reference_et_demand_diagnostics_t, &
       evaluate_restricted_reference_et_demand, REF_ET_DEMAND_OK
  implicit none
  private

  integer, parameter, public :: FMR_REFERENCE_ET_BINDING_OK = 0
  integer, parameter, public :: FMR_REFERENCE_ET_BINDING_INVALID_INTERVAL = 1
  integer, parameter, public :: FMR_REFERENCE_ET_BINDING_INVALID_FORCING_SPAN = 2
  integer, parameter, public :: FMR_REFERENCE_ET_BINDING_FORCING_NOT_COVERING_INTERVAL = 3
  integer, parameter, public :: FMR_REFERENCE_ET_BINDING_PROCESS_REJECTED = 4

  type, public :: fmr_reference_et_forcing_span_t
    real(real64) :: t0 = 0.0_real64
    real(real64) :: t1 = 0.0_real64
    real(real64) :: reference_et_mm_per_day = 0.0_real64
  end type fmr_reference_et_forcing_span_t

  type, public :: fmr_reference_et_binding_diagnostics_t
    integer :: status = FMR_REFERENCE_ET_BINDING_OK
    integer :: process_status = REF_ET_DEMAND_OK
    real(real64) :: interval_duration = 0.0_real64
    logical :: interval_valid = .false.
    logical :: forcing_span_valid = .false.
    logical :: forcing_covers_interval = .false.
    logical :: process_called = .false.
    logical :: result_produced = .false.
  end type fmr_reference_et_binding_diagnostics_t

  public :: fmr_evaluate_reference_et_demand

contains

  subroutine fmr_evaluate_reference_et_demand(interval, forcing_span, parameters, canopy, result, &
                                                process_diagnostics, diagnostics)
    type(canonical_interval_t), intent(in) :: interval
    type(fmr_reference_et_forcing_span_t), intent(in) :: forcing_span
    type(reference_et_demand_parameters_t), intent(in) :: parameters
    type(reference_et_demand_canopy_view_t), intent(in) :: canopy
    type(reference_et_demand_result_t), intent(out) :: result
    type(reference_et_demand_diagnostics_t), intent(out) :: process_diagnostics
    type(fmr_reference_et_binding_diagnostics_t), intent(out) :: diagnostics

    type(reference_et_demand_forcing_t) :: process_forcing

    result = reference_et_demand_result_t()
    process_diagnostics = reference_et_demand_diagnostics_t()
    diagnostics = fmr_reference_et_binding_diagnostics_t()

    if (.not. ieee_is_finite(interval%t0) .or. .not. ieee_is_finite(interval%t1)) then
      diagnostics%status = FMR_REFERENCE_ET_BINDING_INVALID_INTERVAL
      return
    end if
    if (interval%t1 <= interval%t0) then
      diagnostics%status = FMR_REFERENCE_ET_BINDING_INVALID_INTERVAL
      return
    end if
    diagnostics%interval_valid = .true.
    diagnostics%interval_duration = interval%t1 - interval%t0

    if (.not. ieee_is_finite(forcing_span%t0) .or. .not. ieee_is_finite(forcing_span%t1)) then
      diagnostics%status = FMR_REFERENCE_ET_BINDING_INVALID_FORCING_SPAN
      return
    end if
    if (forcing_span%t1 <= forcing_span%t0) then
      diagnostics%status = FMR_REFERENCE_ET_BINDING_INVALID_FORCING_SPAN
      return
    end if
    diagnostics%forcing_span_valid = .true.

    if (interval%t0 < forcing_span%t0 .or. interval%t1 > forcing_span%t1) then
      diagnostics%status = FMR_REFERENCE_ET_BINDING_FORCING_NOT_COVERING_INTERVAL
      return
    end if
    diagnostics%forcing_covers_interval = .true.

    process_forcing%reference_et_mm_per_day = forcing_span%reference_et_mm_per_day
    diagnostics%process_called = .true.
    call evaluate_restricted_reference_et_demand(parameters, process_forcing, canopy, result, process_diagnostics)
    diagnostics%process_status = process_diagnostics%status

    if (process_diagnostics%status /= REF_ET_DEMAND_OK) then
      result = reference_et_demand_result_t()
      diagnostics%status = FMR_REFERENCE_ET_BINDING_PROCESS_REJECTED
      return
    end if

    diagnostics%result_produced = .true.
  end subroutine fmr_evaluate_reference_et_demand

end module mod_fmr_reference_et_demand_binding
