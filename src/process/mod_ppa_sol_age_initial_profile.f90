module mod_ppa_sol_age_initial_profile
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_SOL_AGE_INIT_OK = 0
  integer, parameter, public :: PPA_SOL_AGE_INIT_INVALID_INPUT = 1
  public :: ppa_sol_age_afgen2_candidate, ppa_sol_age_initialize_profile

contains

  pure subroutine ppa_sol_age_afgen2_candidate(table, depth, cursor, age, next_cursor, status)
    real(real64), intent(in) :: table(:), depth
    integer, intent(in) :: cursor
    real(real64), intent(out) :: age
    integer, intent(out) :: next_cursor, status
    integer :: i, n
    real(real64) :: slope

    age = 0.0_real64
    next_cursor = cursor
    status = PPA_SOL_AGE_INIT_INVALID_INPUT
    n = size(table)
    if (n < 4 .or. mod(n, 2) /= 0 .or. cursor < 0 .or. (cursor > 0 .and. mod(cursor, 2) == 0) .or. &
        cursor > n - 1) return
    if (.not. ieee_is_finite(depth) .or. .not. all(ieee_is_finite(table))) return
    if (depth < 0.0_real64) return

    if (table(1) >= depth) then
      age = table(2)
      next_cursor = 1
      status = PPA_SOL_AGE_INIT_OK
      return
    end if
    do i = max(3, cursor), n - 1, 2
      if (table(i) >= depth) then
        slope = (table(i + 1) - table(i - 1)) / (table(i) - table(i - 2))
        age = table(i - 1) + (depth - table(i - 2)) * slope
        next_cursor = i - 2
        status = PPA_SOL_AGE_INIT_OK
        return
      end if
      if (table(i) < table(i - 2)) then
        age = table(i - 1)
        next_cursor = i - 2
        status = PPA_SOL_AGE_INIT_OK
        return
      end if
    end do
    age = table(n)
    next_cursor = n - 1
    status = PPA_SOL_AGE_INIT_OK
  end subroutine ppa_sol_age_afgen2_candidate

  pure subroutine ppa_sol_age_initialize_profile(table, node_depth, initial_age, status)
    real(real64), intent(in) :: table(:), node_depth(:)
    real(real64), allocatable, intent(out) :: initial_age(:)
    integer, intent(out) :: status
    real(real64), allocatable :: candidate(:)
    integer :: i, cursor, next_cursor, local_status, allocation_status

    status = PPA_SOL_AGE_INIT_INVALID_INPUT
    if (size(node_depth) <= 0 .or. size(table) < 4 .or. mod(size(table), 2) /= 0) return
    if (.not. all(ieee_is_finite(node_depth))) return
    if (any(node_depth < 0.0_real64)) return
    allocate(candidate(size(node_depth)), stat=allocation_status)
    if (allocation_status /= 0) return
    cursor = 0
    do i = 1, size(node_depth)
      call ppa_sol_age_afgen2_candidate(table, node_depth(i), cursor, candidate(i), next_cursor, local_status)
      if (local_status /= PPA_SOL_AGE_INIT_OK) return
      cursor = next_cursor
    end do
    call move_alloc(candidate, initial_age)
    status = PPA_SOL_AGE_INIT_OK
  end subroutine ppa_sol_age_initialize_profile

end module mod_ppa_sol_age_initial_profile
