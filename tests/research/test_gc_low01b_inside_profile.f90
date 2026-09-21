program test_gc_low01b_inside_profile
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
  real(real64), parameter :: gwl_cases(3) = [-60.0_real64, -120.0_real64, -200.0_real64]
  integer, parameter :: expected_nn(3) = [1, 2, 3]
  real(real64), parameter :: dt_day = 0.25_real64
  real(real64), parameter :: origin_gwl_cm = -120.0_real64
  real(real64), parameter :: tol = 1.0e-12_real64
  real(real64), parameter :: mass_tol = 1.0e-10_real64

  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(hydraulic_evaluation_context_t) :: evaluation
  real(real64), target :: drainage(1,n), irrigation(n), root_sink(n)
  real(real64) :: raw(24,n)
  type(reference_richards_state_binding_t) :: origin
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
  call require(.not. hydraulic_parameters%ksatexm_extension_enabled, 'LOW01-B KSATEXM disabled')
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, dt_day)
  call gc_low01_bind_mvg(hydraulic_parameters, dt_day)

  drainage = 0.0_real64
  irrigation = 0.0_real64
  root_sink = 0.0_real64
  call bind_b110_source_sink_provider(source_sink, drainage, irrigation, root_sink)

  evaluation%constitutive => constitutive
  evaluation%source_sink => source_sink
  evaluation%top_boundary => top

  call initialize_origin(origin, origin_gwl_cm, parameters, constitutive)

  do i = 1, size(gwl_cases)
    call run_case(gwl_cases(i), expected_nn(i), origin, parameters, hydraulic_parameters, constitutive, evaluation)
  end do

  write(*,'(A,F0.8)') 'GC_LOW01B_IMMUTABLE_ORIGIN_GWL_CM=', origin_gwl_cm
  write(*,'(A)') 'GC_LOW01B_SINGLE_CONSTITUTIVE_OWNER=PASS'
  write(*,'(A)') 'GC_LOW01B_IMMUTABLE_ORIGIN=PASS'
  write(*,'(A)') 'GC_LOW01B_INSIDE_PROFILE_CASES=PASS'
  write(*,'(A)') 'GC_LOW01B_SATURATED_CONTINUATION=PASS'
  write(*,'(A)') 'GC_LOW01B_QBOT_DIAGNOSED=PASS'
  write(*,'(A)') 'GC_LOW01B_MASS_CLOSURE=PASS'
  write(*,'(A)') 'GC_LOW01B_BITWISE_REPLAY=PASS'
  write(*,'(A)') 'GC_LOW01B_LIVE_GATE=PASS'

