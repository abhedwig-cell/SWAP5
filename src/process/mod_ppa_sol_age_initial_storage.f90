module mod_ppa_sol_age_initial_storage
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: PPA_SOL_AGE_STORAGE_OK = 0
  integer, parameter, public :: PPA_SOL_AGE_STORAGE_INVALID_INPUT = 1
  public :: ppa_sol_age_initial_storage
contains
  pure subroutine ppa_sol_age_initial_storage(age_concentration, water_content, cell_thickness, age_storage, total_age, status)
    real(real64), intent(in) :: age_concentration(:), water_content(:), cell_thickness(:)
    real(real64), allocatable, intent(out) :: age_storage(:)
    real(real64), intent(out) :: total_age
    integer, intent(out) :: status
    real(real64), allocatable :: candidate(:)
    integer :: i, n, allocation_status

    total_age = 0.0_real64
    status = PPA_SOL_AGE_STORAGE_INVALID_INPUT
    n = size(age_concentration)
    if (n <= 0 .or. size(water_content) /= n .or. size(cell_thickness) /= n) return
    if (.not. all(ieee_is_finite(age_concentration)) .or. .not. all(ieee_is_finite(water_content)) .or. &
        .not. all(ieee_is_finite(cell_thickness))) return
    if (any(water_content <= 0.0_real64) .or. any(cell_thickness <= 0.0_real64)) return
    allocate(candidate(n), stat=allocation_status)
    if (allocation_status /= 0) return
    total_age = 0.0_real64
    do i = 1, n
      candidate(i) = water_content(i) * age_concentration(i)
      total_age = total_age + candidate(i) * cell_thickness(i)
    end do
    if (.not. all(ieee_is_finite(candidate)) .or. .not. ieee_is_finite(total_age)) then
      total_age = 0.0_real64
      return
    end if
    call move_alloc(candidate, age_storage)
    status = PPA_SOL_AGE_STORAGE_OK
  end subroutine ppa_sol_age_initial_storage
end module mod_ppa_sol_age_initial_storage
