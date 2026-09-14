program test_fsi37_accepted_step_directional_derivative
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
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  implicit none

  real(real64), parameter :: total_dt = 0.25_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: fixed_top
  type(fmr04_fixed_flux_top_provider_t), target :: unqualified_top
  type(soil_water_physical_state_t) :: initial_state
  real(real64), allocatable, target :: drainage(:,:), subsurface(:), root_sink(:)
  real(real64), allocatable :: cofgen(:,:)
  real(real64), allocatable :: incoming_h(:), incoming_theta(:)
  real(real64) :: h0, k0
  integer :: cases, mean_method

  h0 = -100.0_real64
  call configure_problem(h0, parameters, hydraulic_parameters, constitutive, source_sink, initial_state, &
       drainage, subsurface, root_sink, cofgen, k0)
  allocate(incoming_h(numnod), incoming_theta(numnod))
  call make_incoming_direction(incoming_h, incoming_theta)

  cases = 0
  do mean_method = 1, 6
     call check_fd_case(SW_STEP_CONTROL_BOTTOM_FLUX, -0.05_real64, mean_method, 0.7_real64, cases)
     call check_fd_case(SW_STEP_CONTROL_BOTTOM_FLUX,  0.00_real64, mean_method, 0.7_real64, cases)
     call check_fd_case(SW_STEP_CONTROL_BOTTOM_FLUX,  0.05_real64, mean_method, 0.7_real64, cases)
     call check_fd_case(SW_STEP_CONTROL_BOTTOM_HEAD, h0-20.0_real64, mean_method, 0.7_real64, cases)
     call check_fd_case(SW_STEP_CONTROL_BOTTOM_HEAD, h0+20.0_real64, mean_method, 0.7_real64, cases)
  end do

  call check_provider_fail_closed()
  call check_retry_fail_closed()

  call require(cases == 30, 'thirty smooth FD cases executed')
  write(*,'(A,I0)') 'FSI37_FD_CASES=', cases
  write(*,'(A)') 'FSI37_SWKMEAN_METHODS_1_6=PASS'
  write(*,'(A)') 'FSI37_NONUNIFORM_BASE_PROFILE=PASS'
  write(*,'(A)') 'FSI37_ACCEPTED_STEP_DIRECTIONAL_DERIVATIVE PASS'

