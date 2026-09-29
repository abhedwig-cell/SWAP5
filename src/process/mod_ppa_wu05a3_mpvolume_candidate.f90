! PPA-WU05-A3 isolated MPVOLUME task-1 shrinkage candidate equation oracle.
! Results are candidates only; no mutable production state is read or published.
module mod_ppa_wu05a3_mpvolume_candidate
  use, intrinsic :: iso_fortran_env, only: real64, int32
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer(int32), parameter, public :: PPA_WU05A3_MPVOLUME_OK = 0_int32
  integer(int32), parameter, public :: PPA_WU05A3_MPVOLUME_INVALID = 1_int32
  public :: ppa_wu05a3_mpvolume_candidate

contains

  subroutine ppa_wu05a3_mpvolume_candidate(theta, theta_sat, theta_critical, shrink_relative, &
      geometry_factor, dz, matrix_fraction, subsidy_minimum, subsidy, dynamic_volume, status)
    real(real64), intent(in) :: theta, theta_sat, theta_critical, shrink_relative
    real(real64), intent(in) :: geometry_factor, dz, matrix_fraction, subsidy_minimum
    real(real64), intent(out) :: subsidy, dynamic_volume
    integer(int32), intent(out) :: status
    real(real64) :: shrink_volume

    status = PPA_WU05A3_MPVOLUME_INVALID
    subsidy = 0.0_real64
    dynamic_volume = 0.0_real64
    if (.not. all(ieee_is_finite([theta,theta_sat,theta_critical,shrink_relative, &
        geometry_factor,dz,matrix_fraction,subsidy_minimum]))) return
    if (dz <= 0.0_real64 .or. geometry_factor <= 0.0_real64 .or. &
        shrink_relative < 0.0_real64 .or. shrink_relative > 1.0_real64 .or. &
        matrix_fraction < 0.0_real64 .or. matrix_fraction > 1.0_real64 .or. &
        subsidy_minimum < 0.0_real64) return

    if (theta < theta_sat-1.0e-4_real64) then
      shrink_volume = shrink_relative*dz
      if (theta < theta_critical) then
        subsidy = max((1.0_real64-(1.0_real64-shrink_relative)** &
            (1.0_real64/geometry_factor))*dz,subsidy_minimum)
        if (dz-subsidy <= 0.0_real64) return
        dynamic_volume = matrix_fraction*(shrink_volume-subsidy)*dz/(dz-subsidy)
        if (dynamic_volume < 0.0_real64) then
          subsidy = subsidy+dynamic_volume
          dynamic_volume = 0.0_real64
        end if
      else
        subsidy = shrink_volume
        dynamic_volume = 0.0_real64
      end if
    else
      subsidy = 0.0_real64
      dynamic_volume = 0.0_real64
    end if
    if (.not. all(ieee_is_finite([subsidy,dynamic_volume]))) then
      subsidy = 0.0_real64
      dynamic_volume = 0.0_real64
      return
    end if
    status = PPA_WU05A3_MPVOLUME_OK
  end subroutine ppa_wu05a3_mpvolume_candidate

end module mod_ppa_wu05a3_mpvolume_candidate
