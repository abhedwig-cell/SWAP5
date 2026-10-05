module mod_irrigation_solute_depth_process
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: IRRIGATION_SOLUTE_DEPTH_OK = 0
  integer, parameter, public :: IRRIGATION_SOLUTE_DEPTH_INVALID = 1
  public :: select_solute_overirrigation_depth
contains
  pure subroutine select_solute_overirrigation_depth(base_depth_cm, soil_concentration, &
       threshold_concentration, surplus_percent, enabled, candidate_depth_cm, status)
    real(real64), intent(in) :: base_depth_cm, soil_concentration, threshold_concentration, surplus_percent
    logical, intent(in) :: enabled
    real(real64), intent(out) :: candidate_depth_cm
    integer, intent(out) :: status

    candidate_depth_cm = 0.0_real64
    status = IRRIGATION_SOLUTE_DEPTH_INVALID
    if (.not. all(ieee_is_finite([base_depth_cm,soil_concentration,threshold_concentration,surplus_percent]))) return
    if (base_depth_cm < 0.0_real64 .or. soil_concentration < 0.0_real64 .or. &
        threshold_concentration < 0.0_real64 .or. surplus_percent < 0.0_real64 .or. &
        surplus_percent > 100.0_real64) return
    candidate_depth_cm = base_depth_cm
    if (enabled .and. soil_concentration > threshold_concentration) &
      candidate_depth_cm = base_depth_cm*(1.0_real64+0.01_real64*surplus_percent)
    if (.not. ieee_is_finite(candidate_depth_cm)) then
      candidate_depth_cm = 0.0_real64
      return
    end if
    status = IRRIGATION_SOLUTE_DEPTH_OK
  end subroutine
end module