contains

  subroutine check_fd_case(mode, control_value, mean_method, direct_control, counter)
    integer, intent(in) :: mode, mean_method
    real(real64), intent(in) :: control_value, direct_control
    integer, intent(inout) :: counter
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: ws_direction, ws_baseline, ws_plus, ws_minus
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: directional_solve, baseline, plus_result, minus_result
    type(soil_water_accepted_step_direction_request_t) :: drequest
    type(soil_water_accepted_step_direction_result_t) :: dresult
    real(real64), allocatable :: fd_h(:), fd_theta(:)
    real(real64) :: eps1, eps2, err1, err2, flux_fd1, flux_fd2, flux_err1, flux_err2

    call make_request(mode, control_value, mean_method, fixed_top, request)
    drequest%requested = .true.
    drequest%control_coordinate = mode
    allocate(drequest%incoming_pressure_head(numnod), drequest%incoming_water_content(numnod))
    drequest%incoming_pressure_head = incoming_h
    drequest%incoming_water_content = incoming_theta
    drequest%incoming_ponding_depth = 0.0_real64
    drequest%direct_control_derivative = direct_control

    call solve_with_accepted_step_direction(solver, request, ws_direction, drequest, directional_solve, dresult)
    call require(directional_solve%status == SW_SOLVE_CONVERGED, 'directional physical solve converged')
    call require(dresult%status == SW_STEP_DIRECTION_AVAILABLE .and. dresult%available, 'direction available')
    call require(dresult%additional_tridiagonal_backsolves == 1, 'exactly one added backsolve')
    call require(dresult%additional_jacobian_builds == 0, 'no added Jacobian build')
    call require(dresult%additional_full_nonlinear_solves == 0, 'no added nonlinear trajectory')
    call require(all(ieee_is_finite(dresult%outgoing_pressure_head)), 'finite outgoing head direction')
    call require(all(ieee_is_finite(dresult%outgoing_water_content)), 'finite outgoing theta direction')

    call solver%solve(request, ws_baseline, baseline)
    call require(baseline%status == SW_SOLVE_CONVERGED, 'baseline physical solve converged')
    call require(same_bits_vector(baseline%candidate_state%pressure_head, directional_solve%candidate_state%pressure_head), &
         'ON/OFF pressure-head bit identity')
    call require(same_bits_vector(baseline%candidate_state%water_content, directional_solve%candidate_state%water_content), &
         'ON/OFF water-content bit identity')
    call require(same_bits_scalar(baseline%top_flux, directional_solve%top_flux), 'ON/OFF top-flux bit identity')
    call require(same_bits_scalar(baseline%bottom_flux, directional_solve%bottom_flux), 'ON/OFF bottom-flux bit identity')
    call require(same_bits_scalar(baseline%unrounded_mass_balance_residual, &
         directional_solve%unrounded_mass_balance_residual), 'ON/OFF mass diagnostic bit identity')

    allocate(fd_h(numnod), fd_theta(numnod))
    eps1 = 1.0e-4_real64
    eps2 = 5.0e-5_real64
    call centered_fd(request, mode, direct_control, eps1, ws_plus, ws_minus, plus_result, minus_result, &
         fd_h, fd_theta, flux_fd1)
    err1 = max(maxval(abs(fd_h-dresult%outgoing_pressure_head)), &
               maxval(abs(fd_theta-dresult%outgoing_water_content)))
    flux_err1 = abs(flux_fd1-dresult%bottom_flux_derivative)

    call centered_fd(request, mode, direct_control, eps2, ws_plus, ws_minus, plus_result, minus_result, &
         fd_h, fd_theta, flux_fd2)
    err2 = max(maxval(abs(fd_h-dresult%outgoing_pressure_head)), &
               maxval(abs(fd_theta-dresult%outgoing_water_content)))
    flux_err2 = abs(flux_fd2-dresult%bottom_flux_derivative)

    call require(err2 <= max(2.0e-6_real64, 1.25_real64*err1), 'FD state derivative convergence')
    call require(flux_err2 <= max(2.0e-6_real64, 1.25_real64*flux_err1), 'FD bottom-flux derivative convergence')
    call require(err2 <= 2.0e-5_real64*max(1.0_real64,maxval(abs(dresult%outgoing_pressure_head))), &
         'FD state derivative absolute/relative gate')
    call require(flux_err2 <= 2.0e-5_real64*max(1.0_real64,abs(dresult%bottom_flux_derivative)), &
         'FD bottom-flux derivative absolute/relative gate')

    counter = counter + 1
    write(*,'(A,I0,A,I0,A,ES13.5,A,ES13.5,A,ES13.5,A,ES13.5)') &
         'FSI37_CASE:MODE=',mode,':MEAN=',mean_method,':ERR_E1=',err1,':ERR_E2=',err2, &
         ':FLUX_ERR_E1=',flux_err1,':FLUX_ERR_E2=',flux_err2
  end subroutine check_fd_case

  subroutine centered_fd(base_request, mode, direct_control, eps, ws_plus, ws_minus, plus_result, minus_result, &
                         fd_h, fd_theta, fd_bottom_flux)
    type(soil_water_solve_request_t), intent(in) :: base_request
    integer, intent(in) :: mode
    real(real64), intent(in) :: direct_control, eps
    type(reference_richards_legacy_workspace_t), intent(inout) :: ws_plus, ws_minus
    type(soil_water_solve_result_t), intent(out) :: plus_result, minus_result
    real(real64), intent(out) :: fd_h(:), fd_theta(:), fd_bottom_flux
    type(reference_richards_legacy_solver_t) :: solver
    type(soil_water_solve_request_t) :: plus_request, minus_request

    plus_request = base_request
    minus_request = base_request
    plus_request%base_state%pressure_head = base_request%base_state%pressure_head + eps*incoming_h
    minus_request%base_state%pressure_head = base_request%base_state%pressure_head - eps*incoming_h
    plus_request%base_state%water_content = base_request%base_state%water_content + eps*incoming_theta
    minus_request%base_state%water_content = base_request%base_state%water_content - eps*incoming_theta
    select case (mode)
    case (SW_STEP_CONTROL_BOTTOM_FLUX)
       plus_request%boundary%bottom_flux = base_request%boundary%bottom_flux + eps*direct_control
       minus_request%boundary%bottom_flux = base_request%boundary%bottom_flux - eps*direct_control
    case (SW_STEP_CONTROL_BOTTOM_HEAD)
       plus_request%boundary%bottom_head = base_request%boundary%bottom_head + eps*direct_control
       minus_request%boundary%bottom_head = base_request%boundary%bottom_head - eps*direct_control
    end select
    call solver%solve(plus_request, ws_plus, plus_result)
    call solver%solve(minus_request, ws_minus, minus_result)
    call require(plus_result%status == SW_SOLVE_CONVERGED .and. minus_result%status == SW_SOLVE_CONVERGED, &
         'centered FD solves converged')
    fd_h = (plus_result%candidate_state%pressure_head-minus_result%candidate_state%pressure_head)/(2.0_real64*eps)
    fd_theta = (plus_result%candidate_state%water_content-minus_result%candidate_state%water_content)/(2.0_real64*eps)
    fd_bottom_flux = (plus_result%bottom_flux-minus_result%bottom_flux)/(2.0_real64*eps)
  end subroutine centered_fd

  subroutine check_provider_fail_closed()
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    type(soil_water_accepted_step_direction_request_t) :: drequest
    type(soil_water_accepted_step_direction_result_t) :: dresult

    call make_request(SW_STEP_CONTROL_BOTTOM_HEAD, h0+10.0_real64, 1, unqualified_top, request)
    drequest%requested=.true.; drequest%control_coordinate=SW_STEP_CONTROL_BOTTOM_HEAD
    allocate(drequest%incoming_pressure_head(numnod),drequest%incoming_water_content(numnod))
    drequest%incoming_pressure_head=0.0_real64; drequest%incoming_water_content=0.0_real64
    drequest%direct_control_derivative=1.0_real64
    call solve_with_accepted_step_direction(solver,request,workspace,drequest,result,dresult)
    call require(result%status==SW_SOLVE_CONVERGED,'unqualified provider physical solve remains valid')
    call require(dresult%status==SW_STEP_DIRECTION_UNAVAILABLE .and. .not.dresult%available, &
         'unqualified provider derivative fails closed')
  end subroutine check_provider_fail_closed

  subroutine check_retry_fail_closed()
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    type(soil_water_accepted_step_direction_request_t) :: drequest
    type(soil_water_accepted_step_direction_result_t) :: dresult

    call make_request(SW_STEP_CONTROL_BOTTOM_HEAD,h0+50.0_real64,1,fixed_top,request)
    request%numerical%max_iterations=0
    drequest%requested=.true.; drequest%control_coordinate=SW_STEP_CONTROL_BOTTOM_HEAD
    allocate(drequest%incoming_pressure_head(numnod),drequest%incoming_water_content(numnod))
    drequest%incoming_pressure_head=0.0_real64; drequest%incoming_water_content=0.0_real64
    drequest%direct_control_derivative=1.0_real64
    call solve_with_accepted_step_direction(solver,request,workspace,drequest,result,dresult)
    call require(result%status==SW_SOLVE_RETRY_ADVISED,'forced nonacceptance advises retry')
    call require(dresult%status==SW_STEP_DIRECTION_UNAVAILABLE .and. .not.dresult%available, &
         'retry produces no accepted directional result')
  end subroutine check_retry_fail_closed

  subroutine make_request(mode, control_value, mean_method, top_provider, request)
    integer, intent(in) :: mode, mean_method
    real(real64), intent(in) :: control_value
    class(*), target, intent(in) :: top_provider
    type(soil_water_solve_request_t), intent(out) :: request

    request=soil_water_solve_request_t()
    request%parameters=>parameters
    request%base_state=initial_state
    request%step_duration=total_dt
    request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    request%boundary%bottom_mode=mode
    request%boundary%top_flux=-k0
    request%boundary%top_head=h0
    request%boundary%bottom_flux=0.0_real64
    request%boundary%bottom_head=h0
    if (mode==SW_STEP_CONTROL_BOTTOM_FLUX) request%boundary%bottom_flux=control_value
    if (mode==SW_STEP_CONTROL_BOTTOM_HEAD) request%boundary%bottom_head=control_value
    request%physical%macropore_active=.false.
    request%numerical%max_iterations=12
    request%numerical%max_backtracking=6
    request%numerical%conductivity_implicit_mode=0
    request%numerical%conductivity_mean_method=mean_method
    request%numerical%min_step_duration=1.0e-6_real64
    request%numerical%compartment_balance_tolerance=hard_mass_gate
    request%numerical%total_balance_tolerance=hard_mass_gate
    request%numerical%head_abs_tolerance=1.0e-12_real64
    request%numerical%head_rel_tolerance=1.0e-12_real64
    request%numerical%ponding_tolerance=1.0e-12_real64
    request%evaluation%constitutive=>constitutive
    request%evaluation%source_sink=>source_sink
    select type (top_provider)
    type is (fixed_flux_top_boundary_provider_t)
       request%evaluation%top_boundary=>top_provider
    type is (fmr04_fixed_flux_top_provider_t)
       request%evaluation%top_boundary=>top_provider
    class default
       error stop 'FSI37 unsupported test top provider'
    end select
  end subroutine make_request

  subroutine make_incoming_direction(dh,dtheta)
    real(real64), intent(out) :: dh(:),dtheta(:)
    real(real64) :: water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    integer :: i
    call constitutive%evaluate(initial_state%pressure_head,water,conductivity,capacity,dkdh)
    do i=1,numnod
       dh(i)=0.05_real64 + 0.15_real64*real(i-1,real64)/real(max(1,numnod-1),real64)
    end do
    dtheta=capacity*dh
  end subroutine make_incoming_direction

  subroutine configure_problem(initial_head,p,hp,cp,sp,state,qdra,qssdi,qrot,c,k_initial)
    real(real64), intent(in) :: initial_head
    type(soil_water_parameter_set_t), target, intent(out) :: p
    type(b110_default_mvg_parameters_t), target, intent(out) :: hp
    type(b110_default_mvg_provider_t), target, intent(out) :: cp
    type(b110_source_sink_provider_t), target, intent(out) :: sp
    type(soil_water_physical_state_t), intent(out) :: state
    real(real64), allocatable, target, intent(out) :: qdra(:,:),qssdi(:),qrot(:)
    real(real64), allocatable, intent(out) :: c(:,:)
    real(real64), intent(out) :: k_initial
    real(real64) :: heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    integer :: k

    p%parameter_set_id=370001_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod)
    allocate(c(24,numnod)); c=0.0_real64
    do k=1,numnod
      c(1,k)=0.032_real64; c(2,k)=0.423_real64; c(3,k)=4.75_real64
      c(4,k)=0.0135_real64; c(5,k)=0.365_real64; c(6,k)=1.455_real64
      c(7,k)=1.0_real64-1.0_real64/c(6,k); c(8,k)=c(4,k)
      c(9,k)=0.0_real64; c(10,k)=c(3,k); c(11,k)=0.999_real64
      c(12,k)=0.99_real64*c(3,k); c(22,k)=-1.0e6_real64; c(23,k)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp,c)
    call bind_b110_default_mvg_provider(cp,hp,total_dt)
    do k=1,numnod
       heads(k)=initial_head + 5.0_real64*real(k-1,real64)
    end do
    call cp%evaluate(heads,water,conductivity,capacity,dkdh)
    k_initial=conductivity(1)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water
    state%ponding_depth=0.0_real64; state%groundwater_level=-2.0_real64
    allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
    qdra=0.0_real64; qssdi=0.0_real64; qrot=0.0_real64
    call bind_b110_source_sink_provider(sp,qdra,qssdi,qrot)
  end subroutine configure_problem

  logical function same_bits_scalar(a,b)
    real(real64), intent(in) :: a,b
    same_bits_scalar = transfer(a,0_int64)==transfer(b,0_int64)
  end function same_bits_scalar

  logical function same_bits_vector(a,b)
    real(real64), intent(in) :: a(:),b(:)
    integer :: i
    same_bits_vector=size(a)==size(b)
    if (.not.same_bits_vector) return
    do i=1,size(a)
       if (.not.same_bits_scalar(a(i),b(i))) then
          same_bits_vector=.false.; return
       end if
    end do
  end function same_bits_vector

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not.condition) then
      write(*,'(A,1X,A)') 'FSI37_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fsi37_accepted_step_directional_derivative
