module mod_ppa_sol_age_report
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_SOL_AGE_REPORT_OK = 0
  integer, parameter, public :: PPA_SOL_AGE_REPORT_INVALID_INPUT = 1
  public :: ppa_sol_age_report_values

contains

  pure subroutine ppa_sol_age_report_values(age_profile, age_bottom_accumulator, age_root_accumulator, &
       age_surface_accumulator, age_drain_accumulator, output_interval, drainage_inflow, report_profile, &
       age_bottom_rate, age_root_rate, age_surface_rate, age_drain_rate, positive_drainage_rate, status)
    real(real64), intent(in) :: age_profile(:), age_bottom_accumulator, age_root_accumulator, age_surface_accumulator
    real(real64), intent(in) :: age_drain_accumulator(:), output_interval, drainage_inflow(:,:)
    real(real64), allocatable, intent(out) :: report_profile(:), age_drain_rate(:), positive_drainage_rate(:)
    real(real64), intent(out) :: age_bottom_rate, age_root_rate, age_surface_rate
    integer, intent(out) :: status
    real(real64), allocatable :: local_profile(:), local_drain_rate(:), local_positive_rate(:)
    integer :: nlevel, nnode, level, node, allocation_status

    age_bottom_rate = 0.0_real64
    age_root_rate = 0.0_real64
    age_surface_rate = 0.0_real64
    status = PPA_SOL_AGE_REPORT_INVALID_INPUT
    nlevel = size(age_drain_accumulator)
    nnode = size(age_profile)
    if (nnode <= 0 .or. nlevel <= 0 .or. size(drainage_inflow, 1) /= nlevel) return
    if (.not. ieee_is_finite(age_bottom_accumulator) .or. .not. ieee_is_finite(age_root_accumulator) .or. &
        .not. ieee_is_finite(age_surface_accumulator) .or. .not. ieee_is_finite(output_interval) .or. &
        .not. all(ieee_is_finite(age_profile)) .or. .not. all(ieee_is_finite(age_drain_accumulator)) .or. &
        .not. all(ieee_is_finite(drainage_inflow))) return
    if (output_interval <= 0.0_real64) return

    allocate(local_profile(nnode), local_drain_rate(nlevel), local_positive_rate(nlevel), stat=allocation_status)
    if (allocation_status /= 0) return
    local_profile = age_profile
    age_bottom_rate = age_bottom_accumulator / output_interval
    age_root_rate = age_root_accumulator / output_interval
    age_surface_rate = age_surface_accumulator / output_interval
    local_drain_rate = age_drain_accumulator / output_interval
    local_positive_rate = 0.0_real64
    do level = 1, nlevel
      do node = 1, size(drainage_inflow, 2)
        if (drainage_inflow(level, node) > 0.0_real64) then
          local_positive_rate(level) = local_positive_rate(level) + drainage_inflow(level, node)
        end if
      end do
    end do
    if (.not. all(ieee_is_finite(local_profile)) .or. .not. all(ieee_is_finite(local_drain_rate)) .or. &
        .not. all(ieee_is_finite(local_positive_rate)) .or. .not. ieee_is_finite(age_bottom_rate) .or. &
        .not. ieee_is_finite(age_root_rate) .or. .not. ieee_is_finite(age_surface_rate)) then
      age_bottom_rate = 0.0_real64
      age_root_rate = 0.0_real64
      age_surface_rate = 0.0_real64
      return
    end if
    call move_alloc(local_profile, report_profile)
    call move_alloc(local_drain_rate, age_drain_rate)
    call move_alloc(local_positive_rate, positive_drainage_rate)
    status = PPA_SOL_AGE_REPORT_OK
  end subroutine ppa_sol_age_report_values

end module mod_ppa_sol_age_report