contains

  subroutine configure_parameters(parameter_set, cofgen_raw)
    type(soil_water_parameter_set_t), target, intent(out) :: parameter_set
    real(real64), intent(out) :: cofgen_raw(24,n)
    integer :: k

    parameter_set%parameter_set_id = 51001_int64
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

  subroutine run_case(gwl_cm, expected_active_nn, origin_state, parameter_set, hp, provider, eval)
    real(real64), intent(in) :: gwl_cm
    integer, intent(in) :: expected_active_nn
    type(reference_richards_state_binding_t), intent(in) :: origin_state
    type(soil_water_parameter_set_t), target, intent(in) :: parameter_set
    type(b110_default_mvg_parameters_t), intent(in) :: hp
    type(b110_default_mvg_provider_t), intent(in) :: provider
    type(hydraulic_evaluation_context_t), intent(in) :: eval

    type(reference_richards_state_binding_t) :: first, second
    type(a23bu_worker_context_t) :: worker1, worker2
    type(reference_richards_workspace_t), target :: workspace1, workspace2
    type(a23bu_solver_history_t), target :: history1, history2
    type(soil_water_boundary_conditions_t) :: boundary
    type(soil_water_numerical_config_t) :: numerical
    type(soil_water_physical_config_t) :: physical
    integer :: nn

    nn = classify_nn(gwl_cm, parameter_set%z)
    call require(nn == expected_active_nn, 'LOW01-B active NN classification')

    boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
    boundary%bottom_mode = 1
    boundary%top_flux = 0.0_real64
    boundary%top_head = 0.0_real64
    boundary%bottom_flux = 0.0_real64
    boundary%bottom_head = gwl_cm

    numerical%max_iterations = 16
    numerical%max_backtracking = 8
    numerical%conductivity_implicit_mode = 0
    numerical%conductivity_mean_method = 1
    numerical%min_step_duration = 1.0e-8_real64
    numerical%compartment_balance_tolerance = tol
    numerical%total_balance_tolerance = tol
    numerical%head_abs_tolerance = tol
    numerical%head_rel_tolerance = tol
    numerical%ponding_tolerance = tol
    physical%macropore_active = .false.

    first = origin_state
    call headcalc(worker1, workspace1, history1, first, eval, boundary, numerical, physical, dt_day, parameter_set)
    call verify_candidate(first, origin_state, gwl_cm, nn, parameter_set, hp, provider, worker1, 'first')

    second = origin_state
    call headcalc(worker2, workspace2, history2, second, eval, boundary, numerical, physical, dt_day, parameter_set)
    call verify_candidate(second, origin_state, gwl_cm, nn, parameter_set, hp, provider, worker2, 'second')
    call require(states_bitwise_identical(first, second), 'LOW01-B repeated trial bitwise identity')

    write(*,'(A,F0.8)') 'GC_LOW01B_GWL_CM=', gwl_cm
    write(*,'(A,I0)') 'GC_LOW01B_ACTIVE_NN=', nn
    write(*,'(A,ES24.16E3)') 'GC_LOW01B_QBOT_CM_PER_DAY=', first%qbot
    write(*,'(A,I0)') 'GC_LOW01B_NONLINEAR_ITERATIONS=', worker1%diagnostics%nonlinear_iterations
  end subroutine run_case

  subroutine initialize_origin(state, gwl_cm, parameter_set, provider)
    type(reference_richards_state_binding_t), intent(out) :: state
    real(real64), intent(in) :: gwl_cm
    type(soil_water_parameter_set_t), intent(in) :: parameter_set
    type(b110_default_mvg_provider_t), intent(in) :: provider
    real(real64) :: heads(n), water(n), conductivity(n), capacity(n), dkdh(n)
    integer :: k

    do k = 1, n
      heads(k) = gwl_cm - parameter_set%z(k)
    end do
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)

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
    state%gwl = gwl_cm
    state%gwlm1 = gwl_cm
    state%gwlinp = gwl_cm
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

  subroutine verify_candidate(state, origin_state, gwl_cm, nn, parameter_set, hp, provider, worker, label_text)
    type(reference_richards_state_binding_t), intent(in) :: state
    type(reference_richards_state_binding_t), intent(in) :: origin_state
    real(real64), intent(in) :: gwl_cm
    integer, intent(in) :: nn
    type(soil_water_parameter_set_t), intent(in) :: parameter_set
    type(b110_default_mvg_parameters_t), intent(in) :: hp
    type(b110_default_mvg_provider_t), intent(in) :: provider
    type(a23bu_worker_context_t), intent(in) :: worker
    character(len=*), intent(in) :: label_text
    real(real64) :: saturated_head(n), saturated_water(n), saturated_k(n), saturated_c(n), saturated_d(n)
    real(real64) :: storage_change, mass_residual
    integer :: k

    call require(.not. hp%ksatexm_extension_enabled, 'LOW01-B '//trim(label_text)//' KSATEXM disabled')
    call require(.not. state%fllowgwl, 'LOW01-B '//trim(label_text)//' fllowgwl false')
    call require(.not. state%fldecdt, 'LOW01-B '//trim(label_text)//' no dt reduction')
    call require(.not. worker%control%request_dt_reduction, 'LOW01-B '//trim(label_text)//' worker no dt reduction')
    call require(worker%diagnostics%alternative_solver_calls == 0, 'LOW01-B '//trim(label_text)//' no alternative solver')
    call require(abs(state%gwlinp - gwl_cm) <= tol, 'LOW01-B '//trim(label_text)//' gwlinp retained')
    call require(ieee_is_finite(state%qbot), 'LOW01-B '//trim(label_text)//' finite diagnosed qbot')
    call require(transfer(state%gwl,0_int64) == transfer(origin_state%gwl,0_int64), &
         'LOW01-B '//trim(label_text)//' raw accepted gwl remains origin state')

    saturated_head = 0.0_real64
    call provider%evaluate(saturated_head, saturated_water, saturated_k, saturated_c, saturated_d)
    do k = nn+1, n
      call require(transfer(state%theta(k),0_int64) == transfer(saturated_water(k),0_int64), &
           'LOW01-B '//trim(label_text)//' provider-owned saturated theta')
      call require(transfer(saturated_water(k),0_int64) == transfer(hp%cofgen(2,k),0_int64), &
           'LOW01-B '//trim(label_text)//' source-equivalent theta_s')
      call require(transfer(saturated_k(k),0_int64) == transfer(hp%cofgen(3,k),0_int64), &
           'LOW01-B '//trim(label_text)//' source-equivalent K_s')
    end do

    storage_change = sum((state%theta - origin_state%theta) * parameter_set%dz) + &
         (state%pond - origin_state%pond)
    mass_residual = storage_change - dt_day * (-state%qtop + state%qbot)
    call require(abs(mass_residual) <= mass_tol, 'LOW01-B '//trim(label_text)//' mass closure')
    write(*,'(A,A,A,ES24.16E3)') 'GC_LOW01B_',trim(label_text),'_STORAGE_CHANGE_CM=',storage_change
    write(*,'(A,A,A,ES24.16E3)') 'GC_LOW01B_',trim(label_text),'_MASS_RESIDUAL_CM=',mass_residual
  end subroutine verify_candidate

  integer function classify_nn(gwl_cm, z) result(nn)
    real(real64), intent(in) :: gwl_cm
    real(real64), intent(in) :: z(:)

    nn = 0
    do while (nn < size(z))
      if (.not. (z(nn+1) > gwl_cm)) exit
      nn = nn + 1
    end do
    if (nn <= 0 .or. nn >= size(z)) error stop 'LOW01-B prescribed GWL not strictly inside profile'
  end function classify_nn

  logical function states_bitwise_identical(a, b) result(same)
    type(reference_richards_state_binding_t), intent(in) :: a, b
    integer :: k

    same = .false.
    if (a%active_nodes /= b%active_nodes) return
    do k = 1, a%active_nodes
      if (transfer(a%h(k), 0_int64) /= transfer(b%h(k), 0_int64)) return
      if (transfer(a%theta(k), 0_int64) /= transfer(b%theta(k), 0_int64)) return
      if (transfer(a%hm1(k), 0_int64) /= transfer(b%hm1(k), 0_int64)) return
      if (transfer(a%thetm1(k), 0_int64) /= transfer(b%thetm1(k), 0_int64)) return
    end do
    if (transfer(a%qbot, 0_int64) /= transfer(b%qbot, 0_int64)) return
    if (transfer(a%gwl, 0_int64) /= transfer(b%gwl, 0_int64)) return
    if (transfer(a%gwlinp, 0_int64) /= transfer(b%gwlinp, 0_int64)) return
    if (a%fllowgwl .neqv. b%fllowgwl) return
    same = .true.
  end function states_bitwise_identical

  subroutine require(value, message)
    logical, intent(in) :: value
    character(len=*), intent(in) :: message
    if (.not. value) then
      write(*,'(A,1X,A)') 'GC_LOW01B_FAIL', trim(message)
      error stop 1
    end if
  end subroutine require

end program test_gc_low01b_inside_profile
