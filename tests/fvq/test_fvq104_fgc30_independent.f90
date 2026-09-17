program test_fvq104_fgc30_independent
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_head_datum_t, &
       groundwater_interface_state_t
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t, soil_water_parameter_set_t
  use mod_soil_water_accepted_step_direction_contract, only: SW_STEP_CONTROL_BOTTOM_FLUX
  use mod_accepted_trajectory_directional_publication, only: accepted_trajectory_direction_result_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_modflow6_swap_prescribed_qbot_bottom_face, only: modflow6_prescribed_qbot_bottom_face_t, &
       materialize_modflow6_prescribed_qbot_bottom_face, MODFLOW6_BOTTOM_FACE_OK
  use mod_modflow6_swap_predictor_response, only: modflow6_swap_predictor_lineage_t, &
       modflow6_swap_predictor_response_t, modflow6_derivative_coverage_t, &
       compose_modflow6_swap_predictor_response, MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT, &
       MODFLOW6_PREDICTOR_OK, MODFLOW6_PREDICTOR_INCOMPLETE_DERIVATIVE_COVERAGE
  use mod_modflow6_swap_predictor_tangent_adapter, only: modflow6_swap_predictor_tangent_endpoint_t, &
       build_modflow6_swap_predictor_tangent_endpoint, MODFLOW6_TANGENT_ENDPOINT_OK, &
       MODFLOW6_TANGENT_ENDPOINT_INCOMPLETE_COVERAGE
  use mod_modflow6_swap_predictor_origin, only: modflow6_swap_predictor_origin_t, &
       capture_modflow6_swap_predictor_origin, MODFLOW6_PREDICTOR_ORIGIN_OK, &
       MODFLOW6_PREDICTOR_ORIGIN_NOT_COMMITTED, MODFLOW6_PREDICTOR_ORIGIN_NONCONSERVATIVE_INTERFACE
  implicit none

  integer, parameter :: n = 2
  real(real64), parameter :: eps = 1.0e-6_real64
  real(real64), parameter :: tol = 2.0e-6_real64
  real(real64), parameter :: day_to_s = 86400.0_real64
  real(real64), parameter :: cm_to_m = 0.01_real64

  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t) :: constitutive
  type(soil_water_physical_state_t) :: state
  type(soil_water_parameter_set_t) :: parameters
  type(accepted_trajectory_direction_result_t) :: trajectory
  type(groundwater_head_datum_t) :: datum
  type(modflow6_swap_predictor_tangent_endpoint_t) :: endpoint, blocked
  type(modflow6_prescribed_qbot_bottom_face_t) :: plus_face, minus_face
  type(modflow6_derivative_coverage_t) :: coverage
  type(modflow6_swap_predictor_lineage_t) :: lineage
  type(modflow6_swap_predictor_response_t) :: response
  type(groundwater_coupling_window_t) :: window
  type(groundwater_interface_state_t) :: accepted_interface
  type(modflow6_swap_predictor_origin_t) :: origin
  real(real64) :: cofgen(24,n), theta(n), conductivity(n), capacity(n), dkdh(n)
  real(real64) :: hp_plus(n), hp_minus(n), kplus(n), kminus(n), dummy(n), dummy2(n), dummy3(n)
  real(real64) :: qbot, fd, scale, expected_u, expected_qu
  integer :: i, status

  cofgen = 0.0_real64
  do i = 1, n
    cofgen(1,i)=0.032_real64
    cofgen(2,i)=0.423_real64
    cofgen(3,i)=4.75_real64
    cofgen(4,i)=0.0135_real64
    cofgen(5,i)=0.365_real64
    cofgen(6,i)=1.455_real64
    cofgen(7,i)=1.0_real64-1.0_real64/cofgen(6,i)
    cofgen(8,i)=cofgen(4,i)
    cofgen(9,i)=0.0_real64
    cofgen(10,i)=cofgen(3,i)
    cofgen(11,i)=0.999_real64
    cofgen(12,i)=0.99_real64*cofgen(3,i)
    cofgen(22,i)=-1.0e6_real64
    cofgen(23,i)=1.0e-12_real64
  end do
  call initialize_b110_default_mvg_parameters(hp, cofgen)
  call bind_b110_default_mvg_provider(constitutive, hp, 0.1_real64)

  state%active_nodes = n
  allocate(state%pressure_head(n), state%water_content(n))
  state%pressure_head = [-80.0_real64, -70.0_real64]
  call constitutive%evaluate(state%pressure_head, theta, conductivity, capacity, dkdh)
  state%water_content = theta
  state%ponding_depth = 0.0_real64
  state%groundwater_level = -1.5_real64

  parameters%parameter_set_id = 104030_int64
  parameters%active_nodes = n
  allocate(parameters%z(n), parameters%dz(n), parameters%node_distance(n))
  parameters%z = [-5.0_real64, -15.0_real64]
  parameters%dz = [10.0_real64, 10.0_real64]
  parameters%node_distance = [0.0_real64, 10.0_real64]

  trajectory%requested = .true.
  trajectory%available = .true.
  trajectory%worker_id = 104
  trajectory%generation = 7_int64
  trajectory%control_coordinate = SW_STEP_CONTROL_BOTTOM_FLUX
  trajectory%accepted_steps = 2
  trajectory%origin_t0 = 2.0_real64
  trajectory%accepted_t1 = 2.25_real64
  allocate(trajectory%final_pressure_head_direction(n), trajectory%final_water_content_direction(n))
  trajectory%final_pressure_head_direction = [0.15_real64, 0.20_real64]
  trajectory%final_water_content_direction = 0.0_real64
  trajectory%method = 'fvq104-independent-synthetic-direction'
  trajectory%route = 'fvq104-independent'

  datum%available = .true.
  datum%datum_id = 104_int64
  datum%bottom_boundary_elevation_m = -2.0_real64
  qbot = 0.1_real64

  call build_modflow6_swap_predictor_tangent_endpoint(state, parameters, constitutive, trajectory, qbot, datum, &
       .false., .false., .false., .false., endpoint, status)
  call require(status == MODFLOW6_TANGENT_ENDPOINT_OK, 'analytic endpoint status')
  call require(endpoint%available .and. endpoint%authoritative, 'analytic endpoint authoritative')
  call require(endpoint%coverage%tangent_complete(), 'analytic coverage complete')

  hp_plus = state%pressure_head + eps*trajectory%final_pressure_head_direction
  hp_minus = state%pressure_head - eps*trajectory%final_pressure_head_direction
  call constitutive%evaluate(hp_plus, dummy, kplus, dummy2, dummy3)
  call constitutive%evaluate(hp_minus, dummy, kminus, dummy2, dummy3)
  call materialize_modflow6_prescribed_qbot_bottom_face(hp_plus(n), kplus(n), qbot+eps, &
       0.5_real64*parameters%dz(n), datum, plus_face, status)
  call require(status == MODFLOW6_BOTTOM_FACE_OK .and. plus_face%valid, 'plus FD face')
  call materialize_modflow6_prescribed_qbot_bottom_face(hp_minus(n), kminus(n), qbot-eps, &
       0.5_real64*parameters%dz(n), datum, minus_face, status)
  call require(status == MODFLOW6_BOTTOM_FACE_OK .and. minus_face%valid, 'minus FD face')
  fd = (plus_face%pressure_head_cm-minus_face%pressure_head_cm)/(2.0_real64*eps)
  scale = max(1.0_real64,abs(fd),abs(endpoint%bottom_face%dpressure_head_cm_per_qbot_cm_per_day))
  call require(abs(fd-endpoint%bottom_face%dpressure_head_cm_per_qbot_cm_per_day) <= tol*scale, &
       'independent endpoint finite difference')
  write(*,'(A)') 'FVQ104_INDEPENDENT_BOTTOM_FACE_FD=PASS'

  call build_modflow6_swap_predictor_tangent_endpoint(state, parameters, constitutive, trajectory, qbot, datum, &
       .false., .false., .true., .false., blocked, status)
  call require(status == MODFLOW6_TANGENT_ENDPOINT_INCOMPLETE_COVERAGE, 'drainage endpoint incomplete')
  call require(blocked%available .and. .not. blocked%authoritative, 'drainage tangent fail closed')
  write(*,'(A)') 'FVQ104_DRAINAGE_TANGENT_FAIL_CLOSED=PASS'

  window%t0 = 2.0_real64
  window%t1 = 2.25_real64
  lineage%coupling_id = 104_int64
  lineage%swap_lineage_id = 1004_int64
  lineage%swap_origin_revision = 9_int64
  lineage%groundwater_service_id = 204_int64
  lineage%groundwater_lineage_id = 2004_int64
  lineage%groundwater_origin_revision = 11_int64
  coverage = endpoint%coverage

  call compose_modflow6_swap_predictor_response(window, lineage, qbot, &
       endpoint%bottom_face%hydraulic_head_m-0.003_real64, endpoint%bottom_face%hydraulic_head_m, &
       endpoint%bottom_face%dpressure_head_cm_per_qbot_cm_per_day, MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT, &
       coverage, response=response, status=status)
  call require(status == MODFLOW6_PREDICTOR_OK .and. response%valid, 'predictor response valid')
  expected_u = (window%t1-window%t0)/endpoint%bottom_face%dpressure_head_cm_per_qbot_cm_per_day
  expected_qu = expected_u*(0.003_real64*100.0_real64)/(window%t1-window%t0)-qbot
  call require(close(response%coupling_storage_coefficient_u, expected_u), 'u independent algebra')
  call require(close(response%q_u_cm_per_day, expected_qu), 'q_u independent algebra')
  call require(close(response%q_u_m_per_s, expected_qu*cm_to_m/day_to_s), 'q_u SI translation')
  write(*,'(A)') 'FVQ104_INDEPENDENT_U_QU_ALGEBRA=PASS'

  coverage%drainage_active = .true.
  coverage%drainage_covered = .false.
  call compose_modflow6_swap_predictor_response(window, lineage, qbot, 0.0_real64, 0.001_real64, &
       endpoint%bottom_face%dpressure_head_cm_per_qbot_cm_per_day, MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT, &
       coverage, response=response, status=status)
  call require(status == MODFLOW6_PREDICTOR_INCOMPLETE_DERIVATIVE_COVERAGE .and. .not. response%valid, &
       'response drainage coverage fail closed')
  write(*,'(A)') 'FVQ104_RESPONSE_COVERAGE_FAIL_CLOSED=PASS'

  accepted_interface%h_swap_m = 1.25_real64
  accepted_interface%h_groundwater_m = 1.24_real64
  accepted_interface%q_swap_m_per_s = 2.0e-8_real64
  accepted_interface%q_groundwater_m_per_s = -2.0e-8_real64
  call capture_modflow6_swap_predictor_origin(accepted_interface, window%t0, lineage, .true., origin, status)
  call require(status == MODFLOW6_PREDICTOR_ORIGIN_OK .and. origin%structurally_valid(), 'origin valid')
  call require(close(origin%h_bot_start_m,accepted_interface%h_swap_m), 'origin uses accepted SWAP head')
  call require(close(origin%accepted_head_residual_m,0.01_real64), 'origin retains head residual')
  write(*,'(A)') 'FVQ104_ORIGIN_SWAP_HEAD_PROVENANCE=PASS'

  call capture_modflow6_swap_predictor_origin(accepted_interface, window%t0, lineage, .false., origin, status)
  call require(status == MODFLOW6_PREDICTOR_ORIGIN_NOT_COMMITTED, 'uncommitted origin rejected')
  accepted_interface%q_groundwater_m_per_s = 0.0_real64
  call capture_modflow6_swap_predictor_origin(accepted_interface, window%t0, lineage, .true., origin, status)
  call require(status == MODFLOW6_PREDICTOR_ORIGIN_NONCONSERVATIVE_INTERFACE, 'nonconservative origin rejected')
  write(*,'(A)') 'FVQ104_ORIGIN_FAIL_CLOSED=PASS'

  write(*,'(A)') 'FVQ104_INDEPENDENT_NUMERICAL_ORACLE=PASS'

contains

  pure logical function close(a,b)
    real(real64), intent(in) :: a,b
    real(real64) :: s
    s=max(1.0_real64,abs(a),abs(b))
    close=abs(a-b) <= 4096.0_real64*epsilon(1.0_real64)*s
  end function close

  subroutine require(ok,label)
    logical, intent(in) :: ok
    character(len=*), intent(in) :: label
    if(.not.ok) then
      write(*,'(A,1X,A)') 'FVQ104_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fvq104_fgc30_independent
