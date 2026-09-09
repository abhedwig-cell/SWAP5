program test_fsi25_reference_indicator_production_seam
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, soil_water_temporal_indicator_request_t, &
       soil_water_temporal_indicator_result_t, SW_SOLVE_CONVERGED, SW_TEMPORAL_INDICATOR_AVAILABLE, &
       SW_TEMPORAL_INDICATOR_UNAVAILABLE
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: total_dt = 0.25_real64, hard_mass_gate = 1.0e-12_real64
  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: top_provider
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  type(soil_water_physical_state_t) :: initial_state
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: result
  type(soil_water_temporal_indicator_request_t) :: indicator_request
  type(soil_water_temporal_indicator_result_t) :: warmup_result, indicator_result
  real(real64), allocatable, target :: drainage(:,:), subsurface(:), root_sink(:)
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: h0, jump, hbot, conductivity0, mass_residual
  real(real64) :: heads0(numnod), water0(numnod), conductivity0_nodes(numnod), capacity0(numnod), dkdh0(numnod)
  real(real64) :: static_residual(numnod), hdot_n(numnod), storage0, storage1, total_in, total_out
  real(real64) :: state_head_snapshot(numnod), state_water_snapshot(numnod), solver_mass
  integer :: nonlinear_before, jacobian_before, linear_before, backtracking_before, retries_before
  integer :: i

  call read_inputs(h0, jump)
  hbot = h0+jump
  call configure_problem(h0, parameters, hydraulic_parameters, constitutive, source_sink, top_provider, &
       initial_state, drainage, subsurface, root_sink, cofgen, conductivity0)

  heads0 = h0
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, total_dt)
  call constitutive%evaluate(heads0, water0, conductivity0_nodes, capacity0, dkdh0)
  call require(all(ieee_is_finite(capacity0)) .and. all(capacity0 > 0.0_real64), 'bootstrap capacity')
  call require(all(ieee_is_finite(conductivity0_nodes)) .and. all(conductivity0_nodes > 0.0_real64), &
       'bootstrap conductivity')
  do i = 2, numnod
     call require(transfer(conductivity0_nodes(i),0_int64) == transfer(conductivity0_nodes(1),0_int64), &
          'uniform initial conductivity')
  end do
  call require(transfer(conductivity0,0_int64) == transfer(conductivity0_nodes(1),0_int64), 'k0 mapping')

  static_residual = 0.0_real64
  static_residual(numnod) = conductivity0*(h0-hbot)/(0.5_real64*parameters%dz(numnod))
  hdot_n = -static_residual/(capacity0*parameters%dz)
  call require(all(ieee_is_finite(hdot_n)), 'finite previous derivative')

  request = soil_water_solve_request_t()
  request%parameters => parameters
  request%base_state = initial_state
  request%step_duration = total_dt
  request%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
  request%boundary%bottom_mode = 5
  request%boundary%top_flux = -conductivity0
  request%boundary%top_head = h0
  request%boundary%bottom_flux = 12345.678_real64
  request%boundary%bottom_head = hbot
  request%physical%macropore_active = .false.
  request%numerical%max_iterations = 8
  request%numerical%max_backtracking = 4
  request%numerical%conductivity_implicit_mode = 0
  request%numerical%conductivity_mean_method = 1
  request%numerical%min_step_duration = 1.0e-6_real64
  request%numerical%compartment_balance_tolerance = hard_mass_gate
  request%numerical%total_balance_tolerance = hard_mass_gate
  request%numerical%head_abs_tolerance = 1.0e-12_real64
  request%numerical%head_rel_tolerance = 1.0e-12_real64
  request%numerical%ponding_tolerance = 1.0e-12_real64
  request%evaluation%constitutive => constitutive
  request%evaluation%source_sink => source_sink
  request%evaluation%top_boundary => top_provider

  storage0 = sum(initial_state%water_content*parameters%dz)+initial_state%ponding_depth
  call solver%solve(request, workspace, result)
  call require(result%status == SW_SOLVE_CONVERGED, 'principal solve converged')
  storage1 = sum(result%candidate_state%water_content*parameters%dz)+result%candidate_state%ponding_depth
  total_in = max(0.0_real64,-result%top_flux)*total_dt+max(0.0_real64,result%bottom_flux)*total_dt
  total_out = max(0.0_real64,result%top_flux)*total_dt+max(0.0_real64,-result%bottom_flux)*total_dt
  mass_residual = storage1-storage0-(total_in-total_out)
  solver_mass = abs(result%unrounded_mass_balance_residual)
  call require(max(abs(mass_residual),solver_mass) <= hard_mass_gate, 'principal hard mass gate')

  state_head_snapshot = result%candidate_state%pressure_head
  state_water_snapshot = result%candidate_state%water_content
  nonlinear_before = workspace%legacy_worker%diagnostics%nonlinear_iterations
  jacobian_before = workspace%legacy_worker%diagnostics%jacobian_builds
  linear_before = workspace%legacy_worker%diagnostics%linear_solves
  backtracking_before = workspace%legacy_worker%diagnostics%backtracking_attempts
  retries_before = workspace%legacy_worker%diagnostics%internal_retries

  call solver%evaluate_temporal_indicator(request, result, indicator_request, workspace, warmup_result)
  call require(warmup_result%status == SW_TEMPORAL_INDICATOR_UNAVAILABLE, 'warmup unavailable without history')
  call require(.not. warmup_result%available, 'warmup cannot claim indicator')
  call require(allocated(warmup_result%current_right_derivative), 'warmup returns current derivative')
  call require(maxval(abs(warmup_result%current_right_derivative - &
       (result%candidate_state%pressure_head-request%base_state%pressure_head)/total_dt)) == 0.0_real64, &
       'warmup derivative exact')

  indicator_request%previous_right_derivative_available = .true.
  allocate(indicator_request%previous_right_derivative(numnod))
  indicator_request%previous_right_derivative = hdot_n
  call solver%evaluate_temporal_indicator(request, result, indicator_request, workspace, indicator_result)

  call require(indicator_result%status == SW_TEMPORAL_INDICATOR_AVAILABLE, 'production indicator available')
  call require(indicator_result%available, 'production indicator availability flag')
  call require(indicator_result%additional_full_nonlinear_solves == 0, 'no extra nonlinear solve')
  call require(indicator_result%additional_tridiagonal_solves == 1, 'exactly one defect tridag')
  call require(ieee_is_finite(indicator_result%head_inf_bound) .and. indicator_result%head_inf_bound >= 0.0_real64, &
       'finite nonnegative head bound')
  call require(ieee_is_finite(indicator_result%raw_m_norm) .and. &
       ieee_is_finite(indicator_result%defect_m_norm) .and. ieee_is_finite(indicator_result%bounded_m_norm), &
       'finite norm diagnostics')
  call require(maxval(abs(result%candidate_state%pressure_head-state_head_snapshot)) == 0.0_real64, &
       'candidate head noninterference')
  call require(maxval(abs(result%candidate_state%water_content-state_water_snapshot)) == 0.0_real64, &
       'candidate water noninterference')
  call require(workspace%legacy_worker%diagnostics%nonlinear_iterations == nonlinear_before, 'nonlinear counter noninterference')
  call require(workspace%legacy_worker%diagnostics%jacobian_builds == jacobian_before, 'jacobian counter noninterference')
  call require(workspace%legacy_worker%diagnostics%linear_solves == linear_before, 'principal linear counter noninterference')
  call require(workspace%legacy_worker%diagnostics%backtracking_attempts == backtracking_before, &
       'backtracking counter noninterference')
  call require(workspace%legacy_worker%diagnostics%internal_retries == retries_before, 'retry counter noninterference')

  write(*,'(A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,A)') &
       'FSI25_PROD_ROW:H0=',h0,':JUMP=',jump,':RAW_M=',indicator_result%raw_m_norm, &
       ':D2_M=',2.0_real64*indicator_result%defect_m_norm,':BM=',indicator_result%bounded_m_norm, &
       ':BINF=',indicator_result%head_inf_bound,':MIN_M=',indicator_result%min_mass_weight, &
       ':ROUTE=',trim(indicator_result%route)
  write(*,'(A,ES26.17E3,A,I0,A,I0,A,I0)') 'FSI25_PROD_DIAG:MASS=',max(abs(mass_residual),solver_mass), &
       ':EXTRA_NONLINEAR=',indicator_result%additional_full_nonlinear_solves, &
       ':EXTRA_TRIDAG=',indicator_result%additional_tridiagonal_solves, &
       ':PRINCIPAL_LINEAR=',linear_before
  write(*,'(A)') 'FSI25_REFERENCE_INDICATOR_CASE PASS'

