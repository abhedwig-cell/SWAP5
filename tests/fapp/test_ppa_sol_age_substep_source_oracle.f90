program test_ppa_sol_age_substep_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_sol_age_substep
  implicit none

  integer, parameter :: node_count = 5, level_count = 3, vector_count = 100000
  integer(int64) :: state
  integer :: i, j, status
  real(real64) :: old_storage(node_count), concentration(node_count), qface(node_count + 1)
  real(real64) :: upper_weight(node_count + 1), lower_weight(node_count + 1), theta_face(node_count + 1)
  real(real64) :: dispersion(node_count + 1), distance(node_count + 1), theta(node_count), theta_old(node_count)
  real(real64) :: dz(node_count), qroot(node_count), qdrain(level_count, node_count)
  real(real64) :: age_drain, top_amount, dt, expected_storage(node_count), expected_concentration(node_count), nan_value
  real(real64), allocatable :: actual_storage(:), actual_concentration(:), bad_lateral(:,:)

  state = 20260923_int64
  do i = 1, vector_count
    call generate_profile(state, old_storage, concentration, qface, upper_weight, lower_weight, theta_face, &
         dispersion, distance, theta, theta_old, dz, qroot, qdrain, age_drain, top_amount, dt)
    call source_sequential_age_substep(old_storage, concentration, qface, upper_weight, lower_weight, theta_face, &
         dispersion, distance, theta, theta_old, dz, qroot, qdrain, age_drain, top_amount, dt, &
         expected_storage, expected_concentration)
    call ppa_sol_age_substep_candidate(old_storage, concentration, qface, upper_weight, lower_weight, theta_face, &
         dispersion, distance, theta, theta_old, dz, qroot, qdrain, age_drain, top_amount, dt, &
         actual_storage, actual_concentration, status)
    call require(status == PPA_SOL_AGE_SUBSTEP_OK, 1)
    do j = 1, node_count
      call compare_real(expected_storage(j), actual_storage(j), 2)
      call compare_real(expected_concentration(j), actual_concentration(j), 3)
    end do
  end do

  write(*,'(a)') 'PPA_SOL_AGE_SUBSTEP_B1_11_SOURCE_ORACLE_100000x5=PASS'
  write(*,'(a)') 'PPA_SOL_AGE_SUBSTEP_UPDATED_UPPER_FACE_ORDER=PASS'
  write(*,'(a)') 'PPA_SOL_AGE_SUBSTEP_BOTTOM_ROOT_AND_LATERAL_BRANCHES=PASS'

  call ppa_sol_age_substep_candidate(old_storage, concentration, qface, upper_weight, lower_weight, theta_face, &
       dispersion, distance, theta, theta_old, dz, qroot, qdrain(:,1:node_count-1), age_drain, top_amount, dt, &
       actual_storage, actual_concentration, status)
  call require(status == PPA_SOL_AGE_SUBSTEP_INVALID_INPUT, 4)
  nan_value = ieee_value(0.0_real64, ieee_quiet_nan)
  bad_lateral = qdrain
  bad_lateral(2, 2) = nan_value
  call ppa_sol_age_substep_candidate(old_storage, concentration, qface, upper_weight, lower_weight, theta_face, &
       dispersion, distance, theta, theta_old, dz, qroot, bad_lateral, age_drain, top_amount, dt, &
       actual_storage, actual_concentration, status)
  call require(status == PPA_SOL_AGE_SUBSTEP_INVALID_INPUT, 5)
  distance(3) = 0.0_real64
  call ppa_sol_age_substep_candidate(old_storage, concentration, qface, upper_weight, lower_weight, theta_face, &
       dispersion, distance, theta, theta_old, dz, qroot, qdrain, age_drain, top_amount, dt, &
       actual_storage, actual_concentration, status)
  call require(status == PPA_SOL_AGE_SUBSTEP_INVALID_INPUT, 6)
  call require(.not. allocated(actual_storage) .and. .not. allocated(actual_concentration), 7)
  write(*,'(a)') 'PPA_SOL_AGE_SUBSTEP_INVALID_INPUT_FAIL_CLOSED=PASS'

