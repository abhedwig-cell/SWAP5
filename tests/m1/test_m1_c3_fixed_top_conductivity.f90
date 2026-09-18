program test_m1_c3_fixed_top_conductivity
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, initialize_b110_default_mvg_parameters, &
       evaluate_b110_default_mvg_conductivity
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t, &
       b110_dynamic_top_boundary_result_t, evaluate_b110_dynamic_top_boundary, B110_DYN_TOP_AVAILABLE, &
       B110_DYN_TOP_ATMOSPHERIC_HEAD_CM
  implicit none

  type(soil_water_parameter_set_t) :: geometry
  type(b110_default_mvg_parameters_t) :: hydraulics
  type(b110_dynamic_top_boundary_request_t) :: request, explicit_default, fixed_request
  type(b110_dynamic_top_boundary_result_t) :: baseline, default_repeat, fixed_result
  real(real64) :: cofgen(24,1), k_old, k_atm, expected_emax
  logical :: ok

  cofgen = 0.0_real64
  cofgen(1,1) = 0.032_real64
  cofgen(2,1) = 0.423_real64
  cofgen(3,1) = 4.75_real64
  cofgen(4,1) = 0.0135_real64
  cofgen(5,1) = 0.365_real64
  cofgen(6,1) = 1.455_real64
  cofgen(7,1) = 1.0_real64 - 1.0_real64/cofgen(6,1)
  cofgen(8,1) = cofgen(4,1)
  cofgen(9,1) = 0.0_real64
  cofgen(10,1) = 637.2_real64
  cofgen(11,1) = 0.999_real64
  cofgen(12,1) = 0.99_real64*cofgen(3,1)
  cofgen(22,1) = -1.0e6_real64
  cofgen(23,1) = 1.0e-12_real64
  call initialize_b110_default_mvg_parameters(hydraulics, cofgen, .true.)

  geometry%parameter_set_id = 1_int64
  geometry%active_nodes = 1
  allocate(geometry%z(1), geometry%dz(1), geometry%node_distance(1))
  geometry%z = -1.0_real64
  geometry%dz = 2.0_real64
  geometry%node_distance = 1.0_real64

  request%conductivity_mean_method = 1
  request%pressure_head_top_cm = -0.05_real64
  request%water_content_top = 0.4_real64
  request%step_duration_day = 0.001_real64
  request%ponding_max_cm = 0.0_real64
  request%runoff_resistance_day = 0.0_real64

  call evaluate_b110_dynamic_top_boundary(geometry, hydraulics, request, baseline)
  if (baseline%status /= B110_DYN_TOP_AVAILABLE) error stop 'M1C3 baseline dynamic top unavailable'

  explicit_default = request
  explicit_default%fixed_top_node_conductivity_cm_per_day = -1.0_real64
  call evaluate_b110_dynamic_top_boundary(geometry, hydraulics, explicit_default, default_repeat)
  if (default_repeat%status /= B110_DYN_TOP_AVAILABLE) error stop 'M1C3 explicit default unavailable'
  if (baseline%evaporation_capacity_cm_per_day /= default_repeat%evaporation_capacity_cm_per_day) &
       error stop 'M1C3 default semantics changed'

  call evaluate_b110_default_mvg_conductivity(hydraulics, 1, -0.5_real64, k_old, ok)
  if (.not. ok) error stop 'M1C3 frozen top conductivity unavailable'
  call evaluate_b110_default_mvg_conductivity(hydraulics, 1, B110_DYN_TOP_ATMOSPHERIC_HEAD_CM, k_atm, ok)
  if (.not. ok) error stop 'M1C3 atmospheric conductivity unavailable'

  fixed_request = request
  fixed_request%fixed_top_node_conductivity_cm_per_day = k_old
  call evaluate_b110_dynamic_top_boundary(geometry, hydraulics, fixed_request, fixed_result)
  if (fixed_result%status /= B110_DYN_TOP_AVAILABLE) error stop 'M1C3 fixed-top dynamic boundary unavailable'

  expected_emax = -0.5_real64*(k_atm+k_old) * &
       ((B110_DYN_TOP_ATMOSPHERIC_HEAD_CM-request%pressure_head_top_cm)/geometry%node_distance(1) + 1.0_real64)
  if (abs(fixed_result%evaporation_capacity_cm_per_day-expected_emax) > &
       64.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(expected_emax))) &
       error stop 'M1C3 fixed-top legacy conductivity not honored'
  if (fixed_result%evaporation_capacity_cm_per_day == baseline%evaporation_capacity_cm_per_day) &
       error stop 'M1C3 fixed-top opt-in did not change iterative conductivity use'

  print '(A)', 'M1C3_FIXED_TOP_DEFAULT_PRESERVATION=PASS'
  print '(A)', 'M1C3_FIXED_TOP_LEGACY_SEMANTIC=PASS'
end program test_m1_c3_fixed_top_conductivity