contains

  subroutine read_inputs(initial_head, jump_head)
    real(real64), intent(out) :: initial_head, jump_head
    character(len=128) :: arg
    integer :: stat
    if (command_argument_count() /= 2) error stop 'F-SI25 test requires h0 jump'
    call get_command_argument(1,arg)
    read(arg,*,iostat=stat) initial_head
    if (stat /= 0) error stop 'bad h0'
    call get_command_argument(2,arg)
    read(arg,*,iostat=stat) jump_head
    if (stat /= 0) error stop 'bad jump'
  end subroutine read_inputs

  subroutine configure_problem(initial_head,p,hp,cp,sp,tp,state,qdra,qssdi,qrot,c,k0)
    real(real64), intent(in) :: initial_head
    type(soil_water_parameter_set_t), target, intent(out) :: p
    type(b110_default_mvg_parameters_t), target, intent(out) :: hp
    type(b110_default_mvg_provider_t), target, intent(out) :: cp
    type(b110_source_sink_provider_t), target, intent(out) :: sp
    type(fixed_flux_top_boundary_provider_t), target, intent(out) :: tp
    type(soil_water_physical_state_t), intent(out) :: state
    real(real64), allocatable, target, intent(out) :: qdra(:,:),qssdi(:),qrot(:)
    real(real64), allocatable, intent(out) :: c(:,:)
    real(real64), intent(out) :: k0
    real(real64) :: heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    integer :: k

    p%parameter_set_id = 250251_int64
    p%active_nodes = numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)

    allocate(c(24,numnod))
    c = 0.0_real64
    do k = 1, numnod
       c(1,k)=0.032_real64; c(2,k)=0.423_real64; c(3,k)=4.75_real64
       c(4,k)=0.0135_real64; c(5,k)=0.365_real64; c(6,k)=1.455_real64
       c(7,k)=1.0_real64-1.0_real64/c(6,k); c(8,k)=c(4,k)
       c(9,k)=0.0_real64; c(10,k)=c(3,k); c(11,k)=0.999_real64
       c(12,k)=0.99_real64*c(3,k); c(22,k)=-1.0e6_real64; c(23,k)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp,c)
    call bind_b110_default_mvg_provider(cp,hp,total_dt)
    heads = initial_head
    call cp%evaluate(heads,water,conductivity,capacity,dkdh)
    do k = 2, numnod
       call require(transfer(conductivity(k),0_int64) == transfer(conductivity(1),0_int64), &
            'uniform initial K configure')
    end do
    k0 = conductivity(1)

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64

    allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
    qdra = 0.0_real64
    qssdi = 0.0_real64
    qrot = 0.0_real64
    call bind_b110_source_sink_provider(sp,qdra,qssdi,qrot)
  end subroutine configure_problem

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
       write(*,'(A,1X,A)') 'FSI25_REFERENCE_INDICATOR_FAIL',trim(label)
       error stop 1
    end if
  end subroutine require

end program test_fsi25_reference_indicator_production_seam
