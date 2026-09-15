program test_fvq89_fsi37_independent
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED, SW_SOLVE_RETRY_ADVISED
  use mod_soil_water_accepted_step_direction_contract, only: &
       soil_water_accepted_step_direction_request_t, soil_water_accepted_step_direction_result_t, &
       SW_STEP_DIRECTION_AVAILABLE, SW_STEP_DIRECTION_UNAVAILABLE, &
       SW_STEP_CONTROL_BOTTOM_FLUX, SW_STEP_CONTROL_BOTTOM_HEAD
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
  real(real64), parameter :: fd_h_coarse = 2.0e-4_real64
  real(real64), parameter :: fd_h_fine = 1.0e-4_real64
  real(real64), parameter :: rel_gate = 5.0e-5_real64

  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: fixed_top
  type(soil_water_physical_state_t) :: initial_state
  real(real64), allocatable, target :: drainage(:,:), subsurface(:), root_sink(:)
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: base_head, k_initial
  integer :: case_count

  base_head = -135.0_real64
  call configure_problem(base_head, parameters, hydraulic_parameters, constitutive, source_sink, initial_state, &
       drainage, subsurface, root_sink, cofgen, k_initial)

  case_count = 0
  call check_fd_case('zero-flux', SW_STEP_CONTROL_BOTTOM_FLUX, 0.012_real64, 1, 0, case_count)
  call check_fd_case('control-flux', SW_STEP_CONTROL_BOTTOM_FLUX, -0.018_real64, 3, 1, case_count)
  call check_fd_case('single-head', SW_STEP_CONTROL_BOTTOM_HEAD, base_head-16.0_real64, 2, 2, case_count)
  call check_fd_case('single-water', SW_STEP_CONTROL_BOTTOM_HEAD, base_head+11.0_real64, 6, 3, case_count)
  call check_fd_case('mixed-head', SW_STEP_CONTROL_BOTTOM_HEAD, base_head-7.0_real64, 4, 4, case_count)

  call check_unavailable_fail_closed()
  call check_retry_no_leak()

  call require(case_count == 5, 'five independent smooth endpoint FD cases executed')
  write(*,'(A,I0)') 'FVQ89_FD_CASES=', case_count
  write(*,'(A)') 'FVQ89_ACCEPTED_ENDPOINT_REFERENCE=PASS'
  write(*,'(A)') 'FVQ89_ZERO_SINGLE_MIXED_DIRECTIONS=PASS'
  write(*,'(A)') 'FVQ89_NO_COMMITTED_STATE_MUTATION=PASS'
  write(*,'(A)') 'FVQ89_RETRY_NO_DERIVATIVE_LEAK=PASS'
  write(*,'(A)') 'FVQ89_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FVQ89_FSI37_INDEPENDENT PASS'

