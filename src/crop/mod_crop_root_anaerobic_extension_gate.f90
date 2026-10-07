module mod_crop_root_anaerobic_extension_gate
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: ROOT_ANOX_GATE_OK = 0
  integer, parameter, public :: ROOT_ANOX_GATE_INVALID_INPUT = 1

  public :: root_extension_allowed_by_daily_oxygen

contains

  subroutine root_extension_allowed_by_daily_oxygen(enabled, daily_deepest_root_oxygen_factor, &
                                                     aeration_critical_factor, allowed, status)
    logical, intent(in) :: enabled
    real(real64), intent(in) :: daily_deepest_root_oxygen_factor
    real(real64), intent(in) :: aeration_critical_factor
    logical, intent(out) :: allowed
    integer, intent(out) :: status

    allowed = .false.
    status = ROOT_ANOX_GATE_INVALID_INPUT
    if (.not. ieee_is_finite(daily_deepest_root_oxygen_factor) .or. &
        .not. ieee_is_finite(aeration_critical_factor)) return
    if (daily_deepest_root_oxygen_factor < 0.0_real64 .or. &
        daily_deepest_root_oxygen_factor > 1.0_real64) return
    if (aeration_critical_factor < 0.0_real64 .or. aeration_critical_factor > 1.0_real64) return

    ! B1.11 MOD_cropdevelopment: when SWWRTNONOX=1,
    ! root extension is stopped iff IALPWET_DAY < AERATECRIT.
    allowed = .true.
    if (enabled .and. daily_deepest_root_oxygen_factor < aeration_critical_factor) allowed = .false.
    status = ROOT_ANOX_GATE_OK
  end subroutine root_extension_allowed_by_daily_oxygen

end module mod_crop_root_anaerobic_extension_gate
