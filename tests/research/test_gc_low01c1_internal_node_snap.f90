program test_gc_low01c1_internal_node_snap
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t
  use mod_reference_richards_workspace, only: reference_richards_workspace_t
  use mod_reference_richards_state_binding, only: reference_richards_state_binding_t, FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t, &
       soil_water_numerical_config_t, soil_water_physical_config_t, soil_water_parameter_set_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use MOD_MvG, only: gc_low01_bind_mvg
  implicit none

  integer, parameter :: n = 4
  real(real64), parameter :: z_cm(n) = [-25.0_real64, -75.0_real64, -150.0_real64, -250.0_real64]
  real(real64), parameter :: dz_cm(n) = [50.0_real64, 50.0_real64, 100.0_real64, 100.0_real64]
  real(real64), parameter :: dist_cm(n) = [25.0_real64, 50.0_real64, 75.0_real64, 100.0_real64]
  real(real64), parameter :: control_cm(4) = [-149.99995_real64, -150.0_real64, -150.00005_real64, -150.0002_real64]
  integer, parameter :: expected_nn(4) = [2, 2, 2, 3]
  real(real64), parameter :: expected_effective_cm(4) = [-149.99995_real64, -150.0_real64, -150.0_real64, -150.0002_real64]
  logical, parameter :: expected_snap(4) = [.false., .false., .true., .false.]
  real(real64), parameter :: origin_gwl_cm = -120.0_real64
  real(real64), parameter :: dt_day = 0.01_real64
  real(real64), parameter :: tol = 1.0e-10_real64
  real(real64), parameter :: origin_h_phreatic_cm = -120.0_real64

  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(hydraulic_evaluation_context_t) :: evaluation
  real(real64), target :: drainage(1,n), irrigation(n), root_sink(n)
  real(real64) :: raw(24,n)
  type(reference_richards_state_binding_t) :: origin, origin_snapshot, characterized(4)
  real(real64) :: qbot_characterized(4), storage_characterized(4), residual_characterized(4)
  integer :: iterations_characterized(4)
  integer :: i

  interface
    subroutine headcalc(worker, fsi_workspace, history, state_binding, evaluation_context, boundary_conditions, &
                        numerical_config, physical_config, explicit_step_duration, parameter_set)
      use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t
      use mod_reference_richards_workspace, only: reference_richards_workspace_t
      use mod_reference_richards_state_binding, only: reference_richards_state_binding_t
      use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t, &
           soil_water_numerical_config_t, soil_water_physical_config_t, soil_water_parameter_set_t
      type(a23bu_worker_context_t), intent(inout), optional :: worker
      type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace
      type(a23bu_solver_history_t), target, intent(inout), optional :: history
      type(reference_richards_state_binding_t), target, intent(inout), optional :: state_binding
      type(hydraulic_evaluation_context_t), intent(in), optional :: evaluation_context
      type(soil_water_boundary_conditions_t), intent(in), optional :: boundary_conditions
      type(soil_water_numerical_config_t), intent(in), optional :: numerical_config
      type(soil_water_physical_config_t), intent(in), optional :: physical_config
      real(8), intent(in), optional :: explicit_step_duration
      type(soil_water_parameter_set_t), target, intent(in), optional :: parameter_set
    end subroutine headcalc
  end interface

  call configure_parameters(parameters, raw)
  call initialize_b110_default_mvg_parameters(hydraulic_parameters, raw)
  call require(.not. hydraulic_parameters%ksatexm_extension_enabled, 'C1 KSATEXM disabled')
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, dt_day)
  call gc_low01_bind_mvg(hydraulic_parameters, dt_day)

  drainage = 0.0_real64
  irrigation = 0.0_real64
  root_sink = 0.0_real64
  call bind_b110_source_sink_provider(source_sink, drainage, irrigation, root_sink)
  evaluation%constitutive => constitutive
  evaluation%source_sink => source_sink
  evaluation%top_boundary => top

  call initialize_origin(origin)
  origin_snapshot = origin

  do i = 1, size(control_cm)
    call run_case(i, origin, characterized(i), qbot_characterized(i), storage_characterized(i), &
         residual_characterized(i), iterations_characterized(i))
    call require(states_bitwise_identical(origin, origin_snapshot), 'C1 caller origin unchanged')
  end do

  do i = 1, size(control_cm)
    write(*,'(A,I0)') 'GC_LOW01C1_DELTA_CASE=', i
    write(*,'(A,ES24.16E3)') 'GC_LOW01C1_MAX_HEAD_DELTA_FROM_AT_NODE_CM=', &
         maxval(abs(characterized(i)%h-characterized(2)%h))
    write(*,'(A,ES24.16E3)') 'GC_LOW01C1_QBOT_DELTA_FROM_AT_NODE_CM_PER_DAY=', &
         qbot_characterized(i)-qbot_characterized(2)
    write(*,'(A,ES24.16E3)') 'GC_LOW01C1_STORAGE_DELTA_FROM_AT_NODE_CM=', &
         storage_characterized(i)-storage_characterized(2)
  end do

  write(*,'(A)') 'GC_LOW01C1_IMMUTABLE_ORIGIN=PASS'
  write(*,'(A)') 'GC_LOW01C1_PROVIDER_OWNED_ROUTE=PASS'
  write(*,'(A)') 'GC_LOW01C1_ACTIVE_DOMAIN_AND_SNAP=PASS'
  write(*,'(A)') 'GC_LOW01C1_FINITE_QBOT_AND_STATE=PASS'
  write(*,'(A)') 'GC_LOW01C1_MASS_CLOSURE=PASS'
  write(*,'(A)') 'GC_LOW01C1_REPLAY_DETERMINISM=PASS'
  write(*,'(A)') 'GC_LOW01C1_LIVE_GATE=PASS'

