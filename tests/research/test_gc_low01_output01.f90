program test_gc_low01_output01
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_reference_richards_state_binding, only: reference_richards_state_binding_t
  use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_numerical_config_t, &
       soil_water_physical_config_t, soil_water_parameter_set_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_gc_low01_mode1_trial_carrier, only: gc_low01_mode1_trial_result_t, &
       gc_low01_run_inside_profile_trial, GC_LOW01_BRANCH_INSIDE_PROFILE
  use MOD_MvG, only: gc_low01_bind_mvg
  implicit none

  integer, parameter :: n = 4
  real(real64), parameter :: z_cm(n) = [-25.0_real64, -75.0_real64, -150.0_real64, -250.0_real64]
  real(real64), parameter :: dz_cm(n) = [50.0_real64, 50.0_real64, 100.0_real64, 100.0_real64]
  real(real64), parameter :: dist_cm(n) = [25.0_real64, 50.0_real64, 75.0_real64, 100.0_real64]
  real(real64), parameter :: controls_cm(3) = [-60.0_real64, -120.0_real64, -200.0_real64]
  integer, parameter :: expected_nn(3) = [1, 2, 3]
  real(real64), parameter :: origin_h_phreatic_cm = -120.0_real64
  real(real64), parameter :: dt_day = 0.01_real64
  real(real64), parameter :: mass_tol = 1.0e-10_real64

  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(hydraulic_evaluation_context_t) :: evaluation
  type(soil_water_numerical_config_t) :: numerical
  type(soil_water_physical_config_t) :: physical
  type(reference_richards_state_binding_t) :: origin, origin_snapshot
  type(gc_low01_mode1_trial_result_t) :: results(3), replay_a1, replay_b, replay_a2
  real(real64), target :: drainage(1,n), irrigation(n), root_sink(n)
  real(real64) :: raw(24,n)
  logical :: nonvacuous
  integer :: i

  call configure_parameters(parameters, raw)
  call initialize_b110_default_mvg_parameters(hydraulic_parameters, raw)
  call require(.not. hydraulic_parameters%ksatexm_extension_enabled, 'OUTPUT01 KSATEXM disabled')
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, dt_day)
  call gc_low01_bind_mvg(hydraulic_parameters, dt_day)

  drainage = 0.0_real64
  irrigation = 0.0_real64
  root_sink = 0.0_real64
  call bind_b110_source_sink_provider(source_sink, drainage, irrigation, root_sink)

  evaluation%constitutive => constitutive
  evaluation%source_sink => source_sink
  evaluation%top_boundary => top

  numerical%max_iterations = 24
  numerical%max_backtracking = 10
  numerical%conductivity_implicit_mode = 0
  numerical%conductivity_mean_method = 1
  numerical%min_step_duration = 1.0e-8_real64
  numerical%compartment_balance_tolerance = 1.0e-12_real64
  numerical%total_balance_tolerance = 1.0e-12_real64
  numerical%head_abs_tolerance = 1.0e-12_real64
  numerical%head_rel_tolerance = 1.0e-12_real64
  numerical%ponding_tolerance = 1.0e-12_real64
  physical%macropore_active = .false.

  call initialize_origin(origin, parameters, constitutive)
  origin_snapshot = origin

  do i = 1, size(controls_cm)
    call gc_low01_run_inside_profile_trial(origin, controls_cm(i), parameters, evaluation, numerical, physical, dt_day, results(i))
    call verify_result(results(i), controls_cm(i), expected_nn(i), 'control')
    call require(states_bitwise_identical(origin, origin_snapshot), 'OUTPUT01 caller origin unchanged')
    write(*,'(A,F0.8)') 'GC_LOW01_OUTPUT01_CONTROL_CM=', controls_cm(i)
    write(*,'(A,I0)') 'GC_LOW01_OUTPUT01_ACTIVE_NN=', results(i)%active_richards_nodes
    write(*,'(A,ES24.16E3)') 'GC_LOW01_OUTPUT01_QBOT_CM_PER_DAY=', results(i)%qbot_cm_per_day
    write(*,'(A,ES24.16E3)') 'GC_LOW01_OUTPUT01_STORAGE_CHANGE_CM=', results(i)%storage_change_cm
    write(*,'(A,ES24.16E3)') 'GC_LOW01_OUTPUT01_MASS_RESIDUAL_CM=', results(i)%mass_residual_cm
  end do

  call require(abs(results(2)%qbot_cm_per_day) <= mass_tol, 'OUTPUT01 hydrostatic qbot control')
  call require(abs(results(2)%storage_change_cm) <= mass_tol, 'OUTPUT01 hydrostatic storage control')

  nonvacuous = abs(results(1)%qbot_cm_per_day) > 1.0e-14_real64 .or. &
               abs(results(3)%qbot_cm_per_day) > 1.0e-14_real64 .or. &
               .not. states_bitwise_identical(results(1)%candidate, origin) .or. &
               .not. states_bitwise_identical(results(3)%candidate, origin)
  call require(nonvacuous, 'OUTPUT01 nonvacuous response')

  call gc_low01_run_inside_profile_trial(origin, -60.0_real64, parameters, evaluation, numerical, physical, dt_day, replay_a1)
  call require(states_bitwise_identical(origin, origin_snapshot), 'OUTPUT01 origin after A1')
  call gc_low01_run_inside_profile_trial(origin, -200.0_real64, parameters, evaluation, numerical, physical, dt_day, replay_b)
  call require(states_bitwise_identical(origin, origin_snapshot), 'OUTPUT01 origin after B')
  call gc_low01_run_inside_profile_trial(origin, -60.0_real64, parameters, evaluation, numerical, physical, dt_day, replay_a2)
  call require(states_bitwise_identical(origin, origin_snapshot), 'OUTPUT01 origin after A2')

  call verify_result(replay_a1, -60.0_real64, 1, 'A1')
  call verify_result(replay_b, -200.0_real64, 3, 'B')
  call verify_result(replay_a2, -60.0_real64, 1, 'A2')
  call require(results_bitwise_identical(replay_a1, replay_a2), 'OUTPUT01 A-B-A deterministic replay')
  call require(.not. results_bitwise_identical(replay_a1, replay_b), 'OUTPUT01 B distinct from A')

  call test_refusals(origin, parameters, evaluation, numerical, physical)

  write(*,'(A)') 'GC_LOW01_OUTPUT01_TYPED_FIELDS=PASS'
  write(*,'(A)') 'GC_LOW01_OUTPUT01_IMMUTABLE_ORIGIN=PASS'
  write(*,'(A)') 'GC_LOW01_OUTPUT01_A_B_A_REPLAY=PASS'
  write(*,'(A)') 'GC_LOW01_OUTPUT01_SCOPE_REFUSAL=PASS'
  write(*,'(A)') 'GC_LOW01_OUTPUT01_MASS_CLOSURE=PASS'
  write(*,'(A)') 'GC_LOW01_OUTPUT01_GATE=PASS'

