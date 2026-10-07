module mod_fmr_root_depth_rate_daily_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_wofost_one_day_structural_evolution, only: wofost_accepted_window_aggregates_t
  use mod_fmr_wofost_crop_transaction, only: fmr_wofost_crop_transaction_state_t, &
       fmr_wofost_root_growth_carrier_t
  use mod_crop_root_depth_rate_owner, only: crop_root_depth_rate_daily_forcing_t
  implicit none
  private

  integer, parameter, public :: FMR_ROOT_DEPTH_RATE_BIND_OK=0
  integer, parameter, public :: FMR_ROOT_DEPTH_RATE_BIND_MISSING_GROWTH=1
  integer, parameter, public :: FMR_ROOT_DEPTH_RATE_BIND_INVALID_AGGREGATES=2

  public :: bind_accepted_crop_event_to_root_depth_rate

contains

  subroutine bind_accepted_crop_event_to_root_depth_rate(crop_state,aggregates,forcing,status)
    type(fmr_wofost_crop_transaction_state_t), intent(in) :: crop_state
    type(wofost_accepted_window_aggregates_t), intent(in) :: aggregates
    type(crop_root_depth_rate_daily_forcing_t), intent(out) :: forcing
    integer, intent(out) :: status

    type(fmr_wofost_root_growth_carrier_t) :: growth
    logical :: available

    forcing=crop_root_depth_rate_daily_forcing_t()
    status=FMR_ROOT_DEPTH_RATE_BIND_INVALID_AGGREGATES
    if(.not.crop_state%ready())return
    if(aggregates%actual_root_uptake<0.0_real64.or.aggregates%potential_transpiration<0.0_real64)return
    if(aggregates%actual_root_uptake>aggregates%potential_transpiration + &
         256.0_real64*epsilon(1.0_real64)*max(1.0_real64,aggregates%potential_transpiration))return
    if(aggregates%deepest_root_oxygen_factor_available)then
      if(aggregates%deepest_root_oxygen_factor_integral<0.0_real64.or. &
           aggregates%deepest_root_oxygen_factor_integral>1.0_real64+64.0_real64*epsilon(1.0_real64))return
    else
      if(abs(aggregates%deepest_root_oxygen_factor_integral)>tiny(1.0_real64))return
    end if

    call crop_state%snapshot_root_growth(growth,available)
    if(.not.available.or..not.growth%ready())then
      status=FMR_ROOT_DEPTH_RATE_BIND_MISSING_GROWTH
      return
    end if

    forcing%potential_transpiration=aggregates%potential_transpiration
    forcing%actual_root_uptake=aggregates%actual_root_uptake
    forcing%actual_root_growth=growth%actual_gross_root_growth
    forcing%potential_root_growth=growth%potential_gross_root_growth
    forcing%deepest_root_oxygen_factor_available=aggregates%deepest_root_oxygen_factor_available
    forcing%deepest_root_oxygen_factor_integral=aggregates%deepest_root_oxygen_factor_integral
    status=FMR_ROOT_DEPTH_RATE_BIND_OK
  end subroutine bind_accepted_crop_event_to_root_depth_rate

end module mod_fmr_root_depth_rate_daily_binding
