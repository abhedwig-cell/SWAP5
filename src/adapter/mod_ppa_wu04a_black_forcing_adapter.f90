module mod_ppa_wu04a_black_forcing_adapter
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t, &
       fmr_black_evaporation_runtime_forcing_t
  use mod_ppa_wu03_common_forcing_adapter, only: ppa_wu03_common_forcing_result_t
  implicit none
  private

  integer, parameter, public :: PPA_WU04A_BIND_OK = 0
  integer, parameter, public :: PPA_WU04A_BIND_INVALID_INPUT = 1
  integer, parameter, public :: PPA_WU04A_BIND_COMMON_FORCING_REJECTED = 2

  public :: bind_ppa_wu04a_black_runtime_forcing

contains

  subroutine bind_ppa_wu04a_black_runtime_forcing(base_forcing, common_forcing, &
       wetting_reset_event, wetting_event_time, bound_forcing, status)
    type(fmr_b110_physical_forcing_t), intent(in) :: base_forcing
    type(ppa_wu03_common_forcing_result_t), intent(in) :: common_forcing
    logical, intent(in) :: wetting_reset_event
    real(real64), intent(in) :: wetting_event_time
    type(fmr_b110_physical_forcing_t), intent(out) :: bound_forcing
    integer, intent(out) :: status

    real(real64) :: values(10)

    bound_forcing = base_forcing
    status = PPA_WU04A_BIND_INVALID_INPUT

    if (.not. common_forcing%valid) then
      status = PPA_WU04A_BIND_COMMON_FORCING_REJECTED
      return
    end if

    values = [common_forcing%top_request%precipitation_rate_cm_per_day, &
         common_forcing%top_request%irrigation_rate_cm_per_day, &
         common_forcing%top_request%snowmelt_rate_cm_per_day, &
         common_forcing%top_request%runon_rate_cm_per_day, &
         common_forcing%top_request%potential_bare_soil_evaporation_cm_per_day, &
         common_forcing%top_request%potential_pond_evaporation_cm_per_day, &
         common_forcing%top_request%ponding_max_cm, &
         common_forcing%top_request%runoff_resistance_day, &
         common_forcing%top_request%runoff_exponent, wetting_event_time]
    if (.not. all(ieee_is_finite(values))) return
    if (any(values(1:8) < 0.0_real64)) return
    if (common_forcing%top_request%runoff_exponent /= 1.0_real64) return

    ! The existing fixed-flux field is deliberately neutralized.  The accepted
    ! water-mass owner is the dynamic hydraulic/top-boundary process evaluated
    ! inside each transaction trial from the raw forcing carried below.
    bound_forcing%top_flux = 0.0_real64
    if (allocated(bound_forcing%black_evaporation)) deallocate(bound_forcing%black_evaporation)
    allocate(bound_forcing%black_evaporation)
    bound_forcing%black_evaporation = fmr_black_evaporation_runtime_forcing_t()
    bound_forcing%black_evaporation%precipitation_rate_cm_per_day = &
         common_forcing%top_request%precipitation_rate_cm_per_day
    bound_forcing%black_evaporation%irrigation_rate_cm_per_day = &
         common_forcing%top_request%irrigation_rate_cm_per_day
    bound_forcing%black_evaporation%snowmelt_rate_cm_per_day = &
         common_forcing%top_request%snowmelt_rate_cm_per_day
    bound_forcing%black_evaporation%runon_rate_cm_per_day = &
         common_forcing%top_request%runon_rate_cm_per_day
    bound_forcing%black_evaporation%potential_bare_soil_evaporation_cm_per_day = &
         common_forcing%top_request%potential_bare_soil_evaporation_cm_per_day
    bound_forcing%black_evaporation%potential_pond_evaporation_cm_per_day = &
         common_forcing%top_request%potential_pond_evaporation_cm_per_day
    bound_forcing%black_evaporation%ponding_max_cm = common_forcing%top_request%ponding_max_cm
    bound_forcing%black_evaporation%runoff_resistance_day = common_forcing%top_request%runoff_resistance_day
    bound_forcing%black_evaporation%runoff_exponent = common_forcing%top_request%runoff_exponent
    bound_forcing%black_evaporation%wetting_reset_event = wetting_reset_event
    bound_forcing%black_evaporation%wetting_event_time = wetting_event_time

    status = PPA_WU04A_BIND_OK
  end subroutine bind_ppa_wu04a_black_runtime_forcing

end module mod_ppa_wu04a_black_forcing_adapter