contains

  subroutine check_fd_case(label, mode, control_value, mean_method, direction_kind, counter)
    character(len=*), intent(in) :: label
    integer, intent(in) :: mode, mean_method, direction_kind
    real(real64), intent(in) :: control_value
    integer, intent(inout) :: counter

    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: ws_direction, ws_plain
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: directional_solve, plain_solve
    type(soil_water_accepted_step_direction_request_t) :: drequest
    type(soil_water_accepted_step_direction_result_t) :: dresult
    real(real64), allocatable :: dh(:), dtheta(:), base_h_snapshot(:), base_theta_snapshot(:)
    real(real64), allocatable :: fd1_h(:), fd1_theta(:), fd2_h(:), fd2_theta(:)
    real(real64) :: direct_control, base_pond_snapshot, base_bottom_snapshot, base_top_snapshot
    real(real64) :: fd1_bottom, fd1_top, fd2_bottom, fd2_top
    real(real64) :: err_h, err_theta, err_bottom, err_top, consistency
    real(real64) :: tol_h, tol_theta, tol_bottom, tol_top
    integer :: mid

    call make_request(mode, control_value, mean_method, request)
    allocate(dh(numnod), dtheta(numnod))
    call make_direction(direction_kind, dh, dtheta, direct_control)

    drequest = soil_water_accepted_step_direction_request_t()
    drequest%requested = .true.
    drequest%control_coordinate = mode
    allocate(drequest%incoming_pressure_head(numnod), drequest%incoming_water_content(numnod))
    drequest%incoming_pressure_head = dh
    drequest%incoming_water_content = dtheta
    drequest%incoming_ponding_depth = 0.0_real64
    drequest%direct_control_derivative = direct_control

    allocate(base_h_snapshot(numnod), base_theta_snapshot(numnod))
    base_h_snapshot = request%base_state%pressure_head
    base_theta_snapshot = request%base_state%water_content
    base_pond_snapshot = request%base_state%ponding_depth
    base_bottom_snapshot = merge(request%boundary%bottom_flux, request%boundary%bottom_head, &
                                 mode == SW_STEP_CONTROL_BOTTOM_FLUX)
    base_top_snapshot = request%boundary%top_flux

    call solve_with_accepted_step_direction(solver, request, ws_direction, drequest, directional_solve, dresult)

    call require(directional_solve%status == SW_SOLVE_CONVERGED, trim(label)//': physical step converged')
    call require(dresult%status == SW_STEP_DIRECTION_AVAILABLE .and. dresult%available, trim(label)//': derivative available')
    call require(dresult%fixed_smooth_route, trim(label)//': fixed smooth route')
    call require(trim(dresult%route) == 'reference-swkimpl0-fixed-flux-b110', trim(label)//': expected admitted route')
    call require(dresult%additional_tridiagonal_backsolves == 1, trim(label)//': one tangent backsolve')
    call require(dresult%additional_jacobian_builds == 0, trim(label)//': no extra Jacobian build')
    call require(dresult%additional_full_nonlinear_solves == 0, trim(label)//': no extra nonlinear solve')
    call require(allocated(dresult%outgoing_pressure_head) .and. allocated(dresult%outgoing_water_content), &
         trim(label)//': derivative arrays published')
    call require(all(ieee_is_finite(dresult%outgoing_pressure_head)), trim(label)//': finite head derivative')
    call require(all(ieee_is_finite(dresult%outgoing_water_content)), trim(label)//': finite water derivative')

    call solver%solve(request, ws_plain, plain_solve)
    call require(plain_solve%status == SW_SOLVE_CONVERGED, trim(label)//': plain endpoint converged')
    call require(same_bits_vector(plain_solve%candidate_state%pressure_head, directional_solve%candidate_state%pressure_head), &
         trim(label)//': accepted head endpoint bit identity')
    call require(same_bits_vector(plain_solve%candidate_state%water_content, directional_solve%candidate_state%water_content), &
         trim(label)//': accepted water endpoint bit identity')
    call require(same_bits_scalar(plain_solve%candidate_state%ponding_depth, directional_solve%candidate_state%ponding_depth), &
         trim(label)//': accepted ponding endpoint bit identity')
    call require(same_bits_scalar(plain_solve%top_flux, directional_solve%top_flux), trim(label)//': top flux bit identity')
    call require(same_bits_scalar(plain_solve%bottom_flux, directional_solve%bottom_flux), trim(label)//': bottom flux bit identity')
    call require(same_bits_scalar(plain_solve%unrounded_mass_balance_residual, &
         directional_solve%unrounded_mass_balance_residual), trim(label)//': mass residual bit identity')

    call require(same_bits_vector(request%base_state%pressure_head, base_h_snapshot), trim(label)//': base head not mutated')
    call require(same_bits_vector(request%base_state%water_content, base_theta_snapshot), trim(label)//': base water not mutated')
    call require(same_bits_scalar(request%base_state%ponding_depth, base_pond_snapshot), trim(label)//': base ponding not mutated')
    call require(same_bits_scalar(request%boundary%top_flux, base_top_snapshot), trim(label)//': top boundary not mutated')
    if (mode == SW_STEP_CONTROL_BOTTOM_FLUX) then
       call require(same_bits_scalar(request%boundary%bottom_flux, base_bottom_snapshot), trim(label)//': bottom flux request not mutated')
    else
       call require(same_bits_scalar(request%boundary%bottom_head, base_bottom_snapshot), trim(label)//': bottom head request not mutated')
    end if

    allocate(fd1_h(numnod), fd1_theta(numnod), fd2_h(numnod), fd2_theta(numnod))
    call five_point_endpoint_fd(request, dh, dtheta, direct_control, fd_h_coarse, fd1_h, fd1_theta, fd1_top, fd1_bottom)
    call five_point_endpoint_fd(request, dh, dtheta, direct_control, fd_h_fine, fd2_h, fd2_theta, fd2_top, fd2_bottom)

    err_h = maxval(abs(fd2_h-dresult%outgoing_pressure_head))
    err_theta = maxval(abs(fd2_theta-dresult%outgoing_water_content))
    err_bottom = abs(fd2_bottom-dresult%bottom_flux_derivative)
    err_top = abs(fd2_top-dresult%top_flux_derivative)

    tol_h = 2.0e-7_real64 + rel_gate*max(1.0_real64, maxval(abs(dresult%outgoing_pressure_head)))
    tol_theta = 2.0e-9_real64 + rel_gate*max(1.0e-6_real64, maxval(abs(dresult%outgoing_water_content)))
    tol_bottom = 2.0e-9_real64 + rel_gate*max(1.0e-6_real64, abs(dresult%bottom_flux_derivative))
    tol_top = 2.0e-9_real64 + rel_gate*max(1.0e-6_real64, abs(dresult%top_flux_derivative))

    call require(err_h <= tol_h, trim(label)//': five-point FD head agreement')
    call require(err_theta <= tol_theta, trim(label)//': five-point FD water agreement')
    call require(err_bottom <= tol_bottom, trim(label)//': five-point FD bottom-flux agreement')
    call require(err_top <= tol_top, trim(label)//': five-point FD top-flux agreement')

    consistency = max(maxval(abs(fd2_h-fd1_h))/max(1.0_real64,maxval(abs(fd2_h))), &
                      maxval(abs(fd2_theta-fd1_theta))/max(1.0e-6_real64,maxval(abs(fd2_theta))), &
                      abs(fd2_bottom-fd1_bottom)/max(1.0e-6_real64,abs(fd2_bottom)), &
                      abs(fd2_top-fd1_top)/max(1.0e-6_real64,abs(fd2_top)))
    call require(consistency <= 2.0e-5_real64, trim(label)//': two-stencil consistency')

    if (direction_kind == 0) then
       call require(all(dresult%outgoing_pressure_head == 0.0_real64), 'zero direction: exact zero outgoing head')
       call require(all(dresult%outgoing_water_content == 0.0_real64), 'zero direction: exact zero outgoing water')
       call require(dresult%outgoing_ponding_depth == 0.0_real64, 'zero direction: exact zero ponding')
       call require(dresult%top_flux_derivative == 0.0_real64, 'zero direction: exact zero top flux')
       call require(dresult%bottom_flux_derivative == 0.0_real64, 'zero direction: exact zero bottom flux')
    end if

    mid = max(1, (numnod+1)/2)
    write(*,'(A,1X,A,1X,Z16.16,1X,Z16.16,1X,Z16.16,1X,Z16.16)') &
         'FVQ89_SIGNATURE', trim(label), &
         transfer(dresult%outgoing_pressure_head(1),0_int64), &
         transfer(dresult%outgoing_pressure_head(mid),0_int64), &
         transfer(dresult%outgoing_water_content(mid),0_int64), &
         transfer(dresult%bottom_flux_derivative,0_int64)
    write(*,'(A,1X,A,4(1X,ES12.4))') 'FVQ89_FD_ERROR', trim(label), err_h, err_theta, err_bottom, err_top

    counter = counter + 1
  end subroutine check_fd_case

  subroutine five_point_endpoint_fd(base_request, dh, dtheta, direct_control, eps, fd_head, fd_water, fd_top, fd_bottom)
    type(soil_water_solve_request_t), intent(in) :: base_request
    real(real64), intent(in) :: dh(:), dtheta(:), direct_control, eps
    real(real64), intent(out) :: fd_head(:), fd_water(:), fd_top, fd_bottom

    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: wm2, wm1, wp1, wp2
    type(soil_water_solve_request_t) :: rm2, rm1, rp1, rp2
    type(soil_water_solve_result_t) :: ym2, ym1, yp1, yp2

    call perturb_request(base_request, dh, dtheta, direct_control, -2.0_real64*eps, rm2)
    call perturb_request(base_request, dh, dtheta, direct_control, -1.0_real64*eps, rm1)
    call perturb_request(base_request, dh, dtheta, direct_control,  1.0_real64*eps, rp1)
    call perturb_request(base_request, dh, dtheta, direct_control,  2.0_real64*eps, rp2)

    call solver%solve(rm2, wm2, ym2)
    call solver%solve(rm1, wm1, ym1)
    call solver%solve(rp1, wp1, yp1)
    call solver%solve(rp2, wp2, yp2)
    call require(ym2%status == SW_SOLVE_CONVERGED .and. ym1%status == SW_SOLVE_CONVERGED .and. &
                 yp1%status == SW_SOLVE_CONVERGED .and. yp2%status == SW_SOLVE_CONVERGED, &
                 'five-point endpoint solves converged')

    fd_head = (ym2%candidate_state%pressure_head - 8.0_real64*ym1%candidate_state%pressure_head + &
               8.0_real64*yp1%candidate_state%pressure_head - yp2%candidate_state%pressure_head)/(12.0_real64*eps)
    fd_water = (ym2%candidate_state%water_content - 8.0_real64*ym1%candidate_state%water_content + &
                8.0_real64*yp1%candidate_state%water_content - yp2%candidate_state%water_content)/(12.0_real64*eps)
    fd_top = (ym2%top_flux - 8.0_real64*ym1%top_flux + 8.0_real64*yp1%top_flux - yp2%top_flux)/(12.0_real64*eps)
    fd_bottom = (ym2%bottom_flux - 8.0_real64*ym1%bottom_flux + &
                 8.0_real64*yp1%bottom_flux - yp2%bottom_flux)/(12.0_real64*eps)
  end subroutine five_point_endpoint_fd

  subroutine perturb_request(base_request, dh, dtheta, direct_control, alpha, request)
    type(soil_water_solve_request_t), intent(in) :: base_request
    real(real64), intent(in) :: dh(:), dtheta(:), direct_control, alpha
    type(soil_water_solve_request_t), intent(out) :: request

    request = base_request
    request%base_state%pressure_head = base_request%base_state%pressure_head + alpha*dh
    request%base_state%water_content = base_request%base_state%water_content + alpha*dtheta
    select case (base_request%boundary%bottom_mode)
    case (SW_STEP_CONTROL_BOTTOM_FLUX)
       request%boundary%bottom_flux = base_request%boundary%bottom_flux + alpha*direct_control
    case (SW_STEP_CONTROL_BOTTOM_HEAD)
       request%boundary%bottom_head = base_request%boundary%bottom_head + alpha*direct_control
    case default
       error stop 'FVQ89 unsupported bottom mode in perturb_request'
    end select
  end subroutine perturb_request

  subroutine check_unavailable_fail_closed()
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    type(soil_water_accepted_step_direction_request_t) :: drequest
    type(soil_water_accepted_step_direction_result_t) :: dresult

    call make_request(SW_STEP_CONTROL_BOTTOM_HEAD, base_head-4.0_real64, 1, request)
    drequest = soil_water_accepted_step_direction_request_t()
    drequest%requested = .true.
    drequest%control_coordinate = SW_STEP_CONTROL_BOTTOM_FLUX
    allocate(drequest%incoming_pressure_head(numnod), drequest%incoming_water_content(numnod))
    drequest%incoming_pressure_head = 0.0_real64
    drequest%incoming_water_content = 0.0_real64
    drequest%direct_control_derivative = 1.0_real64

    call solve_with_accepted_step_direction(solver, request, workspace, drequest, result, dresult)
    call require(result%status == SW_SOLVE_CONVERGED, 'unavailable path keeps physical solve valid')
    call require(dresult%status == SW_STEP_DIRECTION_UNAVAILABLE .and. .not. dresult%available, &
         'unavailable path fails closed')
    call require(trim(dresult%route) == 'bottom-head-control-coordinate-mismatch', 'unavailable path explicit route')
    call require(.not. allocated(dresult%outgoing_pressure_head) .and. &
                 .not. allocated(dresult%outgoing_water_content), 'unavailable path publishes no derivative arrays')
  end subroutine check_unavailable_fail_closed

  subroutine check_retry_no_leak()
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    type(soil_water_accepted_step_direction_request_t) :: drequest
    type(soil_water_accepted_step_direction_result_t) :: dresult
    real(real64), allocatable :: dh(:), dtheta(:)
    real(real64) :: direct_control

    call make_request(SW_STEP_CONTROL_BOTTOM_HEAD, base_head+20.0_real64, 5, request)
    request%numerical%max_iterations = 0
    allocate(dh(numnod), dtheta(numnod))
    call make_direction(4, dh, dtheta, direct_control)
    drequest = soil_water_accepted_step_direction_request_t()
    drequest%requested = .true.
    drequest%control_coordinate = SW_STEP_CONTROL_BOTTOM_HEAD
    allocate(drequest%incoming_pressure_head(numnod), drequest%incoming_water_content(numnod))
    drequest%incoming_pressure_head = dh
    drequest%incoming_water_content = dtheta
    drequest%direct_control_derivative = direct_control

    call solve_with_accepted_step_direction(solver, request, workspace, drequest, result, dresult)
    call require(result%status == SW_SOLVE_RETRY_ADVISED, 'forced rejected trial advises retry')
    call require(dresult%status == SW_STEP_DIRECTION_UNAVAILABLE .and. .not. dresult%available, &
         'rejected trial publishes no derivative')
    call require(trim(dresult%route) == 'physical-step-not-accepted', 'retry has explicit unavailable route')
    call require(.not. allocated(dresult%outgoing_pressure_head) .and. &
                 .not. allocated(dresult%outgoing_water_content), 'retry derivative arrays absent')

    request%numerical%max_iterations = 16
    drequest%incoming_pressure_head = 0.0_real64
    drequest%incoming_water_content = 0.0_real64
    drequest%incoming_ponding_depth = 0.0_real64
    drequest%direct_control_derivative = 0.0_real64
    call solve_with_accepted_step_direction(solver, request, workspace, drequest, result, dresult)
    call require(result%status == SW_SOLVE_CONVERGED, 'post-retry accepted step converged')
    call require(dresult%status == SW_STEP_DIRECTION_AVAILABLE .and. dresult%available, &
         'post-retry zero derivative available')
    call require(all(dresult%outgoing_pressure_head == 0.0_real64), 'post-retry head derivative has no leak')
    call require(all(dresult%outgoing_water_content == 0.0_real64), 'post-retry water derivative has no leak')
    call require(dresult%top_flux_derivative == 0.0_real64 .and. &
                 dresult%bottom_flux_derivative == 0.0_real64, 'post-retry flux derivatives have no leak')
  end subroutine check_retry_no_leak

  subroutine make_direction(kind, dh, dtheta, direct_control)
    integer, intent(in) :: kind
    real(real64), intent(out) :: dh(:), dtheta(:), direct_control
    real(real64) :: water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: i, mid

    dh = 0.0_real64
    dtheta = 0.0_real64
    direct_control = 0.0_real64
    mid = max(1,(numnod+1)/2)

    select case (kind)
    case (0)
       continue
    case (1)
       direct_control = 0.37_real64
    case (2)
       dh(mid) = 0.11_real64
    case (3)
       dtheta(mid) = 2.5e-4_real64
    case (4)
       call constitutive%evaluate(initial_state%pressure_head, water, conductivity, capacity, dkdh)
       do i = 1, numnod
          dh(i) = 0.025_real64 + 0.009_real64*real(i-1,real64)
       end do
       dtheta = capacity*dh
       if (numnod >= 2) dtheta(2) = dtheta(2) + 7.0e-5_real64
       direct_control = -0.23_real64
    case default
       error stop 'FVQ89 unknown direction kind'
    end select
  end subroutine make_direction

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

    p%parameter_set_id = 890037_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)

    allocate(c(24,numnod))
    c = 0.0_real64
    do k = 1, numnod
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

    do k = 1, numnod
       heads(k) = initial_head + 3.25_real64*real(k-1,real64) + 0.35_real64*real((k-1)*(k-1),real64)
    end do
    call cp%evaluate(heads,water,conductivity,capacity,dkdh)
    k0 = conductivity(1)

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.5_real64

    allocate(qdra(1,numnod), qssdi(numnod), qrot(numnod))
    qdra = 0.0_real64
    qssdi = 0.0_real64
    qrot = 0.0_real64
    call bind_b110_source_sink_provider(sp,qdra,qssdi,qrot)
  end subroutine configure_problem

  logical function same_bits_scalar(a,b)
    real(real64), intent(in) :: a,b
    same_bits_scalar = transfer(a,0_int64) == transfer(b,0_int64)
  end function same_bits_scalar

  logical function same_bits_vector(a,b)
    real(real64), intent(in) :: a(:), b(:)
    integer :: i
    same_bits_vector = size(a) == size(b)
    if (.not. same_bits_vector) return
    do i = 1, size(a)
       if (.not. same_bits_scalar(a(i),b(i))) then
          same_bits_vector = .false.
          return
       end if
    end do
  end function same_bits_vector

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
       write(*,'(A,1X,A)') 'FVQ89_FAIL', trim(label)
       error stop 1
    end if
  end subroutine require

end program test_fvq89_fsi37_independent
