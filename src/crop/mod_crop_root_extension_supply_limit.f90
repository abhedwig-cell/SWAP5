module mod_crop_root_extension_supply_limit
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: ROOT_SUPPLY_OK=0
  integer, parameter, public :: ROOT_SUPPLY_INVALID_INPUT=1

  type, public :: root_extension_supply_result_t
    real(real64) :: extension_cm=0.0_real64
    real(real64) :: drought_scaled_extension_cm=0.0_real64
    real(real64) :: required_root_growth=0.0_real64
    real(real64) :: supply_factor=1.0_real64
  end type

  public :: limit_root_extension_by_drought_and_supply

contains

  subroutine limit_root_extension_by_drought_and_supply(proposed_extension_cm,minimum_extension_cm, &
       daily_drought_uptake_factor,extent_critical_fraction,deepest_node_root_biomass, &
       current_root_depth_cm,deepest_node_top_depth_cm,available_root_growth,negligible_extension_cm,result,status)
    real(real64), intent(in) :: proposed_extension_cm,minimum_extension_cm
    real(real64), intent(in) :: daily_drought_uptake_factor,extent_critical_fraction
    real(real64), intent(in) :: deepest_node_root_biomass,current_root_depth_cm,deepest_node_top_depth_cm
    real(real64), intent(in) :: available_root_growth,negligible_extension_cm
    type(root_extension_supply_result_t), intent(out) :: result
    integer, intent(out) :: status

    real(real64) :: rr, denominator

    result=root_extension_supply_result_t()
    status=ROOT_SUPPLY_INVALID_INPUT
    if(.not.ieee_is_finite(proposed_extension_cm).or.proposed_extension_cm<0.0_real64)return
    if(.not.ieee_is_finite(minimum_extension_cm).or.minimum_extension_cm<0.0_real64)return
    if(minimum_extension_cm>proposed_extension_cm)return
    if(.not.ieee_is_finite(daily_drought_uptake_factor).or. &
       daily_drought_uptake_factor<0.0_real64.or.daily_drought_uptake_factor>1.0_real64)return
    if(.not.ieee_is_finite(extent_critical_fraction).or.extent_critical_fraction<=0.0_real64.or. &
       extent_critical_fraction>1.0_real64)return
    if(.not.ieee_is_finite(deepest_node_root_biomass).or.deepest_node_root_biomass<0.0_real64)return
    if(.not.ieee_is_finite(current_root_depth_cm).or.current_root_depth_cm<0.0_real64)return
    if(.not.ieee_is_finite(deepest_node_top_depth_cm))return
    if(.not.ieee_is_finite(available_root_growth).or.available_root_growth<0.0_real64)return
    if(.not.ieee_is_finite(negligible_extension_cm).or.negligible_extension_cm<0.0_real64)return

    ! Pinned B1.11 SWDMI2RD=2:
    ! rr=max(min(rr,rrimin),rr*min(1,(1-ialpdry_day)/extentcrit))
    rr=max(min(proposed_extension_cm,minimum_extension_cm), &
           proposed_extension_cm*min(1.0_real64,(1.0_real64-daily_drought_uptake_factor)/extent_critical_fraction))
    result%drought_scaled_extension_cm=rr

    ! grrt_needed=(wroot_node(noddrz)/(rd+ztopcp(noddrz)))*rr
    denominator=current_root_depth_cm+deepest_node_top_depth_cm
    if(rr>0.0_real64)then
      if(denominator<=0.0_real64)return
      result%required_root_growth=(deepest_node_root_biomass/denominator)*rr
      if(result%required_root_growth>available_root_growth.and.result%required_root_growth>0.0_real64)then
        result%supply_factor=available_root_growth/result%required_root_growth
        rr=rr*result%supply_factor
      end if
    end if
    if(rr<negligible_extension_cm)rr=0.0_real64
    result%extension_cm=rr
    status=ROOT_SUPPLY_OK
  end subroutine

end module mod_crop_root_extension_supply_limit
