program test_fpe18_richards_full_path_workspace_timing
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  implicit none

  real(real64), parameter :: total_dt = 0.25_real64, hard_mass_gate = 1.0e-12_real64
  character(len=16) :: mode
  integer :: calls, warmup, i
  integer(int64) :: tick0, tick1, tick_rate
  real(real64) :: h0, jump, hbot, conductivity0
  real(real64) :: cpu0, cpu1, wall_seconds, cpu_seconds, checksum, max_mass
  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: reusable
  type(soil_water_physical_state_t) :: initial_state
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: result, fresh_result, reuse_result, reuse_result_2
  real(real64), allocatable, target :: drainage(:,:), subsurface(:), root_sink(:)
  real(real64), allocatable :: cofgen(:,:)

  call read_args(mode, h0, jump, calls, warmup)
  hbot = h0 + jump
  call configure_problem(h0, parameters, hydraulic_parameters, constitutive, source_sink, top_provider, &
       initial_state, drainage, subsurface, root_sink, cofgen, conductivity0)
  call configure_request(parameters, constitutive, source_sink, top_provider, initial_state, conductivity0, h0, hbot, request)

  select case (trim(mode))
  case ('verify')
    call solve_fresh(solver, request, fresh_result)
    call solve_reused(solver, request, reusable, reuse_result)
    call solve_reused(solver, request, reusable, reuse_result_2)
    call require_exact_result(fresh_result, reuse_result, 'fresh versus first reuse')
    call require_exact_result(fresh_result, reuse_result_2, 'fresh versus repeated reuse')
    call require_mass(request, fresh_result, max_mass)
    call require_mass(request, reuse_result, max_mass)
    call require_mass(request, reuse_result_2, max_mass)
    write(*,'(A,ES26.17E3,A,ES26.17E3,A,I0,A,I0,A,I0,A,I0,A,ES26.17E3)') &
         'FPE18_FULL_VERIFY h0=',h0,',jump=',jump,',status=',fresh_result%status, &
         ',iterations=',fresh_result%diagnostics%nonlinear_iterations, &
         ',backtracking=',fresh_result%diagnostics%backtracking_attempts, &
         ',workspace_generation=',reusable%richards%generation, &
         ',mass=',abs(fresh_result%unrounded_mass_balance_residual)
    write(*,'(A)') 'FPE18_FULL_EQUIVALENCE=PASS'

  case ('fresh')
    do i = 1, warmup
      call solve_fresh(solver, request, result)
      call require(result%status == SW_SOLVE_CONVERGED, 'fresh warmup convergence')
    end do
    call solve_fresh(solver, request, result)
    call require_mass(request, result, max_mass)
    checksum = result_checksum(result)
    call cpu_time(cpu0)
    call system_clock(tick0, tick_rate)
    do i = 1, calls
      call solve_fresh(solver, request, result)
      if (result%status /= SW_SOLVE_CONVERGED) error stop 'F-PE18 fresh timing nonconvergence'
      checksum = checksum + result_checksum(result)
    end do
    call system_clock(tick1)
    call cpu_time(cpu1)
    call emit_timing('fresh', h0, jump, calls, warmup, tick0, tick1, tick_rate, cpu0, cpu1, checksum, max_mass)

  case ('reuse')
    do i = 1, warmup
      call solve_reused(solver, request, reusable, result)
      call require(result%status == SW_SOLVE_CONVERGED, 'reuse warmup convergence')
    end do
    call solve_reused(solver, request, reusable, result)
    call require_mass(request, result, max_mass)
    checksum = result_checksum(result)
    call cpu_time(cpu0)
    call system_clock(tick0, tick_rate)
    do i = 1, calls
      call solve_reused(solver, request, reusable, result)
      if (result%status /= SW_SOLVE_CONVERGED) error stop 'F-PE18 reuse timing nonconvergence'
      checksum = checksum + result_checksum(result)
    end do
    call system_clock(tick1)
    call cpu_time(cpu1)
    call emit_timing('reuse', h0, jump, calls, warmup, tick0, tick1, tick_rate, cpu0, cpu1, checksum, max_mass)

  case default
    error stop 'F-PE18 mode must be verify, fresh or reuse'
  end select

