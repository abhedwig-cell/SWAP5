module mod_ppa_wu03_common_forcing_adapter
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_canonical_contracts, only: canonical_interval_t
  use mod_reference_et_demand_process, only: reference_et_demand_parameters_t, &
       reference_et_demand_canopy_view_t, reference_et_demand_result_t, &
       reference_et_demand_diagnostics_t, REF_ET_DEMAND_OK
  use mod_fmr_reference_et_demand_binding, only: fmr_reference_et_forcing_span_t, &
       fmr_reference_et_binding_diagnostics_t, fmr_evaluate_reference_et_demand, &
       FMR_REFERENCE_ET_BINDING_OK
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t, &
       b110_dynamic_top_boundary_result_t, B110_DYN_TOP_AVAILABLE, B110_DYN_TOP_REGIME_FLUX
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t
  implicit none
  private

  integer, parameter, public :: PPA_WU03_OK = 0
  integer, parameter, public :: PPA_WU03_INVALID_INPUT = 1
  integer, parameter, public :: PPA_WU03_UNSUPPORTED_ET = 2
  integer, parameter, public :: PPA_WU03_UNSUPPORTED_INTERCEPTION = 3
  integer, parameter, public :: PPA_WU03_UNSUPPORTED_IRRIGATION = 4
  integer, parameter, public :: PPA_WU03_REFERENCE_ET_REJECTED = 5
  integer, parameter, public :: PPA_WU03_TOP_RESULT_REJECTED = 6

  integer, parameter, public :: PPA_WU03_ET_REFERENCE = 1
  integer, parameter, public :: PPA_WU03_INTERCEPTION_NONE = 0
  integer, parameter, public :: PPA_WU03_IRRIGATION_NONE = 0
  integer, parameter, public :: PPA_WU03_IRRIGATION_RESOLVED_SURFACE = 1

  type, public :: ppa_wu03_common_forcing_config_t
    integer :: et_mode = PPA_WU03_ET_REFERENCE
    integer :: interception_mode = PPA_WU03_INTERCEPTION_NONE
    integer :: irrigation_mode = PPA_WU03_IRRIGATION_NONE
    type(reference_et_demand_parameters_t) :: reference_et_parameters
  end type ppa_wu03_common_forcing_config_t

  type, public :: ppa_wu03_common_forcing_input_t
    type(canonical_interval_t) :: interval
    real(real64) :: forcing_t0 = 0.0_real64
    real(real64) :: forcing_t1 = 0.0_real64
    real(real64) :: precipitation_rate_cm_per_day = 0.0_real64
    real(real64) :: surface_irrigation_rate_cm_per_day = 0.0_real64
    type(fmr_reference_et_forcing_span_t) :: reference_et
    type(reference_et_demand_canopy_view_t) :: canopy
  end type ppa_wu03_common_forcing_input_t

  type, public :: ppa_wu03_common_forcing_result_t
    logical :: valid = .false.
    type(reference_et_demand_result_t) :: reference_et_demand
    type(b110_dynamic_top_boundary_request_t) :: top_request
  end type ppa_wu03_common_forcing_result_t

  type, public :: ppa_wu03_common_forcing_diagnostics_t
    integer :: status = PPA_WU03_INVALID_INPUT
    integer :: reference_et_binding_status = FMR_REFERENCE_ET_BINDING_OK
    integer :: reference_et_process_status = REF_ET_DEMAND_OK
    logical :: interval_valid = .false.
    logical :: forcing_span_valid = .false.
    logical :: forcing_covers_interval = .false.
    logical :: reference_et_called = .false.
    logical :: result_produced = .false.
  end type ppa_wu03_common_forcing_diagnostics_t

  public :: materialize_ppa_wu03_common_forcing
  public :: bind_ppa_wu03_flux_result_to_effective_forcing

