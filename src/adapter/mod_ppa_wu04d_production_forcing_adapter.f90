module mod_ppa_wu04d_production_forcing_adapter
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_gash_interception, only: gash_parameters_t, evaluate_gash_source_window
  use mod_vonhhbraden_interception, only: vonhhbraden_source_window_t, VONHHBRADEN_AVAILABLE
  use mod_ppa_wu04d_gash_forcing_adapter, only: bind_ppa_wu04d_gash_dynamic_top, PPA_WU04D_BIND_OK
  use mod_ppa_wu04c_dynamic_top_forcing_adapter, only: bind_ppa_wu04c_dynamic_top_to_effective_forcing, &
       PPA_WU04C_TOP_FORCING_OK
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t, &
       b110_dynamic_top_boundary_result_t, evaluate_b110_dynamic_top_boundary
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t
  implicit none
  private
  integer, parameter, public :: PPA_WU04D_PRODUCTION_FORCING_OK = 0
  integer, parameter, public :: PPA_WU04D_PRODUCTION_FORCING_GASH_REJECTED = 1
  integer, parameter, public :: PPA_WU04D_PRODUCTION_FORCING_TOP_REJECTED = 2
  type, public :: ppa_wu04d_production_forcing_diagnostics_t
    integer :: status = PPA_WU04D_PRODUCTION_FORCING_GASH_REJECTED
    integer :: gash_status = 0
    integer :: partition_status = PPA_WU04D_BIND_OK
    real(real64) :: source_aggregate_cm_per_day = 0.0_real64
    type(b110_dynamic_top_boundary_result_t) :: top_result
    logical :: result_produced = .false.
  end type
  public :: materialize_ppa_wu04d_production_forcing
contains
  subroutine materialize_ppa_wu04d_production_forcing(base_forcing, base_top_request, geometry, hydraulics, gash, source, &
      interval_rain_cm_per_day, interval_irrigation_cm_per_day, forcing, interception_cm_per_day, diagnostics)
    type(fmr_b110_physical_forcing_t), intent(in) :: base_forcing
    type(b110_dynamic_top_boundary_request_t), intent(in) :: base_top_request
    type(soil_water_parameter_set_t), intent(in) :: geometry
    type(b110_default_mvg_parameters_t), intent(in) :: hydraulics
    type(gash_parameters_t), intent(in) :: gash
    type(vonhhbraden_source_window_t), intent(in) :: source
    real(real64), intent(in) :: interval_rain_cm_per_day, interval_irrigation_cm_per_day
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(out) :: interception_cm_per_day
    type(ppa_wu04d_production_forcing_diagnostics_t), intent(out) :: diagnostics
    type(b110_dynamic_top_boundary_request_t) :: request
    integer :: top_status
    forcing = fmr_b110_physical_forcing_t(); interception_cm_per_day = 0.0_real64
    diagnostics = ppa_wu04d_production_forcing_diagnostics_t()
    call evaluate_gash_source_window(gash, source, diagnostics%source_aggregate_cm_per_day, diagnostics%gash_status)
    if (diagnostics%gash_status /= VONHHBRADEN_AVAILABLE) return
    call bind_ppa_wu04d_gash_dynamic_top(base_top_request, source, diagnostics%source_aggregate_cm_per_day, &
         interval_rain_cm_per_day, interval_irrigation_cm_per_day, request, interception_cm_per_day, diagnostics%partition_status)
    if (diagnostics%partition_status /= PPA_WU04D_BIND_OK) return
    call evaluate_b110_dynamic_top_boundary(geometry, hydraulics, request, diagnostics%top_result)
    call bind_ppa_wu04c_dynamic_top_to_effective_forcing(base_forcing, diagnostics%top_result, forcing, top_status)
    if (top_status /= PPA_WU04C_TOP_FORCING_OK) then
      diagnostics%status = PPA_WU04D_PRODUCTION_FORCING_TOP_REJECTED
      forcing = fmr_b110_physical_forcing_t(); interception_cm_per_day = 0.0_real64
      return
    end if
    diagnostics%status = PPA_WU04D_PRODUCTION_FORCING_OK
    diagnostics%result_produced = .true.
  end subroutine
end module
