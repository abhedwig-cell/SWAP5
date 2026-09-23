program emit_sw_rib_swm01_q1a_oracle
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_restricted_fixed_weir_surface_water, only: fixed_weir_surface_water_parameters_t, &
       fixed_weir_surface_water_state_t, fixed_weir_surface_water_forcing_t, &
       fixed_weir_surface_water_numerical_config_t, fixed_weir_surface_water_result_t, &
       evaluate_restricted_fixed_weir_surface_water, FIXED_WEIR_AVAILABLE
  implicit none

  type(fixed_weir_surface_water_parameters_t) :: p
  type(fixed_weir_surface_water_state_t) :: s
  type(fixed_weir_surface_water_forcing_t) :: f
  type(fixed_weir_surface_water_numerical_config_t) :: n
  type(fixed_weir_surface_water_result_t) :: r
  real(real64), parameter :: dt_day = 1.0e-4_real64
  integer :: i

  allocate(p%level_knots(22), p%storage_knots(22))
  do i = 1, 22
    p%level_knots(i) = 100.0_real64 - real(i-1,real64) * (200.0_real64/21.0_real64)
    p%storage_knots(i) = 200.0_real64 - real(i-1,real64) * (200.0_real64/21.0_real64)
  end do
  p%level_knots(22) = -100.0_real64
  p%storage_knots(22) = 0.0_real64
  p%weir_head = 0.0_real64
  p%rating_coefficient = 0.5_real64
  p%rating_exponent = 1.0_real64
  p%supply_dip = 10.0_real64

  n%max_bisection_iterations = 160
  n%rating_storage_abs_tolerance = 1.0e-12_real64
  n%rating_storage_rel_tolerance = 1.0e-12_real64

  call run_case('C0_NO_DISCHARGE', 80.0_real64, -20.0_real64, 8.0_real64)
  call run_case('C1_MODERATE_DISCHARGE', 130.0_real64, 30.0_real64, 20.0_real64)
  call run_case('C2_HIGH_DISCHARGE', 170.0_real64, 70.0_real64, 5.0_real64)

  write(*,'(A)') 'SW_RIB_SWM01_Q1A_ORACLE_EMISSION=PASS'

contains

  subroutine run_case(id, initial_storage_cm, initial_level_cm, drainage_cm_day)
    character(len=*), intent(in) :: id
    real(real64), intent(in) :: initial_storage_cm, initial_level_cm, drainage_cm_day

    s%storage = initial_storage_cm
    f%secondary_drainage_rate = drainage_cm_day
    f%supply_capacity_rate = 0.0_real64

    call evaluate_restricted_fixed_weir_surface_water(p,n,s,f,dt_day,r)
    if (r%status /= FIXED_WEIR_AVAILABLE) then
      write(*,'(A,1X,A,1X,I0)') 'SW_RIB_SWM01_Q1A_ORACLE_FAIL', trim(id), r%status
      error stop 1
    end if

    if (abs((initial_storage_cm - 100.0_real64) - initial_level_cm) > 1.0e-12_real64) then
      error stop 'initial level/storage mapping drift'
    end if

    write(*,'(A,",",A,",",ES24.16,",",ES24.16,",",ES24.16,",",ES24.16,",",ES24.16,",",ES24.16,",",ES24.16)') &
         'Q1A_CASE', trim(id), initial_storage_cm, initial_level_cm, drainage_cm_day, &
         r%candidate_state%storage, r%water_level, r%discharge_rate, r%mass_residual
  end subroutine run_case
end program emit_sw_rib_swm01_q1a_oracle
