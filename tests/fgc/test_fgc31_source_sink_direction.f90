program test_fgc31_source_sink_direction
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_soil_water_accepted_step_direction_contract, only: &
       soil_water_accepted_step_direction_request_t, soil_water_accepted_step_direction_result_t, &
       SW_STEP_DIRECTION_AVAILABLE, SW_STEP_CONTROL_BOTTOM_FLUX, SW_STEP_CONTROL_BOTTOM_HEAD
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_accepted_step_directional_service, only: solve_with_accepted_step_direction
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: step_dt = 0.20_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  real(real64), parameter :: eps_coarse = 2.0e-4_real64
  real(real64), parameter :: eps_fine = 1.0e-4_real64
  real(real64), parameter :: rel_gate = 7.0e-5_real64

  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: fixed_top
  type(soil_water_physical_state_t) :: initial_state
  real(real64), allocatable, target :: drainage(:,:), subsurface(:), root_sink(:)
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: base_head, k_initial

  base_head = -135.0_real64
  call configure_problem(base_head, parameters, hydraulic_parameters, constitutive, source_sink, initial_state, &
       drainage, subsurface, root_sink, cofgen, k_initial)

  call check_source_sink_fd('flux-control', SW_STEP_CONTROL_BOTTOM_FLUX, 0.012_real64, 1)
  call check_source_sink_fd('head-control', SW_STEP_CONTROL_BOTTOM_HEAD, base_head-16.0_real64, 2)
  call check_absent_equals_explicit_zero()
  call check_invalid_direction_fails_closed()

  write(*,'(A)') 'FGC31_SOURCE_SINK_RHS_FD=PASS'
  write(*,'(A)') 'FGC31_SOURCE_SINK_BOTTOM_HEAD_QBOT_FD=PASS'
  write(*,'(A)') 'FGC31_ABSENT_ZERO_DIRECTION_IDENTITY=PASS'
  write(*,'(A)') 'FGC31_SOURCE_SINK_DIRECTION_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FGC31_SOURCE_SINK_NO_EXTRA_NONLINEAR_SOLVE=PASS'

