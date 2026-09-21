module mod_gc_low01b_test_providers
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t, source_sink_provider_t
  implicit none
  private

  type, extends(constitutive_hydraulics_provider_t), public :: low01b_constitutive_t
    integer :: marker = 1
  contains
    procedure :: evaluate => low01b_constitutive_evaluate
  end type low01b_constitutive_t

  type, extends(source_sink_provider_t), public :: low01b_zero_source_sink_t
    integer :: marker = 1
  contains
    procedure :: evaluate => low01b_zero_source_sink_evaluate
  end type low01b_zero_source_sink_t

contains

  subroutine low01b_constitutive_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(low01b_constitutive_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)

    if (self%marker /= 1) error stop 'LOW01-B invalid constitutive marker'
    if (size(water_content) /= size(pressure_head) .or. size(conductivity) /= size(pressure_head) .or. &
        size(capacity) /= size(pressure_head) .or. size(dconductivity_dhead) /= size(pressure_head)) then
      error stop 'LOW01-B constitutive shape mismatch'
    end if
    water_content = 0.30_real64
    conductivity = 1.0_real64
    capacity = 0.0_real64
    dconductivity_dhead = 0.0_real64
  end subroutine low01b_constitutive_evaluate

  subroutine low01b_zero_source_sink_evaluate(self, pressure_head, water_content, source, sink)
    class(low01b_zero_source_sink_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:), water_content(:)
    real(real64), intent(out) :: source(:), sink(:)

    if (self%marker /= 1) error stop 'LOW01-B invalid source/sink marker'
    if (size(water_content) /= size(pressure_head) .or. size(source) /= size(pressure_head) .or. &
        size(sink) /= size(pressure_head)) then
      error stop 'LOW01-B source/sink shape mismatch'
    end if
    source = 0.0_real64
    sink = 0.0_real64
  end subroutine low01b_zero_source_sink_evaluate

end module mod_gc_low01b_test_providers