contains

  subroutine solve_fresh(s, req, res)
    type(reference_richards_legacy_solver_t), intent(inout) :: s
    type(soil_water_solve_request_t), intent(in) :: req
    type(soil_water_solve_result_t), intent(out) :: res
    type(reference_richards_legacy_workspace_t) :: workspace
    call s%solve(req, workspace, res)
  end subroutine solve_fresh

  subroutine solve_reused(s, req, workspace, res)
    type(reference_richards_legacy_solver_t), intent(inout) :: s
    type(soil_water_solve_request_t), intent(in) :: req
    type(reference_richards_legacy_workspace_t), intent(inout) :: workspace
    type(soil_water_solve_result_t), intent(out) :: res
    call s%solve(req, workspace, res)
  end subroutine solve_reused

  subroutine configure_request(p, cp, sp, tp, state, k0, initial_head, bottom_head, req)
    type(soil_water_parameter_set_t), target, intent(in) :: p
    type(b110_default_mvg_provider_t), target, intent(in) :: cp
    type(b110_source_sink_provider_t), target, intent(in) :: sp
    type(fmr04_fixed_flux_top_provider_t), target, intent(in) :: tp
    type(soil_water_physical_state_t), intent(in) :: state
    real(real64), intent(in) :: k0, initial_head, bottom_head
    type(soil_water_solve_request_t), intent(out) :: req

    req = soil_water_solve_request_t()
    req%parameters => p
    req%base_state = state
    req%step_duration = total_dt
    req%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%bottom_mode = 5
    req%boundary%top_flux = -k0
    req%boundary%top_head = initial_head
    req%boundary%bottom_flux = 12345.678_real64
    req%boundary%bottom_head = bottom_head
    req%physical%macropore_active = .false.
    req%numerical%max_iterations = 8
    req%numerical%max_backtracking = 4
    req%numerical%conductivity_implicit_mode = 0
    req%numerical%conductivity_mean_method = 1
    req%numerical%min_step_duration = 1.0e-6_real64
    req%numerical%compartment_balance_tolerance = hard_mass_gate
    req%numerical%total_balance_tolerance = hard_mass_gate
    req%numerical%head_abs_tolerance = 1.0e-12_real64
    req%numerical%head_rel_tolerance = 1.0e-12_real64
    req%numerical%ponding_tolerance = 1.0e-12_real64
    req%evaluation%constitutive => cp
    req%evaluation%source_sink => sp
    req%evaluation%top_boundary => tp
  end subroutine configure_request

  subroutine configure_problem(initial_head, p, hp, cp, sp, tp, state, qdra, qssdi, qrot, c, k0)
    real(real64), intent(in) :: initial_head
    type(soil_water_parameter_set_t), target, intent(out) :: p
    type(b110_default_mvg_parameters_t), target, intent(out) :: hp
    type(b110_default_mvg_provider_t), target, intent(out) :: cp
    type(b110_source_sink_provider_t), target, intent(out) :: sp
    type(fmr04_fixed_flux_top_provider_t), target, intent(out) :: tp
    type(soil_water_physical_state_t), intent(out) :: state
    real(real64), allocatable, target, intent(out) :: qdra(:,:), qssdi(:), qrot(:)
    real(real64), allocatable, intent(out) :: c(:,:)
    real(real64), intent(out) :: k0
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: k

    p%parameter_set_id = 240242_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod))
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
    call initialize_b110_default_mvg_parameters(hp, c)
    call bind_b110_default_mvg_provider(cp, hp, total_dt)
    heads = initial_head
    call cp%evaluate(heads, water, conductivity, capacity, dkdh)
    do k = 2, numnod
      call require(bit_equal_real(conductivity(k), conductivity(1)), 'uniform initial conductivity')
    end do
    k0 = conductivity(1)

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64

    allocate(qdra(1,numnod), qssdi(numnod), qrot(numnod))
    qdra = 0.0_real64
    qssdi = 0.0_real64
    qrot = 0.0_real64
    call bind_b110_source_sink_provider(sp, qdra, qssdi, qrot)
    if (.not. same_type_as(tp,tp)) error stop 'F-PE18 invalid top provider type'
  end subroutine configure_problem

  subroutine require_exact_result(a, b, label)
    type(soil_water_solve_result_t), intent(in) :: a, b
    character(len=*), intent(in) :: label

    call require(a%status == b%status, label//' status')
    call require(a%retry_advised .eqv. b%retry_advised, label//' retry flag')
    call require(a%candidate_state%active_nodes == b%candidate_state%active_nodes, label//' active nodes')
    call require(allocated(a%candidate_state%pressure_head) .and. allocated(b%candidate_state%pressure_head), &
         label//' pressure allocation')
    call require(allocated(a%candidate_state%water_content) .and. allocated(b%candidate_state%water_content), &
         label//' water allocation')
    call require(size(a%candidate_state%pressure_head) == size(b%candidate_state%pressure_head), label//' pressure shape')
    call require(size(a%candidate_state%water_content) == size(b%candidate_state%water_content), label//' water shape')
    call require(bit_equal_array(a%candidate_state%pressure_head, b%candidate_state%pressure_head), label//' pressure bits')
    call require(bit_equal_array(a%candidate_state%water_content, b%candidate_state%water_content), label//' water bits')
    call require(bit_equal_real(a%candidate_state%ponding_depth, b%candidate_state%ponding_depth), label//' pond bits')
    call require(bit_equal_real(a%candidate_state%groundwater_level, b%candidate_state%groundwater_level), label//' gwl bits')
    call require(bit_equal_real(a%top_flux, b%top_flux), label//' top flux bits')
    call require(bit_equal_real(a%bottom_flux, b%bottom_flux), label//' bottom flux bits')
    call require(bit_equal_real(a%unrounded_mass_balance_residual, b%unrounded_mass_balance_residual), label//' mass bits')
    call require(a%diagnostics%nonlinear_iterations == b%diagnostics%nonlinear_iterations, label//' iterations')
    call require(a%diagnostics%jacobian_builds == b%diagnostics%jacobian_builds, label//' Jacobian builds')
    call require(a%diagnostics%linear_solves == b%diagnostics%linear_solves, label//' linear solves')
    call require(a%diagnostics%backtracking_attempts == b%diagnostics%backtracking_attempts, label//' backtracking')
    call require(a%diagnostics%alternative_solver_calls == b%diagnostics%alternative_solver_calls, label//' alternative solver')
    call require(a%diagnostics%internal_retries == b%diagnostics%internal_retries, label//' retries')
    call require(a%diagnostics%interface_sensitivity_backsolves == b%diagnostics%interface_sensitivity_backsolves, &
         label//' sensitivity backsolves')
    call require(a%diagnostics%route == b%diagnostics%route, label//' route')
    call require(a%interface_sensitivity%available .eqv. b%interface_sensitivity%available, label//' sensitivity flag')
    call require(bit_equal_real(a%interface_sensitivity%dh_bottom_dq_bottom, b%interface_sensitivity%dh_bottom_dq_bottom), &
         label//' sensitivity value')
    call require(a%interface_sensitivity%method == b%interface_sensitivity%method, label//' sensitivity method')
  end subroutine require_exact_result

  subroutine require_mass(req, res, maximum_mass)
    type(soil_water_solve_request_t), intent(in) :: req
    type(soil_water_solve_result_t), intent(in) :: res
    real(real64), intent(out) :: maximum_mass
    real(real64) :: storage0, storage1, total_in, total_out, external_mass

    call require(res%status == SW_SOLVE_CONVERGED, 'mass check convergence')
    storage0 = sum(req%base_state%water_content * req%parameters%dz) + req%base_state%ponding_depth
    storage1 = sum(res%candidate_state%water_content * req%parameters%dz) + res%candidate_state%ponding_depth
    total_in = max(0.0_real64,-res%top_flux)*req%step_duration + max(0.0_real64,res%bottom_flux)*req%step_duration
    total_out = max(0.0_real64,res%top_flux)*req%step_duration + max(0.0_real64,-res%bottom_flux)*req%step_duration
    external_mass = storage1 - storage0 - (total_in - total_out)
    maximum_mass = max(abs(external_mass), abs(res%unrounded_mass_balance_residual))
    call require(ieee_is_finite(maximum_mass), 'finite mass')
    call require(maximum_mass <= hard_mass_gate, 'hard mass gate')
  end subroutine require_mass

  pure logical function bit_equal_real(a, b) result(equal)
    real(real64), intent(in) :: a, b
    equal = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function bit_equal_real

  pure logical function bit_equal_array(a, b) result(equal)
    real(real64), intent(in) :: a(:), b(:)
    integer :: j
    equal = size(a) == size(b)
    if (.not. equal) return
    do j = 1, size(a)
      if (.not. bit_equal_real(a(j), b(j))) then
        equal = .false.
        return
      end if
    end do
  end function bit_equal_array

  pure real(real64) function result_checksum(res) result(value)
    type(soil_water_solve_result_t), intent(in) :: res
    value = sum(res%candidate_state%pressure_head) + sum(res%candidate_state%water_content) + &
         res%candidate_state%ponding_depth + res%candidate_state%groundwater_level + &
         res%top_flux + res%bottom_flux + res%unrounded_mass_balance_residual
  end function result_checksum

  subroutine emit_timing(arm, initial_head, head_jump, ncall, nwarm, c0, c1, crate, t0, t1, sumcheck, maximum_mass)
    character(len=*), intent(in) :: arm
    real(real64), intent(in) :: initial_head, head_jump, t0, t1, sumcheck, maximum_mass
    integer, intent(in) :: ncall, nwarm
    integer(int64), intent(in) :: c0, c1, crate
    real(real64) :: wall, cpu

    if (crate <= 0_int64) error stop 'F-PE18 invalid clock rate'
    wall = real(c1-c0,real64)/real(crate,real64)
    cpu = t1-t0
    call require(wall > 0.0_real64 .and. cpu >= 0.0_real64, 'positive timing')
    write(*,'(A,A,A,ES26.17E3,A,ES26.17E3,A,I0,A,I0,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3)') &
         'FPE18_FULL_TIMING arm=',trim(arm),',h0=',initial_head,',jump=',head_jump,',calls=',ncall,',warmup=',nwarm, &
         ',wall_s=',wall,',cpu_s=',cpu,',checksum=',sumcheck,',mass=',maximum_mass
  end subroutine emit_timing

  subroutine read_args(selected_mode, initial_head, head_jump, ncall, nwarm)
    character(len=*), intent(out) :: selected_mode
    real(real64), intent(out) :: initial_head, head_jump
    integer, intent(out) :: ncall, nwarm
    character(len=128) :: arg
    integer :: stat

    if (command_argument_count() /= 5) error stop 'usage: test_fpe18_full <verify|fresh|reuse> <h0> <jump> <calls> <warmup>'
    call get_command_argument(1, selected_mode)
    call get_command_argument(2,arg); read(arg,*,iostat=stat) initial_head; if (stat/=0) error stop 'bad h0'
    call get_command_argument(3,arg); read(arg,*,iostat=stat) head_jump; if (stat/=0) error stop 'bad jump'
    call get_command_argument(4,arg); read(arg,*,iostat=stat) ncall; if (stat/=0 .or. ncall<=0) error stop 'bad calls'
    call get_command_argument(5,arg); read(arg,*,iostat=stat) nwarm; if (stat/=0 .or. nwarm<=0) error stop 'bad warmup'
  end subroutine read_args

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FPE18_FULL_FAIL',trim(label)
      error stop 18
    end if
  end subroutine require

end program test_fpe18_richards_full_path_workspace_timing