contains

  subroutine configure_parameters(parameter_set, cofgen_raw)
    type(soil_water_parameter_set_t), target, intent(out) :: parameter_set
    real(real64), intent(out) :: cofgen_raw(24,n)
    integer :: k

    parameter_set%parameter_set_id = 51002_int64
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

  subroutine initialize_origin(state, parameter_set, provider)
    type(reference_richards_state_binding_t), intent(out) :: state
    type(soil_water_parameter_set_t), intent(in) :: parameter_set
    type(b110_default_mvg_provider_t), intent(in) :: provider
    real(real64) :: heads(n), water(n), conductivity(n), capacity(n), dkdh(n)
    integer :: k

    do k = 1, n
      heads(k) = origin_h_phreatic_cm - parameter_set%z(k)
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

  subroutine verify_result(result, requested, expected_active, label_text)
    type(gc_low01_mode1_trial_result_t), intent(in) :: result
    real(real64), intent(in) :: requested
    integer, intent(in) :: expected_active
    character(len=*), intent(in) :: label_text

    call require(result%valid, 'OUTPUT01 '//trim(label_text)//' valid')
    call require(result%branch == GC_LOW01_BRANCH_INSIDE_PROFILE, 'OUTPUT01 '//trim(label_text)//' branch')
    call require(result%active_richards_nodes == expected_active, 'OUTPUT01 '//trim(label_text)//' active nodes')
    call require(abs(result%requested_h_phreatic_cm-requested) <= 1.0e-14_real64, 'OUTPUT01 '//trim(label_text)//' requested control')
    call require(abs(result%effective_h_phreatic_cm-result%candidate%gwlinp) <= 1.0e-14_real64, &
         'OUTPUT01 '//trim(label_text)//' effective control')
    call require(.not. result%fllowgwl, 'OUTPUT01 '//trim(label_text)//' fllowgwl false')
    call require(.not. result%retry_advised, 'OUTPUT01 '//trim(label_text)//' no retry')
    call require(transfer(result%qbot_cm_per_day,0_int64) == transfer(result%candidate%qbot,0_int64), &
         'OUTPUT01 '//trim(label_text)//' qbot carrier identity')
    call require(abs(result%mass_residual_cm) <= mass_tol, 'OUTPUT01 '//trim(label_text)//' mass closure')
    call require(result%alternative_solver_calls == 0, 'OUTPUT01 '//trim(label_text)//' no alternative solver')
  end subroutine verify_result

  subroutine test_refusals(origin_state, parameter_set, eval, num, phys)
    type(reference_richards_state_binding_t), intent(in) :: origin_state
    type(soil_water_parameter_set_t), target, intent(in) :: parameter_set
    type(hydraulic_evaluation_context_t), intent(in) :: eval
    type(soil_water_numerical_config_t), intent(in) :: num
    type(soil_water_physical_config_t), intent(in) :: phys
    type(gc_low01_mode1_trial_result_t) :: above, below

    call gc_low01_run_inside_profile_trial(origin_state, -10.0_real64, parameter_set, eval, num, phys, dt_day, above)
    call require(.not. above%valid, 'OUTPUT01 above-top refused')
    call require(above%branch /= GC_LOW01_BRANCH_INSIDE_PROFILE, 'OUTPUT01 above-top branch')

    call gc_low01_run_inside_profile_trial(origin_state, -350.0_real64, parameter_set, eval, num, phys, dt_day, below)
    call require(.not. below%valid, 'OUTPUT01 below-profile refused')
    call require(below%branch /= GC_LOW01_BRANCH_INSIDE_PROFILE, 'OUTPUT01 below-profile branch')
  end subroutine test_refusals

  logical function results_bitwise_identical(a, b) result(same)
    type(gc_low01_mode1_trial_result_t), intent(in) :: a, b

    same = .false.
    if (a%valid .neqv. b%valid) return
    if (a%branch /= b%branch .or. a%active_richards_nodes /= b%active_richards_nodes) return
    if (a%fllowgwl .neqv. b%fllowgwl .or. a%retry_advised .neqv. b%retry_advised) return
    if (a%nonlinear_iterations /= b%nonlinear_iterations .or. a%linear_solves /= b%linear_solves) return
    if (a%backtracking_attempts /= b%backtracking_attempts) return
    if (a%alternative_solver_calls /= b%alternative_solver_calls .or. a%internal_retries /= b%internal_retries) return
    if (transfer(a%requested_h_phreatic_cm,0_int64) /= transfer(b%requested_h_phreatic_cm,0_int64)) return
    if (transfer(a%effective_h_phreatic_cm,0_int64) /= transfer(b%effective_h_phreatic_cm,0_int64)) return
    if (transfer(a%qbot_cm_per_day,0_int64) /= transfer(b%qbot_cm_per_day,0_int64)) return
    if (transfer(a%storage_change_cm,0_int64) /= transfer(b%storage_change_cm,0_int64)) return
    if (transfer(a%mass_residual_cm,0_int64) /= transfer(b%mass_residual_cm,0_int64)) return
    if (.not. states_bitwise_identical(a%candidate,b%candidate)) return
    same = .true.
  end function results_bitwise_identical

  logical function states_bitwise_identical(a, b) result(same)
    type(reference_richards_state_binding_t), intent(in) :: a, b
    integer :: k

    same = .false.
    if (a%active_nodes /= b%active_nodes) return
    do k = 1, a%active_nodes
      if (transfer(a%h(k),0_int64) /= transfer(b%h(k),0_int64)) return
      if (transfer(a%theta(k),0_int64) /= transfer(b%theta(k),0_int64)) return
      if (transfer(a%hm1(k),0_int64) /= transfer(b%hm1(k),0_int64)) return
      if (transfer(a%thetm1(k),0_int64) /= transfer(b%thetm1(k),0_int64)) return
      if (transfer(a%k(k),0_int64) /= transfer(b%k(k),0_int64)) return
      if (transfer(a%dimoca(k),0_int64) /= transfer(b%dimoca(k),0_int64)) return
    end do
    do k = 1, size(a%kmean)
      if (transfer(a%kmean(k),0_int64) /= transfer(b%kmean(k),0_int64)) return
    end do
    if (transfer(a%pond,0_int64) /= transfer(b%pond,0_int64)) return
    if (transfer(a%pondm1,0_int64) /= transfer(b%pondm1,0_int64)) return
    if (transfer(a%gwl,0_int64) /= transfer(b%gwl,0_int64)) return
    if (transfer(a%gwlm1,0_int64) /= transfer(b%gwlm1,0_int64)) return
    if (transfer(a%gwlinp,0_int64) /= transfer(b%gwlinp,0_int64)) return
    if (transfer(a%qtop,0_int64) /= transfer(b%qtop,0_int64)) return
    if (transfer(a%qbot,0_int64) /= transfer(b%qbot,0_int64)) return
    if (transfer(a%hbot,0_int64) /= transfer(b%hbot,0_int64)) return
    if (transfer(a%q0,0_int64) /= transfer(b%q0,0_int64)) return
    if (transfer(a%hsurf,0_int64) /= transfer(b%hsurf,0_int64)) return
    if (transfer(a%runots,0_int64) /= transfer(b%runots,0_int64)) return
    if (a%numbit /= b%numbit) return
    if (a%fllowgwl .neqv. b%fllowgwl) return
    if (a%fldecdt .neqv. b%fldecdt) return
    if (a%flrunoff .neqv. b%flrunoff) return
    if (a%ftoph .neqv. b%ftoph) return
    if (any(a%itnumb /= b%itnumb)) return
    same = .true.
  end function states_bitwise_identical

  subroutine require(value, message)
    logical, intent(in) :: value
    character(len=*), intent(in) :: message
    if (.not. value) then
      write(*,'(A,1X,A)') 'GC_LOW01_OUTPUT01_FAIL', trim(message)
      error stop 1
    end if
  end subroutine require

end program test_gc_low01_output01
