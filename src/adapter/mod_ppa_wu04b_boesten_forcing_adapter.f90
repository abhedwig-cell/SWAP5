module mod_ppa_wu04b_boesten_forcing_adapter
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t, &
       fmr_boesten_evaporation_runtime_forcing_t
  use mod_ppa_wu03_common_forcing_adapter, only: ppa_wu03_common_forcing_result_t
  implicit none
  private

  integer, parameter, public :: PPA_WU04B_BIND_OK = 0
  integer, parameter, public :: PPA_WU04B_BIND_INVALID_INPUT = 1
  integer, parameter, public :: PPA_WU04B_BIND_COMMON_FORCING_REJECTED = 2

  public :: bind_ppa_wu04b_boesten_runtime_forcing

contains

  subroutine bind_ppa_wu04b_boesten_runtime_forcing(base_forcing, common_forcing, bound_forcing, status)
    type(fmr_b110_physical_forcing_t), intent(in) :: base_forcing
    type(ppa_wu03_common_forcing_result_t), intent(in) :: common_forcing
    type(fmr_b110_physical_forcing_t), intent(out) :: bound_forcing
    integer, intent(out) :: status

    real(real64) :: values(9)

    bound_forcing = base_forcing
    status = PPA_WU04B_BIND_INVALID_INPUT
    if (.not. common_forcing%valid) then
      status = PPA_WU04B_BIND_COMMON_FORCING_REJECTED
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
         common_forcing%top_request%runoff_exponent]
    if (.not. all(ieee_is_finite(values))) return
    if (any(values(1:8) < 0.0_real64)) return
    if (common_forcing%top_request%runoff_exponent /= 1.0_real64) return

    ! Under the WU04-B restricted SWINTER=0 composition, net wetting is the
    ! already resolved precipitation plus surface irrigation carried here.
    ! Actual surface water mass remains owned by dynamic top evaluation.
    bound_forcing%top_flux = 0.0_real64
    if (allocated(bound_forcing%boesten_evaporation)) deallocate(bound_forcing%boesten_evaporation)
    allocate(bound_forcing%boesten_evaporation)
    bound_forcing%boesten_evaporation = fmr_boesten_evaporation_runtime_forcing_t()
    bound_forcing%boesten_evaporation%precipitation_rate_cm_per_day = &
         common_forcing%top_request%precipitation_rate_cm_per_day
    bound_forcing%boesten_evaporation%irrigation_rate_cm_per_day = &
         common_forcing%top_request%irrigation_rate_cm_per_day
    bound_forcing%boesten_evaporation%snowmelt_rate_cm_per_day = &
         common_forcing%top_request%snowmelt_rate_cm_per_day
    bound_forcing%boesten_evaporation%runon_rate_cm_per_day = &
         common_forcing%top_request%runon_rate_cm_per_day
    bound_forcing%boesten_evaporation%potential_bare_soil_evaporation_cm_per_day = &
         common_forcing%top_request%potential_bare_soil_evaporation_cm_per_day
    bound_forcing%boesten_evaporation%potential_pond_evaporation_cm_per_day = &
         common_forcing%top_request%potential_pond_evaporation_cm_per_day
    bound_forcing%boesten_evaporation%ponding_max_cm = common_forcing%top_request%ponding_max_cm
    bound_forcing%boesten_evaporation%runoff_resistance_day = common_forcing%top_request%runoff_resistance_day
    bound_forcing%boesten_evaporation%runoff_exponent = common_forcing%top_request%runoff_exponent

    status = PPA_WU04B_BIND_OK
  end subroutine bind_ppa_wu04b_boesten_runtime_forcing

end module mod_ppa_wu04b_boesten_forcing_adapter
