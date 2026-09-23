module mod_ppa_sol_age_vertical_balance
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_ppa_sol_age_cell_balance, only: ppa_sol_age_cell_candidate, PPA_SOL_AGE_CELL_OK
  implicit none
  private

  integer, parameter, public :: PPA_SOL_AGE_VERTICAL_OK = 0
  integer, parameter, public :: PPA_SOL_AGE_VERTICAL_INVALID_INPUT = 1
  integer, parameter, public :: PPA_SOL_AGE_VERTICAL_ALLOCATION_FAILED = 2
  public :: ppa_sol_age_vertical_candidate

contains

  pure subroutine ppa_sol_age_vertical_candidate(previous_age_storage, face_age_amounts, cell_thickness, &
       water_content, previous_water_content, root_age_rate, lateral_age_rate, interval_days, &
       candidate_age_storage, candidate_age_concentration, status)
    real(real64), intent(in) :: previous_age_storage(:), face_age_amounts(:), cell_thickness(:)
    real(real64), intent(in) :: water_content(:), previous_water_content(:), root_age_rate(:), lateral_age_rate(:)
    real(real64), intent(in) :: interval_days
    real(real64), allocatable, intent(out) :: candidate_age_storage(:), candidate_age_concentration(:)
    integer, intent(out) :: status
    real(real64), allocatable :: local_storage(:), local_concentration(:)
    integer :: n, i, allocation_status, cell_status

    status = PPA_SOL_AGE_VERTICAL_INVALID_INPUT
    n = size(previous_age_storage)
    if (n <= 0 .or. size(face_age_amounts) /= n + 1 .or. size(cell_thickness) /= n .or. &
        size(water_content) /= n .or. size(previous_water_content) /= n .or. size(root_age_rate) /= n .or. &
        size(lateral_age_rate) /= n) return
    if (.not. all(ieee_is_finite(previous_age_storage)) .or. .not. all(ieee_is_finite(face_age_amounts)) .or. &
        .not. all(ieee_is_finite(cell_thickness)) .or. .not. all(ieee_is_finite(water_content)) .or. &
        .not. all(ieee_is_finite(previous_water_content)) .or. .not. all(ieee_is_finite(root_age_rate)) .or. &
        .not. all(ieee_is_finite(lateral_age_rate)) .or. .not. ieee_is_finite(interval_days)) return
    if (interval_days <= 0.0_real64 .or. any(cell_thickness <= 0.0_real64) .or. any(water_content <= 0.0_real64)) return

    allocate(local_storage(n), local_concentration(n), stat=allocation_status)
    if (allocation_status /= 0) then
      status = PPA_SOL_AGE_VERTICAL_ALLOCATION_FAILED
      return
    end if
    do i = 1, n
      call ppa_sol_age_cell_candidate(previous_age_storage(i), face_age_amounts(i + 1), face_age_amounts(i), &
           cell_thickness(i), water_content(i), previous_water_content(i), root_age_rate(i), lateral_age_rate(i), &
           interval_days, local_storage(i), local_concentration(i), cell_status)
      if (cell_status /= PPA_SOL_AGE_CELL_OK) return
    end do
    call move_alloc(local_storage, candidate_age_storage)
    call move_alloc(local_concentration, candidate_age_concentration)
    status = PPA_SOL_AGE_VERTICAL_OK
  end subroutine ppa_sol_age_vertical_candidate

end module mod_ppa_sol_age_vertical_balance