contains

  subroutine generate_profile(random_state, old, age, q, wa, wb, wf, disp, dist, water, water_old, thickness, &
       root, drain, drain_age, top, step)
    integer(int64), intent(inout) :: random_state
    real(real64), intent(out) :: old(:), age(:), q(:), wa(:), wb(:), wf(:), disp(:), dist(:)
    real(real64), intent(out) :: water(:), water_old(:), thickness(:), root(:), drain(:,:)
    real(real64), intent(out) :: drain_age, top, step
    integer :: k, l

    do k = 1, size(old)
      age(k) = 15.0_real64 * next_unit(random_state)
      water(k) = 0.08_real64 + 0.45_real64 * next_unit(random_state)
      water_old(k) = 0.08_real64 + 0.45_real64 * next_unit(random_state)
      old(k) = age(k) * water(k)
      thickness(k) = 0.1_real64 + 2.0_real64 * next_unit(random_state)
      root(k) = 0.04_real64 * next_unit(random_state)
      do l = 1, size(drain, 1)
        drain(l, k) = -0.02_real64 + 0.04_real64 * next_unit(random_state)
      end do
    end do
    do k = 1, size(q)
      q(k) = -0.3_real64 + 0.6_real64 * next_unit(random_state)
      wa(k) = 0.1_real64 + 0.8_real64 * next_unit(random_state)
      wb(k) = 0.1_real64 + 0.8_real64 * next_unit(random_state)
      wf(k) = 0.08_real64 + 0.45_real64 * next_unit(random_state)
      disp(k) = 0.3_real64 * next_unit(random_state)
      dist(k) = 0.1_real64 + 1.5_real64 * next_unit(random_state)
    end do
    drain_age = 15.0_real64 * next_unit(random_state)
    top = -0.03_real64 + 0.06_real64 * next_unit(random_state)
    step = 0.001_real64 + 0.1_real64 * next_unit(random_state)
  end subroutine generate_profile

  real(real64) function next_unit(random_state) result(value)
    integer(int64), intent(inout) :: random_state
    random_state = modulo(random_state * 48271_int64, 2147483647_int64)
    value = real(modulo(random_state, 1000000_int64), real64) / 1000000.0_real64
  end function next_unit

  subroutine source_sequential_age_substep(old, age, q, wa, wb, wf, disp, dist, water, water_old, thickness, &
       root, drain, drain_age, initial_top, step, new_storage, new_age)
    real(real64), intent(in) :: old(:), age(:), q(:), wa(:), wb(:), wf(:), disp(:), dist(:)
    real(real64), intent(in) :: water(:), water_old(:), thickness(:), root(:), drain(:,:), drain_age, initial_top, step
    real(real64), intent(out) :: new_storage(:), new_age(:)
    real(real64) :: flux_bottom, flux_top, age_lateral, age_root, age_prod
    integer :: k, l

    new_storage = old
    new_age = age
    flux_top = initial_top
    do k = 1, size(age)
      if (k < size(age)) then
        flux_bottom = (q(k + 1) * (wa(k + 1) * new_age(k) + wb(k) * new_age(k + 1)) + &
             wf(k + 1) * disp(k + 1) * (new_age(k + 1) - new_age(k)) / dist(k + 1)) * step
      else if (q(size(age) + 1) > 0.0_real64) then
        flux_bottom = q(size(age) + 1) * drain_age * step
      else
        flux_bottom = q(size(age) + 1) * new_age(size(age)) * step
      end if
      age_root = root(k) * new_age(k) / thickness(k)
      age_lateral = 0.0_real64
      do l = 1, size(drain, 1)
        if (drain(l, k) > 0.0_real64) then
          age_lateral = age_lateral + drain(l, k) * new_age(k) / thickness(k)
        else
          age_lateral = age_lateral + drain(l, k) * drain_age / thickness(k)
        end if
      end do
      age_prod = 1.0_real64 * 0.5_real64 * (water(k) + water_old(k))
      new_storage(k) = new_storage(k) + (flux_bottom - flux_top) / thickness(k) + &
           (-age_root - age_lateral + age_prod) * step
      new_age(k) = new_storage(k) / water(k)
      flux_top = flux_bottom
    end do
  end subroutine source_sequential_age_substep

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
    write(*,'(a,i0)') 'PPA_SOL_AGE_SUBSTEP_FAIL=', code
    error stop 1
  end subroutine require

end program test_ppa_sol_age_substep_source_oracle
