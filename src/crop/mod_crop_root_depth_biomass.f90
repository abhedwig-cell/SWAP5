module mod_crop_root_depth_biomass
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_wofost_rate_table, only: wofost_rate_table_t, WOFOST_RATE_TABLE_OK
  implicit none
  private

  integer, parameter, public :: CROP_ROOT_DEPTH_BIOMASS_OK = 0
  integer, parameter, public :: CROP_ROOT_DEPTH_BIOMASS_INVALID_TABLE = 1
  integer, parameter, public :: CROP_ROOT_DEPTH_BIOMASS_INVALID_INPUT = 2

  type, public :: crop_root_depth_biomass_result_t
    real(real64) :: maximum_root_depth_cm = 0.0_real64
    real(real64) :: actual_root_depth_cm = 0.0_real64
    real(real64) :: potential_root_depth_cm = 0.0_real64
  end type crop_root_depth_biomass_result_t

  public :: evaluate_crop_root_depth_biomass

contains

  subroutine evaluate_crop_root_depth_biomass(table, soil_maximum_root_depth_cm, maximum_root_biomass, &
                                              actual_root_biomass, potential_root_biomass, result, status)
    type(wofost_rate_table_t), intent(in) :: table
    real(real64), intent(in) :: soil_maximum_root_depth_cm
    real(real64), intent(in) :: maximum_root_biomass
    real(real64), intent(in) :: actual_root_biomass
    real(real64), intent(in) :: potential_root_biomass
    type(crop_root_depth_biomass_result_t), intent(out) :: result
    integer, intent(out) :: status

    real(real64) :: crop_maximum_depth, actual_depth, potential_depth
    integer :: table_status

    result = crop_root_depth_biomass_result_t()
    status = CROP_ROOT_DEPTH_BIOMASS_INVALID_INPUT
    if (.not. table%ready()) then
      status = CROP_ROOT_DEPTH_BIOMASS_INVALID_TABLE
      return
    end if
    if (.not. ieee_is_finite(soil_maximum_root_depth_cm) .or. soil_maximum_root_depth_cm < 0.0_real64) return
    if (.not. ieee_is_finite(maximum_root_biomass) .or. maximum_root_biomass < 0.0_real64) return
    if (.not. ieee_is_finite(actual_root_biomass) .or. actual_root_biomass < 0.0_real64) return
    if (.not. ieee_is_finite(potential_root_biomass) .or. potential_root_biomass < 0.0_real64) return

    ! B1.11 get_rdm(), SWRD=3:
    !   rdc = AFGEN(RLWTB,WRTMAX)
    !   rdm = min(RDMAX,rdc)
    call table%evaluate(maximum_root_biomass, crop_maximum_depth, table_status)
    if (table_status /= WOFOST_RATE_TABLE_OK .or. .not. ieee_is_finite(crop_maximum_depth) .or. &
        crop_maximum_depth < 0.0_real64) then
      status = CROP_ROOT_DEPTH_BIOMASS_INVALID_TABLE
      return
    end if
    result%maximum_root_depth_cm = min(soil_maximum_root_depth_cm, crop_maximum_depth)

    ! B1.11 update_rootextension(), SWRD=3:
    !   rdpot = min(AFGEN(RLWTB,WRTpot),RDM)
    !   rd    = min(AFGEN(RLWTB,WRT),RDM)
    call table%evaluate(actual_root_biomass, actual_depth, table_status)
    if (table_status /= WOFOST_RATE_TABLE_OK .or. .not. ieee_is_finite(actual_depth) .or. actual_depth < 0.0_real64) then
      result = crop_root_depth_biomass_result_t()
      status = CROP_ROOT_DEPTH_BIOMASS_INVALID_TABLE
      return
    end if
    call table%evaluate(potential_root_biomass, potential_depth, table_status)
    if (table_status /= WOFOST_RATE_TABLE_OK .or. .not. ieee_is_finite(potential_depth) .or. potential_depth < 0.0_real64) then
      result = crop_root_depth_biomass_result_t()
      status = CROP_ROOT_DEPTH_BIOMASS_INVALID_TABLE
      return
    end if
    result%actual_root_depth_cm = min(actual_depth, result%maximum_root_depth_cm)
    result%potential_root_depth_cm = min(potential_depth, result%maximum_root_depth_cm)

    status = CROP_ROOT_DEPTH_BIOMASS_OK
  end subroutine evaluate_crop_root_depth_biomass

end module mod_crop_root_depth_biomass