program test_gc_low01b_inside_profile
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t
  use mod_reference_richards_workspace, only: reference_richards_workspace_t
  use mod_reference_richards_state_binding, only: reference_richards_state_binding_t, FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t, &
       soil_water_numerical_config_t, soil_water_physical_config_t, soil_water_parameter_set_t
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_gc_low01b_test_providers, only: low01b_constitutive_t, low01b_zero_source_sink_t
  implicit none

  integer, parameter :: n = 4
  real(real64), parameter :: z_cm(n) = [-25.0_real64, -75.0_real64, -150.0_real64, -250.0_real64]
  real(real64), parameter :: dz_cm(n) = [50.0_real64, 50.0_real64, 100.0_real64, 100.0_real64]
  real(real64), parameter :: dist_cm(n) = [25.0_real64, 50.0_real64, 75.0_real64, 100.0_real64]
  real(real64), parameter :: gwl_cases(3) = [-60.0_real64, -120.0_real64, -200.0_real64]
  integer, parameter :: expected_nn(3) = [1, 2, 3]
  real(real64), parameter :: dt_day = 0.25_real64
  real(real64), parameter :: tol = 1.0e-12_real64

  type(soil_water_parameter_set_t), target :: parameters
  type(low01b_constitutive_t), target :: constitutive
  type(low01b_zero_source_sink_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(hydraulic_evaluation_context_t) :: evaluation
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

  parameters%parameter_set_id = 51001_int64
  parameters%active_nodes = n
  allocate(parameters%z(n), parameters%dz(n), parameters%node_distance(n))
  parameters%z = z_cm
  parameters%dz = dz_cm
  parameters%node_distance = dist_cm

  evaluation%constitutive => constitutive
  evaluation%source_sink => source_sink
  evaluation%top_boundary => top

  do i = 1, size(gwl_cases)
    call run_case(gwl_cases(i), expected_nn(i), parameters, evaluation)
  end do

  write(*,'(A)') 'GC_LOW01B_INSIDE_PROFILE_CASES=PASS'
  write(*,'(A)') 'GC_LOW01B_SATURATED_CONTINUATION=PASS'
  write(*,'(A)') 'GC_LOW01B_QBOT_DIAGNOSED=PASS'
  write(*,'(A)') 'GC_LOW01B_MASS_CLOSURE=PASS'
  write(*,'(A)') 'GC_LOW01B_BITWISE_REPLAY=PASS'
  write(*,'(A)') 'GC_LOW01B_LIVE_GATE=PASS'

contains

  subroutine run_case(gwl_cm, expected_active_nn, parameter_set, eval)
    real(real64), intent(in) :: gwl_cm
    integer, intent(in) :: expected_active_nn
    type(soil_water_parameter_set_t), target, intent(in) :: parameter_set
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

    call initialize_state(first, gwl_cm, parameter_set)
    call headcalc(worker1, workspace1, history1, first, eval, boundary, numerical, physical, dt_day, parameter_set)
    call verify_candidate(first, gwl_cm, nn, parameter_set, worker1, 'first')

    call initialize_state(second, gwl_cm, parameter_set)
    call headcalc(worker2, workspace2, history2, second, eval, boundary, numerical, physical, dt_day, parameter_set)
    call verify_candidate(second, gwl_cm, nn, parameter_set, worker2, 'second')
    call require(states_bitwise_identical(first, second), 'LOW01-B repeated trial bitwise identity')

    write(*,'(A,F0.8)') 'GC_LOW01B_GWL_CM=', gwl_cm
    write(*,'(A,I0)') 'GC_LOW01B_ACTIVE_NN=', nn
    write(*,'(A,ES24.16)') 'GC_LOW01B_QBOT_CM_PER_DAY=', first%qbot
    write(*,'(A,I0)') 'GC_LOW01B_NONLINEAR_ITERATIONS=', worker1%diagnostics%nonlinear_iterations
  end subroutine run_case

  subroutine initialize_state(state, gwl_cm, parameter_set)
    type(reference_richards_state_binding_t), intent(out) :: state
    real(real64), intent(in) :: gwl_cm
    type(soil_water_parameter_set_t), intent(in) :: parameter_set
    integer :: k

    state%active_nodes = n
    allocate(state%h(n), state%theta(n), state%hm1(n), state%thetm1(n))
    allocate(state%k(n), state%kmean(n+1), state%dimoca(n), state%itnumb(100,2))

    do k = 1, n
      state%h(k) = gwl_cm - parameter_set%z(k)
    end do
    state%theta = 0.30_real64
    state%hm1 = state%h
    state%thetm1 = state%theta
    state%k = 1.0_real64
    state%kmean = 1.0_real64
    state%dimoca = 0.0_real64
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
  end subroutine initialize_state

  subroutine verify_candidate(state, gwl_cm, nn, parameter_set, worker, label)
    type(reference_richards_state_binding_t), intent(in) :: state
    real(real64), intent(in) :: gwl_cm
    integer, intent(in) :: nn
    type(soil_water_parameter_set_t), intent(in) :: parameter_set
    type(a23bu_worker_context_t), intent(in) :: worker
    character(len=*), intent(in) :: label
    real(real64) :: storage_change, mass_residual
    integer :: k

    call require(.not. state%fllowgwl, 'LOW01-B '//trim(label)//' fllowgwl false')
    call require(.not. state%fldecdt, 'LOW01-B '//trim(label)//' no dt reduction')
    call require(.not. worker%control%request_dt_reduction, 'LOW01-B '//trim(label)//' worker no dt reduction')
    call require(worker%diagnostics%alternative_solver_calls == 0, 'LOW01-B '//trim(label)//' no alternative solver')
    call require(abs(state%gwlinp - gwl_cm) <= tol, 'LOW01-B '//trim(label)//' gwlinp retained')
    call require(abs(state%qbot) <= tol, 'LOW01-B '//trim(label)//' qbot zero')

    do k = 1, n
      call require(abs(state%h(k) - (gwl_cm - parameter_set%z(k))) <= tol, &
           'LOW01-B '//trim(label)//' hydrostatic pressure profile')
    end do
    do k = nn+1, n
      call require(abs(state%theta(k) - 0.30_real64) <= tol, &
           'LOW01-B '//trim(label)//' saturated continuation theta')
    end do

    storage_change = sum((state%theta - state%thetm1) * parameter_set%dz)
    mass_residual = storage_change - dt_day * (state%qtop + state%qbot)
    call require(abs(storage_change) <= tol, 'LOW01-B '//trim(label)//' zero storage change')
    call require(abs(mass_residual) <= tol, 'LOW01-B '//trim(label)//' mass closure')
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