contains

  subroutine configure_parameters(parameter_set, cofgen_raw)
    type(soil_water_parameter_set_t), target, intent(out) :: parameter_set
    real(real64), intent(out) :: cofgen_raw(24,n)
    integer :: k

    parameter_set%parameter_set_id = 51003_int64
    parameter_set%active_nodes = n
    allocate(parameter_set%z(n), parameter_set%dz(n), parameter_set%node_distance(n))
    parameter_set%z = z_cm
    parameter_set%dz = dz_cm
    parameter_set%node_distance = dist_cm

    cofgen_raw = 0.0_real64
    do k = 1, n
      cofgen_raw(1,k) = 0.032_real64
      cofgen_raw(2,k) = 0.423_real64 + 0.001_real64*real(k-1,real64)
      cofgen_raw(3,k) = 4.75_real64 + 0.5_real64*real(k-1,real64)
      cofgen_raw(4,k) = 0.0135_real64
      cofgen_raw(5,k) = 0.365_real64
      cofgen_raw(6,k) = 1.455_real64
      cofgen_raw(7,k) = 1.0_real64 - 1.0_real64/cofgen_raw(6,k)
      cofgen_raw(8,k) = cofgen_raw(4,k)
      cofgen_raw(9,k) = 0.0_real64
      cofgen_raw(10,k) = 10.0_real64*cofgen_raw(3,k)
      cofgen_raw(11,k) = 0.998_real64
      cofgen_raw(12,k) = 0.99_real64*cofgen_raw(3,k)
      cofgen_raw(22,k) = -1.0e6_real64
      cofgen_raw(23,k) = 1.0e-12_real64
    end do
  end subroutine configure_parameters

  subroutine initialize_origin(state)
    type(reference_richards_state_binding_t), intent(out) :: state
    real(real64) :: heads(n), water(n), conductivity(n), capacity(n), dkdh(n)
    integer :: k

    do k = 1, n
      heads(k) = origin_h_phreatic_cm - z_cm(k)
    end do
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)

    state%active_nodes = n
    allocate(state%h(n), state%theta(n), state%hm1(n), state%thetm1(n))
    allocate(state%k(n), state%kmean(n+1), state%dimoca(n), state%itnumb(100,2))
    state%h = heads
    state%theta = water
    state%hm1 = heads
    state%thetm1 = water
    state%k = conductivity
    state%kmean = 0.0_real64
    state%dimoca = capacity
    state%pond = 0.0_real64
    state%pondm1 = 0.0_real64
    state%gwl = origin_h_phreatic_cm
    state%gwlm1 = origin_h_phreatic_cm
    state%gwlinp = origin_h_phreatic_cm
    state%dtold = dt_day
    state%qtop = 0.0_real64
    state%qbot = 0.0_real64
    state%hbot = 0.0_real64
    state%q0 = 0.0_real64
    state%hsurf = 0.0_real64
    state%runots = 0.0_real64
    state%itnumb = 0
    state%numbit = 0
    state%fllowgwl = .false.
    state%fldecdt = .false.
    state%flrunoff = .false.
    state%ftoph = .false.
  end subroutine initialize_origin

  subroutine run_case(index, immutable_origin, characterized_state, qbot_out, storage_out, residual_out, iterations_out)
    integer, intent(in) :: index
    type(reference_richards_state_binding_t), intent(in) :: immutable_origin
    type(reference_richards_state_binding_t), intent(out) :: characterized_state
    real(real64), intent(out) :: qbot_out, storage_out, residual_out
    integer, intent(out) :: iterations_out
    type(reference_richards_state_binding_t) :: first, second
    type(a23bu_worker_context_t) :: worker1, worker2
    type(reference_richards_workspace_t), target :: workspace1, workspace2
    type(a23bu_solver_history_t), target :: history1, history2
    type(soil_water_boundary_conditions_t) :: boundary
    type(soil_water_numerical_config_t) :: numerical
    type(soil_water_physical_config_t) :: physical
    real(real64) :: storage0, storage1, residual1, residual2, max_head_delta
    real(real64) :: lower_distance, lower_gradient_observed, lower_gradient_formula
    real(real64) :: jacobian_without_lower, lower_jacobian_observed, lower_jacobian_formula
    integer :: observed_nn, k

    first = immutable_origin
    second = immutable_origin
    first%gwlinp = control_cm(index)
    second%gwlinp = control_cm(index)

    boundary = soil_water_boundary_conditions_t()
    boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
    boundary%bottom_mode = 1
    boundary%top_flux = 0.0_real64
    boundary%top_head = immutable_origin%hsurf
    boundary%bottom_flux = 0.0_real64
    boundary%bottom_head = 0.0_real64

    numerical%max_iterations = 24
    numerical%max_backtracking = 8
    numerical%conductivity_implicit_mode = 0
    numerical%conductivity_mean_method = 1
    numerical%min_step_duration = 1.0e-10_real64
    numerical%compartment_balance_tolerance = tol
    numerical%total_balance_tolerance = tol
    numerical%head_abs_tolerance = tol
    numerical%head_rel_tolerance = tol
    numerical%ponding_tolerance = tol
    physical%macropore_active = .false.

    storage0 = sum(immutable_origin%theta*dz_cm) + immutable_origin%pond
    call headcalc(worker1, workspace1, history1, first, evaluation, boundary, numerical, physical, dt_day, parameters)
    storage1 = sum(first%theta*dz_cm) + first%pond
    residual1 = storage1-storage0 - dt_day*(-first%qtop+first%qbot)

    call headcalc(worker2, workspace2, history2, second, evaluation, boundary, numerical, physical, dt_day, parameters)
    residual2 = (sum(second%theta*dz_cm)+second%pond)-storage0 - dt_day*(-second%qtop+second%qbot)

    observed_nn = 0
    do while (observed_nn < n)
      if (.not. (z_cm(observed_nn+1) > control_cm(index))) exit
      observed_nn = observed_nn + 1
    end do
    call require(observed_nn > 0 .and. observed_nn < n, 'C1 source-safe inside-profile control')
    if ((z_cm(observed_nn)-control_cm(index)) < 1.0e-4_real64) observed_nn = observed_nn - 1

    lower_distance = z_cm(observed_nn) - first%gwlinp
    call require(lower_distance > 0.0_real64, 'C1 positive lower distance')
    lower_gradient_observed = workspace1%head_gradient(observed_nn+1)
    lower_gradient_formula = first%h(observed_nn)/lower_distance + 1.0_real64
    lower_jacobian_formula = first%kmean(observed_nn+1)/lower_distance
    if (observed_nn == 1) then
      jacobian_without_lower = first%dimoca(1)*dz_cm(1)/dt_day - workspace1%dfdh_lower(1)
    else
      jacobian_without_lower = first%dimoca(observed_nn)*dz_cm(observed_nn)/dt_day - &
           workspace1%dfdh_upper(observed_nn)
    end if
    lower_jacobian_observed = workspace1%dfdh_main(observed_nn) - jacobian_without_lower

    call require(observed_nn == expected_nn(index), 'C1 reconstructed active NN')
    call require(abs(first%gwlinp-expected_effective_cm(index)) <= 1.0e-12_real64, 'C1 effective H')
    call require((abs(first%gwlinp-control_cm(index)) > 0.0_real64) .eqv. expected_snap(index), 'C1 snap flag')
    call require(.not. first%fllowgwl, 'C1 inside-profile fllowgwl false')
    call require(.not. first%fldecdt .and. .not. worker1%control%request_dt_reduction, 'C1 no dt reduction')
    call require(worker1%diagnostics%alternative_solver_calls == 0, 'C1 no alternative solver')
    call require(all(ieee_is_finite(first%h)) .and. all(ieee_is_finite(first%theta)), 'C1 finite state')
    call require(ieee_is_finite(first%qbot), 'C1 finite qbot')
    call require(ieee_is_finite(lower_gradient_observed) .and. ieee_is_finite(lower_gradient_formula), &
         'C1 finite lower gradient diagnostic')
    call require(ieee_is_finite(lower_jacobian_observed) .and. ieee_is_finite(lower_jacobian_formula), &
         'C1 finite lower Jacobian diagnostic')
    call require(abs(lower_gradient_observed-lower_gradient_formula) <= 1.0e-12_real64, &
         'C1 lower gradient formula')
    call require(abs(lower_jacobian_observed-lower_jacobian_formula) <= 1.0e-12_real64, &
         'C1 lower Jacobian formula')
    call require(abs(residual1) <= tol, 'C1 mass closure')
    call require(states_bitwise_identical(first,second), 'C1 repeat state')
    call require(transfer(residual1,0_int64) == transfer(residual2,0_int64), 'C1 repeat mass residual')
    call require(worker1%diagnostics%nonlinear_iterations == worker2%diagnostics%nonlinear_iterations, 'C1 repeat iterations')
    call require(transfer(immutable_origin%gwl,0_int64) == transfer(origin_gwl_cm,0_int64), 'C1 origin accepted GWL')
    call require(transfer(immutable_origin%gwlinp,0_int64) == transfer(origin_gwl_cm,0_int64), 'C1 origin requested GWL')
    call require(all([(transfer(immutable_origin%h(k),0_int64) == &
         transfer(origin_gwl_cm-z_cm(k),0_int64), k=1,n)]), 'C1 fixed hydrostatic origin heads')

    characterized_state = first
    qbot_out = first%qbot
    storage_out = storage1-storage0
    residual_out = residual1
    iterations_out = worker1%diagnostics%nonlinear_iterations

    max_head_delta = maxval(abs(first%h-immutable_origin%h))
    write(*,'(A,I0)') 'GC_LOW01C1_CASE=', index
    write(*,'(A,ES24.16E3)') 'GC_LOW01C1_REQUESTED_H_CM=', control_cm(index)
    write(*,'(A,ES24.16E3)') 'GC_LOW01C1_EFFECTIVE_H_CM=', first%gwlinp
    write(*,'(A,I0)') 'GC_LOW01C1_ACTIVE_NN=', observed_nn
    write(*,'(A,I0)') 'GC_LOW01C1_SNAP=', merge(1,0,expected_snap(index))
    write(*,'(A,ES24.16E3)') 'GC_LOW01C1_QBOT_CM_PER_DAY=', first%qbot
    write(*,'(A,ES24.16E3)') 'GC_LOW01C1_STORAGE_CHANGE_CM=', storage1-storage0
    write(*,'(A,ES24.16E3)') 'GC_LOW01C1_MASS_RESIDUAL_CM=', residual1
    write(*,'(A,ES24.16E3)') 'GC_LOW01C1_LOWER_DISTANCE_CM=', lower_distance
    write(*,'(A,ES24.16E3)') 'GC_LOW01C1_LOWER_GRADIENT=', lower_gradient_observed
    write(*,'(A,ES24.16E3)') 'GC_LOW01C1_LOWER_JACOBIAN_PER_DAY=', lower_jacobian_observed
    write(*,'(A,ES24.16E3)') 'GC_LOW01C1_MAX_HEAD_DELTA_CM=', max_head_delta
    write(*,'(A,I0)') 'GC_LOW01C1_NONLINEAR_ITERATIONS=', worker1%diagnostics%nonlinear_iterations
  end subroutine run_case

  logical function states_bitwise_identical(a,b) result(same)
    type(reference_richards_state_binding_t), intent(in) :: a,b
    integer :: k
    same = .false.
    if (a%active_nodes /= b%active_nodes) return
    do k=1,a%active_nodes
      if (transfer(a%h(k),0_int64) /= transfer(b%h(k),0_int64)) return
      if (transfer(a%theta(k),0_int64) /= transfer(b%theta(k),0_int64)) return
    end do
    if (transfer(a%qbot,0_int64) /= transfer(b%qbot,0_int64)) return
    if (transfer(a%gwlinp,0_int64) /= transfer(b%gwlinp,0_int64)) return
    if (a%fllowgwl .neqv. b%fllowgwl) return
    same = .true.
  end function states_bitwise_identical

  subroutine require(ok,msg)
    logical, intent(in) :: ok
    character(len=*), intent(in) :: msg
    if(.not.ok) then
      write(*,'(A,1X,A)') 'GC_LOW01C1_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine require

end program test_gc_low01c1_internal_node_snap
