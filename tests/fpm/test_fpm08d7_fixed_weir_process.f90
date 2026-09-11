program test_fpm08d7_fixed_weir_process
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_restricted_fixed_weir_surface_water, only: fixed_weir_surface_water_parameters_t, &
       fixed_weir_surface_water_state_t, fixed_weir_surface_water_forcing_t, &
       fixed_weir_surface_water_numerical_config_t, fixed_weir_surface_water_result_t, &
       evaluate_restricted_fixed_weir_surface_water, fixed_weir_storage_from_level, &
       FIXED_WEIR_AVAILABLE, FIXED_WEIR_INVALID_INPUT, FIXED_WEIR_NO_FEASIBLE_STATE
  implicit none

  type(fixed_weir_surface_water_parameters_t) :: p
  type(fixed_weir_surface_water_state_t) :: s
  type(fixed_weir_surface_water_forcing_t) :: f
  type(fixed_weir_surface_water_numerical_config_t) :: n
  type(fixed_weir_surface_water_result_t) :: r
  real(real64) :: level, storage, dt
  logical :: ok, exact
  integer :: i

  allocate(p%level_knots(22), p%storage_knots(22))
  do i = 1, 22
    p%level_knots(i) = 100.0_real64 - real(i-1,real64) * (200.0_real64/21.0_real64)
    p%storage_knots(i) = 200.0_real64 - real(i-1,real64) * (200.0_real64/21.0_real64)
  end do
  p%storage_knots(22) = 0.0_real64
  p%level_knots(22) = -100.0_real64
  p%weir_head = 0.0_real64
  p%rating_coefficient = 0.5_real64
  p%rating_exponent = 1.5_real64
  p%supply_dip = 10.0_real64
  n%max_bisection_iterations = 160
  n%rating_storage_abs_tolerance = 1.0e-12_real64
  n%rating_storage_rel_tolerance = 1.0e-12_real64
  dt = 0.25_real64

  call fixed_weir_storage_from_level(p, p%level_knots(11), storage, ok, exact)
  call require(ok .and. exact, 'exact knot policy was not explicit')
  call require(storage == p%storage_knots(11), 'exact knot did not return authoritative stored coordinate')

  ! Stable no-discharge route below the weir target.
  s%storage = 80.0_real64
  f%secondary_drainage_rate = 8.0_real64
  f%supply_capacity_rate = 0.0_real64
  call evaluate_restricted_fixed_weir_surface_water(p,n,s,f,dt,r)
  call require(r%status == FIXED_WEIR_AVAILABLE, 'no-discharge route rejected')
  call require(r%discharge_rate == 0.0_real64, 'unexpected discharge below target')
  call require(abs(r%mass_residual) <= 1.0e-13_real64, 'no-discharge mass residual')

  ! Supply route: storage is below h_weir-WLDIP and capacity is sufficient.
  s%storage = 70.0_real64
  f%secondary_drainage_rate = 0.0_real64
  f%supply_capacity_rate = 100.0_real64
  call evaluate_restricted_fixed_weir_surface_water(p,n,s,f,dt,r)
  call require(r%status == FIXED_WEIR_AVAILABLE, 'supply route rejected')
  call require(r%supply_rate > 0.0_real64 .and. r%discharge_rate == 0.0_real64, 'supply route classification')
  call require(abs(r%mass_residual) <= 1.0e-13_real64, 'supply mass residual')

  ! Power-rating discharge route above target.
  s%storage = 130.0_real64
  f%secondary_drainage_rate = 20.0_real64
  f%supply_capacity_rate = 0.0_real64
  call evaluate_restricted_fixed_weir_surface_water(p,n,s,f,dt,r)
  call require(r%status == FIXED_WEIR_AVAILABLE, 'discharge route rejected')
  call require(r%discharge_rate > 0.0_real64, 'discharge route did not discharge')
  call require(abs(r%mass_residual) <= 1.0e-13_real64, 'discharge mass residual')
  call require(abs(r%rating_storage_residual) <= 1.0e-9_real64, 'rating residual too large')

  ! Held negative/infiltration drainage may not enter this restricted candidate.
  s%storage = 100.0_real64
  f%secondary_drainage_rate = -1.0_real64
  f%supply_capacity_rate = 0.0_real64
  call evaluate_restricted_fixed_weir_surface_water(p,n,s,f,dt,r)
  call require(r%status == FIXED_WEIR_INVALID_INPUT, 'negative drainage route was not held')

  ! No feasible state beyond top storage plus rating capacity.
  s%storage = 199.0_real64
  f%secondary_drainage_rate = 1.0e6_real64
  f%supply_capacity_rate = 0.0_real64
  call evaluate_restricted_fixed_weir_surface_water(p,n,s,f,dt,r)
  call require(r%status == FIXED_WEIR_NO_FEASIBLE_STATE, 'overflow route was not fail-closed')

  call fixed_weir_storage_from_level(p, 200.0_real64, storage, ok, exact)
  call require(.not. ok, 'outside mapping domain was accepted')

  level = r%water_level
  write(*,'(A)') 'PASS_FPM08D7_FIXED_WEIR_PROCESS'
  write(*,'(A,ES24.16)') 'LAST_LEVEL=', level
contains
  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(A)') 'FAIL: '//trim(message)
      error stop 1
    end if
  end subroutine require
end program test_fpm08d7_fixed_weir_process