contains

  subroutine materialize_ppa_wu03_common_forcing(config, input, base_top_request, result, diagnostics)
    type(ppa_wu03_common_forcing_config_t), intent(in) :: config
    type(ppa_wu03_common_forcing_input_t), intent(in) :: input
    type(b110_dynamic_top_boundary_request_t), intent(in) :: base_top_request
    type(ppa_wu03_common_forcing_result_t), intent(out) :: result
    type(ppa_wu03_common_forcing_diagnostics_t), intent(out) :: diagnostics

    type(reference_et_demand_diagnostics_t) :: process_diagnostics
    type(fmr_reference_et_binding_diagnostics_t) :: binding_diagnostics
    real(real64) :: duration

    result = ppa_wu03_common_forcing_result_t()
    diagnostics = ppa_wu03_common_forcing_diagnostics_t()

    if (config%et_mode /= PPA_WU03_ET_REFERENCE) then
      diagnostics%status = PPA_WU03_UNSUPPORTED_ET
      return
    end if
    if (config%interception_mode /= PPA_WU03_INTERCEPTION_NONE) then
      diagnostics%status = PPA_WU03_UNSUPPORTED_INTERCEPTION
      return
    end if
    if (config%irrigation_mode /= PPA_WU03_IRRIGATION_NONE .and. &
        config%irrigation_mode /= PPA_WU03_IRRIGATION_RESOLVED_SURFACE) then
      diagnostics%status = PPA_WU03_UNSUPPORTED_IRRIGATION
      return
    end if

    if (.not. ieee_is_finite(input%interval%t0) .or. .not. ieee_is_finite(input%interval%t1)) return
    duration = input%interval%t1 - input%interval%t0
    if (.not. ieee_is_finite(duration) .or. duration <= 0.0_real64) return
    diagnostics%interval_valid = .true.

    if (.not. ieee_is_finite(input%forcing_t0) .or. .not. ieee_is_finite(input%forcing_t1)) return
    if (input%forcing_t1 <= input%forcing_t0) return
    diagnostics%forcing_span_valid = .true.
    if (input%forcing_t0 > input%interval%t0 .or. input%forcing_t1 < input%interval%t1) return
    diagnostics%forcing_covers_interval = .true.

    if (.not. ieee_is_finite(input%precipitation_rate_cm_per_day) .or. &
        input%precipitation_rate_cm_per_day < 0.0_real64) return
    if (.not. ieee_is_finite(input%surface_irrigation_rate_cm_per_day) .or. &
        input%surface_irrigation_rate_cm_per_day < 0.0_real64) return
    if (config%irrigation_mode == PPA_WU03_IRRIGATION_NONE .and. &
        input%surface_irrigation_rate_cm_per_day /= 0.0_real64) then
      diagnostics%status = PPA_WU03_UNSUPPORTED_IRRIGATION
      return
    end if

    ! Snowmelt and runon are separate ingestion slices.  They are never
    ! silently inherited from the caller's base request in this WU03 slice.
    if (.not. ieee_is_finite(base_top_request%snowmelt_rate_cm_per_day) .or. &
        .not. ieee_is_finite(base_top_request%runon_rate_cm_per_day)) return
    if (base_top_request%snowmelt_rate_cm_per_day /= 0.0_real64 .or. &
        base_top_request%runon_rate_cm_per_day /= 0.0_real64) return

    diagnostics%reference_et_called = .true.
    call fmr_evaluate_reference_et_demand(input%interval, input%reference_et, &
         config%reference_et_parameters, input%canopy, result%reference_et_demand, &
         process_diagnostics, binding_diagnostics)
    diagnostics%reference_et_binding_status = binding_diagnostics%status
    diagnostics%reference_et_process_status = process_diagnostics%status
    if (binding_diagnostics%status /= FMR_REFERENCE_ET_BINDING_OK .or. &
        process_diagnostics%status /= REF_ET_DEMAND_OK .or. &
        .not. binding_diagnostics%result_produced) then
      diagnostics%status = PPA_WU03_REFERENCE_ET_REJECTED
      return
    end if

    result%top_request = base_top_request
    result%top_request%step_duration_day = duration
    result%top_request%precipitation_rate_cm_per_day = input%precipitation_rate_cm_per_day
    result%top_request%irrigation_rate_cm_per_day = input%surface_irrigation_rate_cm_per_day
    result%top_request%snowmelt_rate_cm_per_day = 0.0_real64
    result%top_request%runon_rate_cm_per_day = 0.0_real64
    result%top_request%potential_bare_soil_evaporation_cm_per_day = &
         result%reference_et_demand%potential_soil_evaporation_cm_per_day
    result%top_request%potential_pond_evaporation_cm_per_day = &
         result%reference_et_demand%potential_pond_evaporation_cm_per_day

    result%valid = .true.
    diagnostics%status = PPA_WU03_OK
    diagnostics%result_produced = .true.
  end subroutine materialize_ppa_wu03_common_forcing

  subroutine bind_ppa_wu03_flux_result_to_effective_forcing(base_forcing, top_result, bound_forcing, status)
    type(fmr_b110_physical_forcing_t), intent(in) :: base_forcing
    type(b110_dynamic_top_boundary_result_t), intent(in) :: top_result
    type(fmr_b110_physical_forcing_t), intent(out) :: bound_forcing
    integer, intent(out) :: status

    bound_forcing = base_forcing
    status = PPA_WU03_TOP_RESULT_REJECTED

    if (top_result%status /= B110_DYN_TOP_AVAILABLE) return
    if (top_result%regime /= B110_DYN_TOP_REGIME_FLUX) return
    if (.not. ieee_is_finite(top_result%actual_top_flux_cm_per_day)) return
    if (top_result%runoff_potential) return
    if (top_result%candidate_ponding_depth_cm /= 0.0_real64) return
    if (top_result%runoff_depth_cm /= 0.0_real64) return

    bound_forcing%top_flux = top_result%actual_top_flux_cm_per_day
    status = PPA_WU03_OK
  end subroutine bind_ppa_wu03_flux_result_to_effective_forcing

end module mod_ppa_wu03_common_forcing_adapter
