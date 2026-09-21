module mod_gc_hlink_low01_groundwater_level_adapter
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t
  implicit none
  private

  integer, parameter, public :: LOW01_GWL_OK = 0
  integer, parameter, public :: LOW01_GWL_INVALID = 1
  integer, parameter, public :: LOW01_GWL_UNSUPPORTED_BRANCH = 2

  integer, parameter, public :: LOW01_BRANCH_BELOW_PROFILE = 1
  integer, parameter, public :: LOW01_BRANCH_INSIDE_PROFILE = 2
  integer, parameter, public :: LOW01_BRANCH_ABOVE_OR_AT_TOP = 3

  type, public :: gc_low01_groundwater_level_control_t
    real(real64) :: groundwater_level = 0.0_real64
  end type gc_low01_groundwater_level_control_t

  public :: classify_low01_groundwater_level
  public :: materialize_low01a_below_profile

contains

  subroutine classify_low01_groundwater_level(control, z, dz, branch, status)
    type(gc_low01_groundwater_level_control_t), intent(in) :: control
    real(real64), intent(in) :: z(:), dz(:)
    integer, intent(out) :: branch, status
    integer :: n
    real(real64) :: lower_face

    branch = 0
    status = LOW01_GWL_INVALID
    n = size(z)
    if (n <= 0 .or. size(dz) /= n) return
    if (.not. ieee_is_finite(control%groundwater_level)) return
    if (any(.not. ieee_is_finite(z)) .or. any(.not. ieee_is_finite(dz))) return
    if (any(dz <= 0.0_real64)) return

    lower_face = z(n) - 0.5_real64 * dz(n)
    if (control%groundwater_level < lower_face) then
      branch = LOW01_BRANCH_BELOW_PROFILE
    else if (control%groundwater_level >= z(1) - 1.0e-4_real64) then
      branch = LOW01_BRANCH_ABOVE_OR_AT_TOP
    else
      branch = LOW01_BRANCH_INSIDE_PROFILE
    end if
    status = LOW01_GWL_OK
  end subroutine classify_low01_groundwater_level

  subroutine materialize_low01a_below_profile(control, z, dz, base_forcing, forcing, branch, status)
    type(gc_low01_groundwater_level_control_t), intent(in) :: control
    real(real64), intent(in) :: z(:), dz(:)
    type(fmr_b110_physical_forcing_t), intent(in) :: base_forcing
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    integer, intent(out) :: branch, status
    integer :: classify_status, n

    forcing = base_forcing
    status = LOW01_GWL_INVALID
    branch = 0
    call classify_low01_groundwater_level(control, z, dz, branch, classify_status)
    if (classify_status /= LOW01_GWL_OK) return
    if (branch /= LOW01_BRANCH_BELOW_PROFILE) then
      status = LOW01_GWL_UNSUPPORTED_BRANCH
      return
    end if

    n = size(z)
    forcing%bottom_head = control%groundwater_level - z(n) + 0.5_real64 * dz(n)
    if (.not. ieee_is_finite(forcing%bottom_head)) return
    status = LOW01_GWL_OK
  end subroutine materialize_low01a_below_profile

end module mod_gc_hlink_low01_groundwater_level_adapter
