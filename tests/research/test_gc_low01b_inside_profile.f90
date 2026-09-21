program test_gc_low01b_inside_profile
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_reference_richards_state_binding, only: reference_richards_state_binding_t
  use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_numerical_config_t, &
       soil_water_physical_config_t, soil_water_parameter_set_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use MOD_MvG, only: gc_low01_bind_mvg
  use mod_gc_low01_mode1_trial_carrier, only: gc_low01_mode1_trial_result_t, &
       gc_low01_run_inside_profile_trial, GC_LOW01_BRANCH_INSIDE_PROFILE
  implicit none

  integer, parameter :: n = 4
  real(real64), parameter :: z_cm(n) = [-25.0_real64, -75.0_real64, -150.0_real64, -250.0_real64]
  real(real64), parameter :: dz_cm(n) = [50.0_real64, 50.0_real64, 100.0_real64, 100.0_real64]
  real(real64), parameter :: dist_cm(n) = [25.0_real64, 50.0_real64, 75.0_real64, 100.0_real64]
  real(real64), parameter :: gwl_cases(3) = [-60.0_real64, -120.0_real64, -200.0_real64]
  integer, parameter :: expected_nn(3) = [1, 2, 3]
  real(real64), parameter :: origin_gwl_cm = -120.0_real64
  real(real64), parameter :: dt_day = 0.01_real64
  real(real64), parameter :: strict_tol = 1.0e-10_real64

  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(hydraulic_evaluation_context_t) :: evaluation
  type(soil_water_numerical_config_t) :: numerical
  type(soil_water_physical_config_t) :: physical
  type(reference_richards_state_binding_t) :: origin, origin_snapshot
  type(gc_low01_mode1_trial_result_t) :: first(3), second(3)
  real(real64), target :: drainage(1,n), irrigation(n), root_sink(n)
  real(real64) :: raw(24,n)
  integer :: i

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

  numerical%max_iterations = 24
  numerical%max_backtracking = 8
  numerical%conductivity_implicit_mode = 0
  numerical%conductivity_mean_method = 1
  numerical%min_step_duration = 1.0e-10_real64
  numerical%compartment_balance_tolerance = strict_tol
  numerical%total_balance_tolerance = strict_tol
  numerical%head_abs_tolerance = strict_tol
  numerical%head_rel_tolerance = strict_tol
  numerical%ponding_tolerance = strict_tol
  physical%macropore_active = .false.

  call initialize_origin(origin, parameters, constitutive)
  origin_snapshot = origin

  do i = 1, size(gwl_cases)
    call gc_low01_run_inside_profile_trial(origin, gwl_cases(i), parameters, evaluation, numerical, physical, dt_day, first(i))
    call verify_result(first(i), gwl_cases(i), expected_nn(i), parameters, hydraulic_parameters, constitutive, 'first')

    call gc_low01_run_inside_profile_trial(origin, gwl_cases(i), parameters, evaluation, numerical, physical, dt_day, second(i))
    call verify_result(second(i), gwl_cases(i), expected_nn(i), parameters, hydraulic_parameters, constitutive, 'second')

    call require(results_bitwise_identical(first(i), second(i)), 'LOW01-B repeated trial bitwise identity')
    call require(states_bitwise_identical(origin, origin_snapshot), 'LOW01-B immutable origin retained')

    write(*,'(A,F0.8)') 'GC_LOW01B_GWL_CM=', gwl_cases(i)
    write(*,'(A,I0)') 'GC_LOW01B_ACTIVE_NN=', first(i)%active_richards_nodes
    write(*,'(A,ES24.16E3)') 'GC_LOW01B_QBOT_CM_PER_DAY=', first(i)%qbot_cm_per_day
    write(*,'(A,ES24.16E3)') 'GC_LOW01B_STORAGE_CHANGE_CM=', first(i)%storage_change_cm
    write(*,'(A,ES24.16E3)') 'GC_LOW01B_MASS_RESIDUAL_CM=', first(i)%mass_residual_cm
    write(*,'(A,I0)') 'GC_LOW01B_NONLINEAR_ITERATIONS=', first(i)%nonlinear_iterations
  end do

  call require(abs(first(2)%qbot_cm_per_day) <= strict_tol, 'LOW01-B hydrostatic identity qbot')
  call require(abs(first(2)%storage_change_cm) <= strict_tol, 'LOW01-B hydrostatic identity storage')
  call require(.not. results_bitwise_identical(first(1), first(2)) .or. &
       .not. results_bitwise_identical(first(3), first(2)), 'LOW01-B nonvacuous control response')

  write(*,'(A)') 'GC_LOW01B_SINGLE_CONSTITUTIVE_OWNER=PASS'
  write(*,'(A)') 'GC_LOW01B_IMMUTABLE_ORIGIN=PASS'
  write(*,'(A)') 'GC_LOW01B_COMPLETE_TRIAL_CARRIER=PASS'
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

  subroutine initialize_origin(state, parameter_set, provider)
    type(reference_richards_state_binding_t), intent(out) :: state
    type(soil_water_parameter_set_t), intent(in) :: parameter_set
    type(b110_default_mvg_provider_t), intent(in) :: provider
    real(real64) :: heads(n), water(n), conductivity(n), capacity(n), dkdh(n)
    integer :: k

    do k = 1, n
      heads(k) = origin_gwl_cm - parameter_set%z(k)
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
    state%gwl = origin_gwl_cm
    state%gwlm1 = origin_gwl_cm
    state%gwlinp = origin_gwl_cm
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

  subroutine verify_result(result, gwl_cm, nn, parameter_set, hp, provider, label_text)
    type(gc_low01_mode1_trial_result_t), intent(in) :: result
    real(real64), intent(in) :: gwl_cm
    integer, intent(in) :: nn
    type(soil_water_parameter_set_t), intent(in) :: parameter_set
    type(b110_default_mvg_parameters_t), intent(in) :: hp
    type(b110_default_mvg_provider_t), intent(in) :: provider
    character(len=*), intent(in) :: label_text
    real(real64) :: saturated_head(n), saturated_water(n), saturated_k(n), saturated_c(n), saturated_d(n)
    integer :: k

    call require(result%valid, 'LOW01-B '//trim(label_text)//' valid carrier result')
    call require(result%branch == GC_LOW01_BRANCH_INSIDE_PROFILE, 'LOW01-B '//trim(label_text)//' inside branch')
    call require(result%active_richards_nodes == nn, 'LOW01-B '//trim(label_text)//' active NN')
    call require(.not. result%fllowgwl, 'LOW01-B '//trim(label_text)//' fllowgwl false')
    call require(.not. result%retry_advised, 'LOW01-B '//trim(label_text)//' no retry')
    call require(result%alternative_solver_calls == 0, 'LOW01-B '//trim(label_text)//' no alternative solver')
    call require(abs(result%requested_h_phreatic_cm-gwl_cm) <= strict_tol, 'LOW01-B requested Hphi')
    call require(abs(result%effective_h_phreatic_cm-gwl_cm) <= strict_tol, 'LOW01-B effective Hphi')
    call require(transfer(result%qbot_cm_per_day,0_int64) == transfer(result%candidate%qbot,0_int64), &
         'LOW01-B carrier qbot authority')
    call require(ieee_is_finite(result%qbot_cm_per_day), 'LOW01-B finite qbot')
    call require(abs(result%mass_residual_cm) <= strict_tol, 'LOW01-B independent mass closure')
    call require(.not. hp%ksatexm_extension_enabled, 'LOW01-B KSATEXM disabled result')

    saturated_head = 0.0_real64
    call provider%evaluate(saturated_head, saturated_water, saturated_k, saturated_c, saturated_d)
    do k = nn+1, n
      call require(transfer(result%candidate%theta(k),0_int64) == transfer(saturated_water(k),0_int64), &
           'LOW01-B provider-owned saturated theta')
      call require(transfer(saturated_water(k),0_int64) == transfer(hp%cofgen(2,k),0_int64), &
           'LOW01-B source-equivalent theta_s')
      call require(transfer(saturated_k(k),0_int64) == transfer(hp%cofgen(3,k),0_int64), &
           'LOW01-B source-equivalent K_s')
    end do
    call require(all(ieee_is_finite(result%candidate%h)), 'LOW01-B finite candidate heads')
    call require(all(ieee_is_finite(result%candidate%theta)), 'LOW01-B finite candidate theta')
    call require(parameter_set%active_nodes == n, 'LOW01-B parameter shape')
  end subroutine verify_result

  logical function results_bitwise_identical(a,b) result(same)
    type(gc_low01_mode1_trial_result_t), intent(in) :: a,b
    same = .false.
    if (a%valid .neqv. b%valid) return
    if (a%branch /= b%branch .or. a%active_richards_nodes /= b%active_richards_nodes) return
    if (a%fllowgwl .neqv. b%fllowgwl .or. a%retry_advised .neqv. b%retry_advised) return
    if (transfer(a%requested_h_phreatic_cm,0_int64) /= transfer(b%requested_h_phreatic_cm,0_int64)) return
    if (transfer(a%effective_h_phreatic_cm,0_int64) /= transfer(b%effective_h_phreatic_cm,0_int64)) return
    if (transfer(a%qbot_cm_per_day,0_int64) /= transfer(b%qbot_cm_per_day,0_int64)) return
    if (transfer(a%storage_change_cm,0_int64) /= transfer(b%storage_change_cm,0_int64)) return
    if (transfer(a%mass_residual_cm,0_int64) /= transfer(b%mass_residual_cm,0_int64)) return
    if (a%nonlinear_iterations /= b%nonlinear_iterations .or. a%linear_solves /= b%linear_solves) return
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
    end do
    if (transfer(a%qtop,0_int64) /= transfer(b%qtop,0_int64)) return
    if (transfer(a%qbot,0_int64) /= transfer(b%qbot,0_int64)) return
    if (transfer(a%gwl,0_int64) /= transfer(b%gwl,0_int64)) return
    if (transfer(a%gwlinp,0_int64) /= transfer(b%gwlinp,0_int64)) return
    if (a%fllowgwl .neqv. b%fllowgwl) return
    if (a%fldecdt .neqv. b%fldecdt) return
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
