module mod_crop_root_depth_biomass
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_wofost_rate_table, only: wofost_rate_table_t, WOFOST_RATE_TABLE_OK
  implicit none
  private
  integer, parameter, public :: CROP_ROOT_DEPTH_BIOMASS_OK = 0
  integer, parameter, public :: CROP_ROOT_DEPTH_BIOMASS_INVALID_TABLE = 1
  integer, parameter, public :: CROP_ROOT_DEPTH_BIOMASS_INVALID_BIOMASS = 2
  integer, parameter, public :: CROP_ROOT_DEPTH_BIOMASS_INVALID_LIMIT = 3
  integer, parameter, public :: CROP_ROOT_DEPTH_BIOMASS_INVALID_RESULT = 4
  public :: evaluate_crop_root_depth_biomass
contains
  subroutine evaluate_crop_root_depth_biomass(table, root_biomass, maximum_root_depth_cm, value, status)
    type(wofost_rate_table_t), intent(in) :: table
    real(real64), intent(in) :: root_biomass, maximum_root_depth_cm
    real(real64), intent(out) :: value
    integer, intent(out) :: status
    real(real64) :: raw_depth
    integer :: table_status
    value=0.0_real64
    status=CROP_ROOT_DEPTH_BIOMASS_INVALID_TABLE
    if(.not.table%ready())return
    status=CROP_ROOT_DEPTH_BIOMASS_INVALID_BIOMASS
    if(.not.ieee_is_finite(root_biomass).or.root_biomass<0.0_real64)return
    status=CROP_ROOT_DEPTH_BIOMASS_INVALID_LIMIT
    if(.not.ieee_is_finite(maximum_root_depth_cm).or.maximum_root_depth_cm<0.0_real64)return
    call table%evaluate(root_biomass,raw_depth,table_status)
    if(table_status/=WOFOST_RATE_TABLE_OK)return
    if(.not.ieee_is_finite(raw_depth).or.raw_depth<0.0_real64)then
      status=CROP_ROOT_DEPTH_BIOMASS_INVALID_RESULT;return
    end if
    value=min(raw_depth,maximum_root_depth_cm)
    status=CROP_ROOT_DEPTH_BIOMASS_OK
  end subroutine evaluate_crop_root_depth_biomass
end module mod_crop_root_depth_biomass