contains

  subroutine check_source_sink_fd(label, mode, control_value, mean_method)
    character(len=*), intent(in) :: label
    integer, intent(in) :: mode, mean_method
    real(real64), intent(in) :: control_value
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: solve_result
    type(soil_water_accepted_step_direction_request_t) :: drequest
    type(soil_water_accepted_step_direction_result_t) :: dresult
    real(real64), allocatable :: dsource(:), dsink(:)
    real(real64), allocatable :: fd1_h(:), fd1_theta(:), fd2_h(:), fd2_theta(:)
    real(real64) :: fd1_top, fd1_bottom, fd2_top, fd2_bottom
    real(real64) :: err_h, err_theta, err_top, err_bottom
    real(real64) :: tol_h, tol_theta, tol_top, tol_bottom
    integer :: mid

    call make_request(mode, control_value, mean_method, request)
    allocate(dsource(numnod), dsink(numnod))
    dsource = 0.0_real64
    dsink = 0.0_real64
    mid = max(1,(numnod+1)/2)
    dsource(mid) = 2.0e-3_real64
    dsink(numnod) = 5.0e-3_real64
    if (numnod > 2) dsink(2) = -7.5e-4_real64

    drequest = soil_water_accepted_step_direction_request_t()
    drequest%requested = .true.
    drequest%control_coordinate = mode
    allocate(drequest%incoming_pressure_head(numnod), drequest%incoming_water_content(numnod), &
         drequest%incoming_source_direction(numnod), drequest%incoming_sink_direction(numnod))
    drequest%incoming_pressure_head = 0.0_real64
    drequest%incoming_water_content = 0.0_real64
    drequest%incoming_source_direction = dsource
    drequest%incoming_sink_direction = dsink
    drequest%incoming_ponding_depth = 0.0_real64
    drequest%direct_control_derivative = 0.0_real64

    call solve_with_accepted_step_direction(solver, request, workspace, drequest, solve_result, dresult)
    call require(solve_result%status == SW_SOLVE_CONVERGED, trim(label)//': physical solve converged')
    call require(dresult%status == SW_STEP_DIRECTION_AVAILABLE .and. dresult%available, &
         trim(label)//': source/sink direction available')
    call require(dresult%additional_tridiagonal_backsolves == 1, trim(label)//': exactly one tangent backsolve')
    call require(dresult%additional_jacobian_builds == 0 .and. dresult%additional_full_nonlinear_solves == 0, &
         trim(label)//': no extra Jacobian/nonlinear solve')
    call require(all(ieee_is_finite(dresult%outgoing_pressure_head)) .and. &
         all(ieee_is_finite(dresult%outgoing_water_content)), trim(label)//': finite directional state')

    allocate(fd1_h(numnod), fd1_theta(numnod), fd2_h(numnod), fd2_theta(numnod))
    call five_point_source_sink_fd(request, dsource, dsink, eps_coarse, fd1_h, fd1_theta, fd1_top, fd1_bottom)
    call five_point_source_sink_fd(request, dsource, dsink, eps_fine, fd2_h, fd2_theta, fd2_top, fd2_bottom)

    err_h = maxval(abs(fd2_h-dresult%outgoing_pressure_head))
    err_theta = maxval(abs(fd2_theta-dresult%outgoing_water_content))
    err_top = abs(fd2_top-dresult%top_flux_derivative)
    err_bottom = abs(fd2_bottom-dresult%bottom_flux_derivative)

    tol_h = 3.0e-7_real64 + rel_gate*max(1.0_real64,maxval(abs(dresult%outgoing_pressure_head)))
    tol_theta = 3.0e-9_real64 + rel_gate*max(1.0e-6_real64,maxval(abs(dresult%outgoing_water_content)))
    tol_top = 3.0e-9_real64 + rel_gate*max(1.0e-6_real64,abs(dresult%top_flux_derivative))
    tol_bottom = 3.0e-9_real64 + rel_gate*max(1.0e-6_real64,abs(dresult%bottom_flux_derivative))

    call require(err_h <= tol_h, trim(label)//': head direction agrees with five-point FD')
    call require(err_theta <= tol_theta, trim(label)//': water direction agrees with five-point FD')
    call require(err_top <= tol_top, trim(label)//': top-flux direction agrees with five-point FD')
    call require(err_bottom <= tol_bottom, trim(label)//': bottom-flux direction agrees with five-point FD')

    call require(maxval(abs(fd2_h-fd1_h)) <= 3.0e-5_real64*max(1.0_real64,maxval(abs(fd2_h))), &
         trim(label)//': two FD stencils consistent')
    if (mode == SW_STEP_CONTROL_BOTTOM_FLUX) then
      call require(dresult%bottom_flux_derivative == 0.0_real64, &
           trim(label)//': prescribed qbot remains directionally fixed')
    else
      call require(abs(dresult%bottom_flux_derivative) > 0.0_real64, &
           trim(label)//': prescribed-head qbot includes source/sink direction')
    end if

    write(*,'(A,1X,A,4(1X,ES12.4))') 'FGC31_SOURCE_SINK_FD_ERROR', trim(label), &
         err_h, err_theta, err_top, err_bottom
  end subroutine check_source_sink_fd

  subroutine five_point_source_sink_fd(base_request, dsource, dsink, eps, fd_head, fd_water, fd_top, fd_bottom)
    type(soil_water_solve_request_t), intent(in) :: base_request
    real(real64), intent(in) :: dsource(:), dsink(:), eps
    real(real64), intent(out) :: fd_head(:), fd_water(:), fd_top, fd_bottom
    type(soil_water_solve_result_t) :: ym2, ym1, yp1, yp2

    call source_sink_perturbed_solve(base_request, dsource, dsink, -2.0_real64*eps, ym2)
    call source_sink_perturbed_solve(base_request, dsource, dsink, -1.0_real64*eps, ym1)
    call source_sink_perturbed_solve(base_request, dsource, dsink,  1.0_real64*eps, yp1)
    call source_sink_perturbed_solve(base_request, dsource, dsink,  2.0_real64*eps, yp2)

    fd_head = (ym2%candidate_state%pressure_head - 8.0_real64*ym1%candidate_state%pressure_head + &
               8.0_real64*yp1%candidate_state%pressure_head - yp2%candidate_state%pressure_head)/(12.0_real64*eps)
    fd_water = (ym2%candidate_state%water_content - 8.0_real64*ym1%candidate_state%water_content + &
                8.0_real64*yp1%candidate_state%water_content - yp2%candidate_state%water_content)/(12.0_real64*eps)
    fd_top = (ym2%top_flux - 8.0_real64*ym1%top_flux + 8.0_real64*yp1%top_flux - yp2%top_flux)/(12.0_real64*eps)
    fd_bottom = (ym2%bottom_flux - 8.0_real64*ym1%bottom_flux + &
                 8.0_real64*yp1%bottom_flux - yp2%bottom_flux)/(12.0_real64*eps)
  end subroutine five_point_source_sink_fd

  subroutine source_sink_perturbed_solve(base_request, dsource, dsink, alpha, result)
    type(soil_water_solve_request_t), intent(in) :: base_request
    real(real64), intent(in) :: dsource(:), dsink(:), alpha
    type(soil_water_solve_result_t), intent(out) :: result
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(soil_water_solve_request_t) :: request
    type(b110_source_sink_provider_t), target :: perturbed_provider
    real(real64), allocatable, target :: qdra(:,:), qssdi(:), qrot(:)

    allocate(qdra(size(drainage,1),size(drainage,2)), qssdi(size(subsurface)), qrot(size(root_sink)))
    qdra = drainage
    qdra(1,:) = qdra(1,:) + alpha*dsink
    qssdi = subsurface + alpha*dsource
    qrot = root_sink
    call bind_b110_source_sink_provider(perturbed_provider, qdra, qssdi, qrot)

    request = base_request
    request%evaluation%source_sink => perturbed_provider
    call solver%solve(request, workspace, result)
    call require(result%status == SW_SOLVE_CONVERGED, 'five-point source/sink perturbation converged')
  end subroutine source_sink_perturbed_solve

  subroutine check_absent_equals_explicit_zero()
    type(reference_richards_legacy_solver_t) :: solver_a, solver_b
    type(reference_richards_legacy_workspace_t) :: workspace_a, workspace_b
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: solve_a, solve_b
    type(soil_water_accepted_step_direction_request_t) :: absent, explicit_zero
    type(soil_water_accepted_step_direction_result_t) :: result_a, result_b

    call make_request(SW_STEP_CONTROL_BOTTOM_FLUX, 0.012_real64, 3, request)

    absent = soil_water_accepted_step_direction_request_t()
    absent%requested = .true.
    absent%control_coordinate = SW_STEP_CONTROL_BOTTOM_FLUX
    allocate(absent%incoming_pressure_head(numnod), absent%incoming_water_content(numnod))
    absent%incoming_pressure_head = 0.0_real64
    absent%incoming_water_content = 0.0_real64

    explicit_zero = absent
    allocate(explicit_zero%incoming_source_direction(numnod), explicit_zero%incoming_sink_direction(numnod))
    explicit_zero%incoming_source_direction = 0.0_real64
    explicit_zero%incoming_sink_direction = 0.0_real64

    call solve_with_accepted_step_direction(solver_a, request, workspace_a, absent, solve_a, result_a)
    call solve_with_accepted_step_direction(solver_b, request, workspace_b, explicit_zero, solve_b, result_b)

    call require(solve_a%status == SW_SOLVE_CONVERGED .and. solve_b%status == SW_SOLVE_CONVERGED, &
         'zero-identity physical solves converged')
    call require(result_a%status == SW_STEP_DIRECTION_AVAILABLE .and. result_b%status == SW_STEP_DIRECTION_AVAILABLE, &
         'zero-identity directions available')
    call require(same_bits_vector(solve_a%candidate_state%pressure_head,solve_b%candidate_state%pressure_head), &
         'absent/zero physical head identity')
    call require(same_bits_vector(result_a%outgoing_pressure_head,result_b%outgoing_pressure_head), &
         'absent/zero directional head identity')
    call require(same_bits_vector(result_a%outgoing_water_content,result_b%outgoing_water_content), &
         'absent/zero directional water identity')
    call require(same_bits_scalar(result_a%bottom_flux_derivative,result_b%bottom_flux_derivative), &
         'absent/zero bottom derivative identity')
    call require(same_bits_scalar(result_a%top_flux_derivative,result_b%top_flux_derivative), &
         'absent/zero top derivative identity')
  end subroutine check_absent_equals_explicit_zero

  subroutine check_invalid_direction_fails_closed()
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: solve_result
    type(soil_water_accepted_step_direction_request_t) :: drequest
    type(soil_water_accepted_step_direction_result_t) :: dresult

    call make_request(SW_STEP_CONTROL_BOTTOM_FLUX, 0.012_real64, 1, request)
    drequest%requested = .true.
    drequest%control_coordinate = SW_STEP_CONTROL_BOTTOM_FLUX
    allocate(drequest%incoming_pressure_head(numnod), drequest%incoming_water_content(numnod), &
         drequest%incoming_sink_direction(max(1,numnod-1)))
    drequest%incoming_pressure_head = 0.0_real64
    drequest%incoming_water_content = 0.0_real64
    drequest%incoming_sink_direction = 0.0_real64

    call solve_with_accepted_step_direction(solver, request, workspace, drequest, solve_result, dresult)
    call require(solve_result%status == SW_SOLVE_CONVERGED, 'invalid scratch keeps physical solve valid')
    call require(.not. dresult%available, 'invalid scratch publishes no derivative')
    call require(trim(dresult%route) == 'sink-direction-shape-invalid', 'invalid scratch explicit route')
  end subroutine check_invalid_direction_fails_closed

  subroutine make_request(mode, control_value, mean_method, request)
    integer, intent(in) :: mode, mean_method
    real(real64), intent(in) :: control_value
    type(soil_water_solve_request_t), intent(out) :: request

    request = soil_water_solve_request_t()
    request%parameters => parameters
    request%base_state = initial_state
    request%step_duration = step_dt
    request%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
    request%boundary%bottom_mode = mode
    request%boundary%top_flux = -0.65_real64*k_initial
    request%boundary%top_head = base_head
    request%boundary%bottom_flux = 0.0_real64
    request%boundary%bottom_head = base_head
    if (mode == SW_STEP_CONTROL_BOTTOM_FLUX) request%boundary%bottom_flux = control_value
    if (mode == SW_STEP_CONTROL_BOTTOM_HEAD) request%boundary%bottom_head = control_value
    request%physical%macropore_active = .false.
    request%numerical%max_iterations = 16
    request%numerical%max_backtracking = 8
    request%numerical%conductivity_implicit_mode = 0
    request%numerical%conductivity_mean_method = mean_method
    request%numerical%min_step_duration = 1.0e-7_real64
    request%numerical%compartment_balance_tolerance = hard_mass_gate
    request%numerical%total_balance_tolerance = hard_mass_gate
    request%numerical%head_abs_tolerance = 1.0e-12_real64
    request%numerical%head_rel_tolerance = 1.0e-12_real64
    request%numerical%ponding_tolerance = 1.0e-12_real64
    request%evaluation%constitutive => constitutive
    request%evaluation%source_sink => source_sink
    request%evaluation%top_boundary => fixed_top
  end subroutine make_request

  subroutine configure_problem(initial_head, p, hp, cp, sp, state, qdra, qssdi, qrot, c, k0)
    real(real64), intent(in) :: initial_head
    type(soil_water_parameter_set_t), target, intent(out) :: p
    type(b110_default_mvg_parameters_t), target, intent(out) :: hp
    type(b110_default_mvg_provider_t), target, intent(out) :: cp
    type(b110_source_sink_provider_t), target, intent(out) :: sp
    type(soil_water_physical_state_t), intent(out) :: state
    real(real64), allocatable, target, intent(out) :: qdra(:,:), qssdi(:), qrot(:)
    real(real64), allocatable, intent(out) :: c(:,:)
    real(real64), intent(out) :: k0
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: k

    p%parameter_set_id = 310037_int64
    p%active_nodes = numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)

    allocate(c(24,numnod))
    c = 0.0_real64
    do k=1,numnod
      c(1,k)=0.032_real64
      c(2,k)=0.423_real64
      c(3,k)=4.75_real64
      c(4,k)=0.0135_real64
      c(5,k)=0.365_real64
      c(6,k)=1.455_real64
      c(7,k)=1.0_real64-1.0_real64/c(6,k)
      c(8,k)=c(4,k)
      c(9,k)=0.0_real64
      c(10,k)=c(3,k)
      c(11,k)=0.999_real64
      c(12,k)=0.99_real64*c(3,k)
      c(22,k)=-1.0e6_real64
      c(23,k)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp,c)
    call bind_b110_default_mvg_provider(cp,hp,step_dt)

    do k=1,numnod
      heads(k)=initial_head+3.25_real64*real(k-1,real64)+0.35_real64*real((k-1)*(k-1),real64)
    end do
    call cp%evaluate(heads,water,conductivity,capacity,dkdh)
    k0 = conductivity(1)

    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads
    state%water_content=water
    state%ponding_depth=0.0_real64
    state%groundwater_level=-2.5_real64

    allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
    qdra = 0.0_real64
    qdra(1,numnod) = 1.0e-2_real64
    qssdi = 0.0_real64
    qrot = 0.0_real64
    call bind_b110_source_sink_provider(sp,qdra,qssdi,qrot)
  end subroutine configure_problem

  logical function same_bits_scalar(a,b)
    real(real64), intent(in) :: a,b
    same_bits_scalar = transfer(a,0_int64) == transfer(b,0_int64)
  end function same_bits_scalar

  logical function same_bits_vector(a,b)
    real(real64), intent(in) :: a(:),b(:)
    integer :: i
    same_bits_vector = size(a)==size(b)
    if (.not. same_bits_vector) return
    do i=1,size(a)
      if (.not. same_bits_scalar(a(i),b(i))) then
        same_bits_vector=.false.
        return
      end if
    end do
  end function same_bits_vector

  subroutine require(condition,message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FGC31_SOURCE_SINK_TEST_FAIL',trim(message)
      error stop 31
    end if
  end subroutine require

end program test_fgc31_source_sink_direction
