module mod_fmr_crop_co2_response_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_crop_co2_response_resolver, only: crop_co2_response_parameters_t, crop_co2_response_t, &
       evaluate_crop_co2_response, CROP_CO2_RESPONSE_OK
  use mod_wofost_one_day_structural_evolution, only: wofost_one_day_forcing_t
  use mod_crop_et_canopy_view_provider, only: crop_et_canopy_parameters_t, crop_et_canopy_state_view_t, &
       crop_et_canopy_forcing_t, crop_et_canopy_view_t, crop_et_canopy_diagnostics_t, &
       evaluate_crop_et_canopy_view, CROP_ET_CANOPY_OK
  implicit none
  private

  integer, parameter, public :: FMR_CROP_CO2_BINDING_OK = 0
  integer, parameter, public :: FMR_CROP_CO2_BINDING_RESPONSE_REJECTED = 1
  integer, parameter, public :: FMR_CROP_CO2_BINDING_ET_REJECTED = 2

  type, public :: fmr_crop_co2_binding_diagnostics_t
    integer :: status = FMR_CROP_CO2_BINDING_OK
    integer :: response_status = CROP_CO2_RESPONSE_OK
    integer :: canopy_status = CROP_ET_CANOPY_OK
    logical :: response_resolved = .false.
    logical :: crop_forcing_bound = .false.
    logical :: canopy_view_bound = .false.
  end type fmr_crop_co2_binding_diagnostics_t

  public :: fmr_bind_crop_co2_response

contains

  subroutine fmr_bind_crop_co2_response(parameters, atmospheric_co2_ppm, base_crop_forcing, canopy_parameters, &
                                        canopy_state, crop_forcing, canopy_view, response, canopy_diagnostics, diagnostics)
    type(crop_co2_response_parameters_t), intent(in) :: parameters
    real(real64), intent(in) :: atmospheric_co2_ppm
    type(wofost_one_day_forcing_t), intent(in) :: base_crop_forcing
    type(crop_et_canopy_parameters_t), intent(in) :: canopy_parameters
    type(crop_et_canopy_state_view_t), intent(in) :: canopy_state
    type(wofost_one_day_forcing_t), intent(out) :: crop_forcing
    type(crop_et_canopy_view_t), intent(out) :: canopy_view
    type(crop_co2_response_t), intent(out) :: response
    type(crop_et_canopy_diagnostics_t), intent(out) :: canopy_diagnostics
    type(fmr_crop_co2_binding_diagnostics_t), intent(out) :: diagnostics

    type(crop_et_canopy_forcing_t) :: canopy_forcing
    integer :: status

    crop_forcing = base_crop_forcing
    canopy_view = crop_et_canopy_view_t()
    response = crop_co2_response_t()
    canopy_diagnostics = crop_et_canopy_diagnostics_t()
    diagnostics = fmr_crop_co2_binding_diagnostics_t()

    if (.not. canopy_state%crop_emerged) then
      canopy_forcing%atmospheric_co2_ppm = 0.0_real64
      call evaluate_crop_et_canopy_view(canopy_parameters, canopy_state, canopy_forcing, canopy_view, &
                                        canopy_diagnostics)
      diagnostics%canopy_status = canopy_diagnostics%status
      if (canopy_diagnostics%status /= CROP_ET_CANOPY_OK .or. .not. canopy_diagnostics%result_produced) then
        diagnostics%status = FMR_CROP_CO2_BINDING_ET_REJECTED
        return
      end if
      diagnostics%canopy_view_bound = .true.
      diagnostics%status = FMR_CROP_CO2_BINDING_OK
      return
    end if

    call evaluate_crop_co2_response(parameters, atmospheric_co2_ppm, response, status)
    diagnostics%response_status = status
    if (status /= CROP_CO2_RESPONSE_OK) then
      diagnostics%status = FMR_CROP_CO2_BINDING_RESPONSE_REJECTED
      return
    end if
    diagnostics%response_resolved = .true.

    crop_forcing%co2_efficiency_factor = response%efficiency_factor
    crop_forcing%co2_amax_factor = response%amax_factor
    diagnostics%crop_forcing_bound = .true.

    canopy_forcing%atmospheric_co2_ppm = atmospheric_co2_ppm
    call evaluate_crop_et_canopy_view(canopy_parameters, canopy_state, canopy_forcing, canopy_view, &
                                      canopy_diagnostics, response%transpiration_factor)
    diagnostics%canopy_status = canopy_diagnostics%status
    if (canopy_diagnostics%status /= CROP_ET_CANOPY_OK .or. .not. canopy_diagnostics%result_produced) then
      crop_forcing = base_crop_forcing
      canopy_view = crop_et_canopy_view_t()
      diagnostics%crop_forcing_bound = .false.
      diagnostics%status = FMR_CROP_CO2_BINDING_ET_REJECTED
      return
    end if
    diagnostics%canopy_view_bound = .true.
    diagnostics%status = FMR_CROP_CO2_BINDING_OK
  end subroutine fmr_bind_crop_co2_response

end module mod_fmr_crop_co2_response_binding
