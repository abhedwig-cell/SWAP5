program test_fgc30_predictor_tangent_adapter
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t, soil_water_parameter_set_t
  use mod_soil_water_accepted_step_direction_contract, only: SW_STEP_CONTROL_BOTTOM_FLUX, SW_STEP_CONTROL_BOTTOM_HEAD
  use mod_accepted_trajectory_directional_publication, only: accepted_trajectory_direction_result_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_modflow6_swap_predictor_tangent_adapter, only: modflow6_swap_predictor_tangent_endpoint_t, &
       build_modflow6_swap_predictor_tangent_endpoint, MODFLOW6_TANGENT_ENDPOINT_OK, &
       MODFLOW6_TANGENT_ENDPOINT_INCOMPLETE_COVERAGE, MODFLOW6_TANGENT_ENDPOINT_CONTROL_MISMATCH
  implicit none

  real(real64), parameter :: H0 = -75.0_real64
  real(real64), parameter :: QBOT = -0.20_real64
  real(real64), parameter :: DHDQ = 1.50_real64
  real(real64), parameter :: DZ = 20.0_real64
  real(real64), parameter :: EPSQ = 1.0e-5_real64
  real(real64), parameter :: DT = 0.25_real64

  type(soil_water_parameter_set_t) :: parameters
  type(soil_water_physical_state_t) :: candidate
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t) :: constitutive
  type(accepted_trajectory_direction_result_t) :: trajectory, wrong_control
  type(groundwater_head_datum_t) :: datum
  type(modflow6_swap_predictor_tangent_endpoint_t) :: endpoint, incomplete
  real(real64) :: cofgen(24,1)
  real(real64) :: theta(1), conductivity(1), capacity(1), reserved_dkdh(1)
  real(real64) :: hp(1), hm(1), tp(1), tm(1), kp(1), km(1), cp(1), cm(1), dkp(1), dkm(1)
  real(real64) :: face_plus, face_minus, fd_direction
  integer :: status

  call initialize_cofgen(cofgen)
  call initialize_b110_default_mvg_parameters(hydraulic_parameters, cofgen)
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, DT)

  parameters%parameter_set_id = 30001_int64
  parameters%active_nodes = 1
  allocate(parameters%z(1), parameters%dz(1), parameters%node_distance(1))
  parameters%z = -10.0_real64
  parameters%dz = DZ
  parameters%node_distance = DZ

  candidate%active_nodes = 1
  allocate(candidate%pressure_head(1), candidate%water_content(1))
  candidate%pressure_head = H0
  call constitutive%evaluate(candidate%pressure_head, theta, conductivity, capacity, reserved_dkdh)
  candidate%water_content = theta

  trajectory%requested = .true.
  trajectory%available = .true.
  trajectory%worker_id = 3001
  trajectory%generation = 17_int64
  trajectory%control_coordinate = SW_STEP_CONTROL_BOTTOM_FLUX
  trajectory%accepted_steps = 2
  trajectory%origin_t0 = 4.0_real64
  trajectory%accepted_t1 = 4.25_real64
  trajectory%method = 'same-accepted-tridag-factor'
  trajectory%route = 'accepted-trajectory'
  trajectory%additional_tridiagonal_backsolves = 2
  trajectory%additional_jacobian_builds = 0
  trajectory%additional_full_nonlinear_solves = 0
  allocate(trajectory%final_pressure_head_direction(1), trajectory%final_water_content_direction(1))
  trajectory%final_pressure_head_direction = DHDQ
  trajectory%final_water_content_direction = 0.0_real64

  datum%available = .true.
  datum%datum_id = 3001_int64
  datum%bottom_boundary_elevation_m = -0.20_real64

  call build_modflow6_swap_predictor_tangent_endpoint(candidate, parameters, constitutive, trajectory, QBOT, datum, &
       .true., .false., .false., .false., endpoint, status)
  call require(status == MODFLOW6_TANGENT_ENDPOINT_OK .and. endpoint%available .and. endpoint%authoritative, &
       'drainage-free accepted trajectory did not produce authoritative endpoint')
  call require(endpoint%coverage%tangent_complete(), 'complete route did not publish complete coverage')
  call require(endpoint%worker_id == trajectory%worker_id .and. &
       endpoint%trajectory_generation == trajectory%generation .and. &
       endpoint%accepted_steps == trajectory%accepted_steps, 'trajectory provenance not retained')

  hp = H0 + DHDQ*EPSQ
  hm = H0 - DHDQ*EPSQ
  call constitutive%evaluate(hp, tp, kp, cp, dkp)
  call constitutive%evaluate(hm, tm, km, cm, dkm)
  face_plus = hp(1) + 0.5_real64*DZ*(1.0_real64 + (QBOT+EPSQ)/kp(1))
  face_minus = hm(1) + 0.5_real64*DZ*(1.0_real64 + (QBOT-EPSQ)/km(1))
  fd_direction = (face_plus-face_minus)/(2.0_real64*EPSQ)
  call require_close(endpoint%bottom_face%dpressure_head_cm_per_qbot_cm_per_day, fd_direction, 2.0e-7_real64, &
       'accepted-trajectory endpoint direction disagrees with independent constitutive FD')

  call build_modflow6_swap_predictor_tangent_endpoint(candidate, parameters, constitutive, trajectory, QBOT, datum, &
       .true., .false., .true., .false., incomplete, status)
  call require(status == MODFLOW6_TANGENT_ENDPOINT_INCOMPLETE_COVERAGE, &
       'active drainage was not classified as incomplete analytic coverage')
  call require(incomplete%available .and. .not. incomplete%authoritative, &
       'partial drainage tangent was exposed as authoritative')
  call require(incomplete%coverage%drainage_active .and. .not. incomplete%coverage%drainage_covered, &
       'drainage provenance not retained fail-closed')

  wrong_control = trajectory
  wrong_control%control_coordinate = SW_STEP_CONTROL_BOTTOM_HEAD
  call build_modflow6_swap_predictor_tangent_endpoint(candidate, parameters, constitutive, wrong_control, QBOT, datum, &
       .false., .false., .false., .false., incomplete, status)
  call require(status == MODFLOW6_TANGENT_ENDPOINT_CONTROL_MISMATCH .and. .not. incomplete%available, &
       'prescribed-head trajectory was relabelled as qbot predictor tangent')

  print '(a)', 'FGC30_ACCEPTED_QBOT_TRAJECTORY_ENDPOINT=PASS'
  print '(a)', 'FGC30_ENDPOINT_CONSTITUTIVE_DIRECTION=PASS'
  print '(a)', 'FGC30_ENDPOINT_CENTERED_FD_ORACLE=PASS'
  print '(a)', 'FGC30_ENDPOINT_PROVENANCE=PASS'
  print '(a)', 'FGC30_ENDPOINT_DRAINAGE_FAIL_CLOSED=PASS'
  print '(a)', 'FGC30_ENDPOINT_CONTROL_FAIL_CLOSED=PASS'
  print '(a)', 'FGC30_PREDICTOR_TANGENT_ADAPTER_GATE=PASS'

contains

  subroutine initialize_cofgen(c)
    real(real64), intent(out) :: c(24,1)
    c = 0.0_real64
    c(1,1) = 0.032_real64
    c(2,1) = 0.423_real64
    c(3,1) = 4.75_real64
    c(4,1) = 0.0135_real64
    c(5,1) = 0.365_real64
    c(6,1) = 1.455_real64
    c(7,1) = 1.0_real64 - 1.0_real64/c(6,1)
    c(8,1) = c(4,1)
    c(9,1) = 0.0_real64
    c(10,1) = c(3,1)
    c(11,1) = 0.999_real64
    c(12,1) = 0.99_real64*c(3,1)
    c(22,1) = -1.0e6_real64
    c(23,1) = 1.0e-12_real64
  end subroutine initialize_cofgen

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a)') 'FGC30_TANGENT_ADAPTER_FAIL: '//trim(message)
      error stop 1
    end if
  end subroutine require

  subroutine require_close(actual, expected, tolerance, message)
    real(real64), intent(in) :: actual, expected, tolerance
    character(len=*), intent(in) :: message
    call require(abs(actual-expected) <= tolerance, message)
  end subroutine require_close

end program test_fgc30_predictor_tangent_adapter
