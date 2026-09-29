program test_ppa_sol_age_vertical_balance_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_sol_age_vertical_balance
  implicit none

  integer, parameter :: cell_count = 6, vector_count = 100000
  integer(int64) :: state
  integer :: i, j, status
  real(real64) :: old_storage(cell_count), faces(cell_count + 1), dz(cell_count)
  real(real64) :: theta(cell_count), theta_old(cell_count), root(cell_count), lateral(cell_count), dt
  real(real64) :: expected_storage(cell_count), expected_concentration(cell_count), nan_value
  real(real64), allocatable :: actual_storage(:), actual_concentration(:), invalid_storage(:)

  state = 20260923_int64
  do i = 1, vector_count
    do j = 1, cell_count
      old_storage(j) = 8.0_real64 * next_unit(state)
      dz(j) = 0.05_real64 + 5.0_real64 * next_unit(state)
      theta(j) = 0.05_real64 + 0.55_real64 * next_unit(state)
      theta_old(j) = 0.05_real64 + 0.55_real64 * next_unit(state)
      root(j) = 0.15_real64 * next_unit(state)
      lateral(j) = 0.15_real64 * next_unit(state)
    end do
    do j = 1, cell_count + 1
      faces(j) = -0.08_real64 + 0.16_real64 * next_unit(state)
    end do
    dt = 0.001_real64 + 0.25_real64 * next_unit(state)
    if (mod(i, 4) == 0) faces(cell_count + 1) = faces(1)
    if (mod(i, 4) == 1) root(1) = 0.0_real64

    call source_ordered_vertical_update(old_storage, faces, dz, theta, theta_old, root, lateral, dt, &
         expected_storage, expected_concentration)
    call ppa_sol_age_vertical_candidate(old_storage, faces, dz, theta, theta_old, root, lateral, dt, &
         actual_storage, actual_concentration, status)
    call require(status == PPA_SOL_AGE_VERTICAL_OK, 1)
    call require(allocated(actual_storage) .and. allocated(actual_concentration), 2)
    do j = 1, cell_count
      call compare_real(expected_storage(j), actual_storage(j), 3)
      call compare_real(expected_concentration(j), actual_concentration(j), 4)
    end do
  end do

  write(*,'(a)') 'PPA_SOL_AGE_VERTICAL_SOURCE_ORACLE_100000x6=PASS'
  write(*,'(a)') 'PPA_SOL_AGE_VERTICAL_FACE_TO_CELL_CANDIDATE_ORDER=PASS'

  call ppa_sol_age_vertical_candidate(old_storage, faces(1:cell_count), dz, theta, theta_old, root, lateral, dt, &
       actual_storage, actual_concentration, status)
  call require(status == PPA_SOL_AGE_VERTICAL_INVALID_INPUT, 5)
  nan_value = ieee_value(0.0_real64, ieee_quiet_nan)
  invalid_storage = old_storage
  invalid_storage(3) = nan_value
  call ppa_sol_age_vertical_candidate(invalid_storage, faces, dz, theta, theta_old, root, lateral, dt, &
       actual_storage, actual_concentration, status)
  call require(status == PPA_SOL_AGE_VERTICAL_INVALID_INPUT, 6)
  dz(2) = 0.0_real64
  call ppa_sol_age_vertical_candidate(old_storage, faces, dz, theta, theta_old, root, lateral, dt, &
       actual_storage, actual_concentration, status)
  call require(status == PPA_SOL_AGE_VERTICAL_INVALID_INPUT, 7)
  call require(.not. allocated(actual_storage) .and. .not. allocated(actual_concentration), 8)
  write(*,'(a)') 'PPA_SOL_AGE_VERTICAL_INVALID_VECTOR_FAIL_CLOSED=PASS'

contains

  real(real64) function next_unit(random_state) result(value)
    integer(int64), intent(inout) :: random_state
    random_state = modulo(random_state * 48271_int64, 2147483647_int64)
    value = real(modulo(random_state, 1000000_int64), real64) / 1000000.0_real64
  end function next_unit

  subroutine source_ordered_vertical_update(old, face_amounts, thickness, water, water_old, uptake, drain, step, &
       new_storage, new_concentration)
    real(real64), intent(in) :: old(:), face_amounts(:), thickness(:), water(:), water_old(:), uptake(:), drain(:), step
    real(real64), intent(out) :: new_storage(:), new_concentration(:)
    real(real64) :: age_prod
    integer :: node

    do node = 1, size(old)
      age_prod = 1.0_real64 * 0.5_real64 * (water(node) + water_old(node))
      new_storage(node) = old(node) + (face_amounts(node + 1) - face_amounts(node)) / thickness(node) + &
           (-uptake(node) - drain(node) + age_prod) * step
      new_concentration(node) = new_storage(node) / water(node)
    end do
  end subroutine source_ordered_vertical_update

  subroutine compare_real(expected, actual, code)
    real(real64), intent(in) :: expected, actual
    integer, intent(in) :: code
    integer(int64) :: expected_bits, actual_bits
    expected_bits = transfer(expected, expected_bits)
    actual_bits = transfer(actual, actual_bits)
    call require(expected_bits == actual_bits, code)
  end subroutine compare_real

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (condition) return
    write(*,'(a,i0)') 'PPA_SOL_AGE_VERTICAL_FAIL=', code
    error stop 1
  end subroutine require

end program test_ppa_sol_age_vertical_balance_source_oracle
