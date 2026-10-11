module mod_crop_root_depth_dvs
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_wofost_rate_table, only: wofost_rate_table_t, WOFOST_RATE_TABLE_OK
  implicit none
  private

  integer, parameter, public :: CROP_ROOT_DEPTH_DVS_OK = 0
  integer, parameter, public :: CROP_ROOT_DEPTH_DVS_INVALID_TABLE = 1
  integer, parameter, public :: CROP_ROOT_DEPTH_DVS_INVALID_DVS = 2
  integer, parameter, public :: CROP_ROOT_DEPTH_DVS_INVALID_MAX_DEPTH = 3
  integer, parameter, public :: CROP_ROOT_DEPTH_DVS_INVALID_DEPTH = 4

  public :: evaluate_crop_root_depth_dvs

contains

  subroutine evaluate_crop_root_depth_dvs(table, development_stage, maximum_root_depth_cm, root_depth_cm, status)
    type(wofost_rate_table_t), intent(in) :: table
    real(real64), intent(in) :: development_stage, maximum_root_depth_cm
    real(real64), intent(out) :: root_depth_cm
    integer, intent(out) :: status
    real(real64) :: table_depth
    integer :: table_status

    root_depth_cm = 0.0_real64
    status = CROP_ROOT_DEPTH_DVS_OK
    if (.not. table%ready()) then
      status = CROP_ROOT_DEPTH_DVS_INVALID_TABLE
      return
    end if
    if (.not. ieee_is_finite(development_stage)) then
      status = CROP_ROOT_DEPTH_DVS_INVALID_DVS
      return
    end if
    if (.not. ieee_is_finite(maximum_root_depth_cm) .or. maximum_root_depth_cm <= 0.0_real64) then
      status = CROP_ROOT_DEPTH_DVS_INVALID_MAX_DEPTH
      return
    end if

    call table%evaluate(development_stage, table_depth, table_status)
    if (table_status /= WOFOST_RATE_TABLE_OK .or. .not. ieee_is_finite(table_depth) .or. table_depth < 0.0_real64) then
      status = CROP_ROOT_DEPTH_DVS_INVALID_DEPTH
      return
    end if

    ! B1.11 MOD_cropdevelopment SWRD=1:
    ! RD = min(AFGEN(RDTB,DVS), RDM).
    root_depth_cm = min(table_depth, maximum_root_depth_cm)
  end subroutine evaluate_crop_root_depth_dvs

end module mod_crop_root_depth_dvs
