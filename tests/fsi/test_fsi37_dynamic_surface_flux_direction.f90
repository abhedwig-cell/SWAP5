program test_fsi37_dynamic_surface_flux_direction
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, soil_water_top_boundary_result_t, &
       SW_SOLVE_CONVERGED, SW_TOP_BOUNDARY_AVAILABLE, SW_TOP_BOUNDARY_REGIME_FLUX
  use mod_soil_water_accepted_step_direction_contract, only: &
       soil_water_accepted_step_direction_request_t, soil_water_accepted_step_direction_result_t, &
       SW_STEP_DIRECTION_AVAILABLE, SW_STEP_DIRECTION_UNAVAILABLE, &
       SW_STEP_CONTROL_BOTTOM_FLUX, SW_STEP_CONTROL_BOTTOM_HEAD
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_accepted_step_directional_service, only: solve_with_accepted_step_direction
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  implicit none

  real(real64), parameter :: total_dt = 0.25_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  real(real64), parameter :: previous_pond = 0.01_real64
  real(real64), parameter :: incoming_pond_direction = 0.03_real64
  real(real64), parameter :: precipitation = 0.02_real64
  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(soil_water_physical_state_t) :: initial_state
  real(real64), allocatable, target :: drainage(:,:), subsurface(:), root_sink(:)
  real(real64), allocatable :: cofgen(:,:)
  real(real64), allocatable :: incoming_h(:), incoming_theta(:)
  real(real64) :: h0
  integer :: cases, mean_method

  h0 = -100.0_real64
  call configure_problem(h0, parameters, hydraulic_parameters, constitutive, source_sink, initial_state, &
       drainage, subsurface, root_sink, cofgen)
  allocate(incoming_h(numnod), incoming_theta(numnod))
  call make_incoming_direction(incoming_h, incoming_theta)

  cases = 0
  do mean_method = 1, 6
     call check_dynamic_fd_case(SW_STEP_CONTROL_BOTTOM_FLUX, 0.0_real64, mean_method, 0.7_real64, cases)
     call check_dynamic_fd_case(SW_STEP_CONTROL_BOTTOM_HEAD, h0+20.0_real64, mean_method, 0.7_real64, cases)
  end do
  call check_capacity_limited_fail_closed()

  call require(cases == 12, 'twelve dynamic smooth FD cases executed')
  write(*,'(A,I0)') 'FSI37_DYNAMIC_FD_CASES=',cases
  write(*,'(A)') 'FSI37_DYNAMIC_SWKMEAN_METHODS_1_6=PASS'
  write(*,'(A)') 'FSI37_DYNAMIC_TOP_FLUX_AND_MODE5_MASS_DERIVATIVE=PASS'
  write(*,'(A)') 'FSI37_DYNAMIC_CAPACITY_LIMITED_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FSI37_DYNAMIC_SURFACE_FLUX_DIRECTION PASS'

contains

  subroutine check_dynamic_fd_case(mode, control_value, mean_method, direct_control, counter)
    integer, intent(in) :: mode, mean_method
    real(real64), intent(in) :: control_value, direct_control
    integer, intent(inout) :: counter
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: ws_direction, ws_baseline, ws_plus, ws_minus
    type(b110_dynamic_top_boundary_solver_provider_t), target :: top
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: directional_solve, baseline, plus_result, minus_result
    type(soil_water_accepted_step_direction_request_t) :: drequest
    type(soil_water_accepted_step_direction_result_t) :: dresult
    type(soil_water_top_boundary_result_t) :: base_top, accepted_top
    real(real64), allocatable :: fd_h(:), fd_theta(:)
    real(real64) :: eps1, eps2, err1, err2
    real(real64) :: top_fd1, top_fd2, top_err1, top_err2
    real(real64) :: bottom_fd1, bottom_fd2, bottom_err1, bottom_err2
    real(real64) :: pond_fd1, pond_fd2, pond_err1, pond_err2

    call bind_dynamic_top(top, mean_method, previous_pond, 0.0_real64, 0.0_real64, precipitation)
    call make_request(mode, control_value, mean_method, top, request)
    call top%evaluate(request%base_state%pressure_head(1), request%base_state%water_content(1), &
         request%base_state%ponding_depth, request%boundary, base_top)
    call require(base_top%status==SW_TOP_BOUNDARY_AVAILABLE .and. base_top%regime==SW_TOP_BOUNDARY_REGIME_FLUX .and. &
         trim(base_top%route)=='surface-flux','dynamic base route is surface-flux')

    drequest%requested=.true.
    drequest%control_coordinate=mode
    allocate(drequest%incoming_pressure_head(numnod),drequest%incoming_water_content(numnod))
    drequest%incoming_pressure_head=incoming_h
    drequest%incoming_water_content=incoming_theta
    drequest%incoming_ponding_depth=incoming_pond_direction
    drequest%direct_control_derivative=direct_control

    call solve_with_accepted_step_direction(solver,request,ws_direction,drequest,directional_solve,dresult)
    call require(directional_solve%status==SW_SOLVE_CONVERGED,'dynamic directional physical solve converged')
    call require(dresult%status==SW_STEP_DIRECTION_AVAILABLE .and. dresult%available,'dynamic direction available')
    call require(dresult%additional_tridiagonal_backsolves==1,'dynamic exactly one added backsolve')
    call require(dresult%additional_jacobian_builds==0,'dynamic no added Jacobian build')
    call require(dresult%additional_full_nonlinear_solves==0,'dynamic no added nonlinear trajectory')
    call require(all(ieee_is_finite(dresult%outgoing_pressure_head)),'dynamic finite outgoing head direction')
    call require(all(ieee_is_finite(dresult%outgoing_water_content)),'dynamic finite outgoing theta direction')
    call require(abs(dresult%top_flux_derivative + incoming_pond_direction/total_dt) <= 1.0e-13_real64, &
         'dynamic analytic previous-pond top-flux derivative')
    call require(abs(dresult%outgoing_ponding_depth) <= 1.0e-15_real64,'dynamic surface-flux outgoing pond direction zero')

    call top%evaluate(directional_solve%candidate_state%pressure_head(1), &
         directional_solve%candidate_state%water_content(1), directional_solve%candidate_state%ponding_depth, &
         request%boundary, accepted_top)
    call require(accepted_top%status==SW_TOP_BOUNDARY_AVAILABLE .and. accepted_top%regime==SW_TOP_BOUNDARY_REGIME_FLUX .and. &
         trim(accepted_top%route)=='surface-flux','dynamic accepted route is surface-flux')

    call solver%solve(request,ws_baseline,baseline)
    call require(baseline%status==SW_SOLVE_CONVERGED,'dynamic baseline physical solve converged')
    call require(same_bits_vector(baseline%candidate_state%pressure_head,directional_solve%candidate_state%pressure_head), &
         'dynamic ON/OFF pressure-head bit identity')
    call require(same_bits_vector(baseline%candidate_state%water_content,directional_solve%candidate_state%water_content), &
         'dynamic ON/OFF water-content bit identity')
    call require(same_bits_scalar(baseline%candidate_state%ponding_depth,directional_solve%candidate_state%ponding_depth), &
         'dynamic ON/OFF ponding bit identity')
    call require(same_bits_scalar(baseline%top_flux,directional_solve%top_flux),'dynamic ON/OFF top-flux bit identity')
    call require(same_bits_scalar(baseline%bottom_flux,directional_solve%bottom_flux),'dynamic ON/OFF bottom-flux bit identity')
    call require(same_bits_scalar(baseline%unrounded_mass_balance_residual, &
         directional_solve%unrounded_mass_balance_residual),'dynamic ON/OFF mass diagnostic bit identity')

    allocate(fd_h(numnod),fd_theta(numnod))
    eps1=1.0e-4_real64
    eps2=5.0e-5_real64
    call centered_fd_dynamic(request,mode,direct_control,mean_method,eps1,ws_plus,ws_minus,plus_result,minus_result, &
         fd_h,fd_theta,top_fd1,bottom_fd1,pond_fd1)
    err1=max(maxval(abs(fd_h-dresult%outgoing_pressure_head)),maxval(abs(fd_theta-dresult%outgoing_water_content)))
    top_err1=abs(top_fd1-dresult%top_flux_derivative)
    bottom_err1=abs(bottom_fd1-dresult%bottom_flux_derivative)
    pond_err1=abs(pond_fd1-dresult%outgoing_ponding_depth)

    call centered_fd_dynamic(request,mode,direct_control,mean_method,eps2,ws_plus,ws_minus,plus_result,minus_result, &
         fd_h,fd_theta,top_fd2,bottom_fd2,pond_fd2)
    err2=max(maxval(abs(fd_h-dresult%outgoing_pressure_head)),maxval(abs(fd_theta-dresult%outgoing_water_content)))
    top_err2=abs(top_fd2-dresult%top_flux_derivative)
    bottom_err2=abs(bottom_fd2-dresult%bottom_flux_derivative)
    pond_err2=abs(pond_fd2-dresult%outgoing_ponding_depth)

    call require(err2<=max(2.0e-6_real64,1.25_real64*err1),'dynamic FD state derivative convergence')
    call require(top_err2<=max(2.0e-6_real64,1.25_real64*top_err1),'dynamic FD top-flux derivative convergence')
    call require(bottom_err2<=max(2.0e-6_real64,1.25_real64*bottom_err1),'dynamic FD bottom-flux derivative convergence')
    call require(pond_err2<=max(2.0e-8_real64,1.25_real64*pond_err1),'dynamic FD pond derivative convergence')
    call require(err2<=2.0e-5_real64*max(1.0_real64,maxval(abs(dresult%outgoing_pressure_head))), &
         'dynamic FD state derivative absolute/relative gate')
    call require(top_err2<=2.0e-5_real64*max(1.0_real64,abs(dresult%top_flux_derivative)), &
         'dynamic FD top-flux derivative absolute/relative gate')
    call require(bottom_err2<=2.0e-5_real64*max(1.0_real64,abs(dresult%bottom_flux_derivative)), &
         'dynamic FD bottom-flux derivative absolute/relative gate')
    call require(pond_err2<=2.0e-8_real64,'dynamic FD pond derivative absolute gate')

    counter=counter+1
    write(*,'(A,I0,A,I0,A,ES12.4,A,ES12.4,A,ES12.4,A,ES12.4)') &
         'FSI37_DYNAMIC_CASE:MODE=',mode,':MEAN=',mean_method,':STATE_ERR=',err2,':TOP_ERR=',top_err2, &
         ':BOTTOM_ERR=',bottom_err2,':POND_ERR=',pond_err2
  end subroutine check_dynamic_fd_case

  subroutine centered_fd_dynamic(base_request,mode,direct_control,mean_method,eps,ws_plus,ws_minus, &
       plus_result,minus_result,fd_h,fd_theta,fd_top_flux,fd_bottom_flux,fd_pond)
    type(soil_water_solve_request_t), intent(in) :: base_request
    integer, intent(in) :: mode,mean_method
    real(real64), intent(in) :: direct_control,eps
    type(reference_richards_legacy_workspace_t), intent(inout) :: ws_plus,ws_minus
    type(soil_water_solve_result_t), intent(out) :: plus_result,minus_result
    real(real64), intent(out) :: fd_h(:),fd_theta(:),fd_top_flux,fd_bottom_flux,fd_pond
    type(reference_richards_legacy_solver_t) :: solver
    type(b110_dynamic_top_boundary_solver_provider_t), target :: plus_top,minus_top
    type(soil_water_solve_request_t) :: plus_request,minus_request

    plus_request=base_request
    minus_request=base_request
    plus_request%base_state%pressure_head=base_request%base_state%pressure_head+eps*incoming_h
    minus_request%base_state%pressure_head=base_request%base_state%pressure_head-eps*incoming_h
    plus_request%base_state%water_content=base_request%base_state%water_content+eps*incoming_theta
    minus_request%base_state%water_content=base_request%base_state%water_content-eps*incoming_theta
    plus_request%base_state%ponding_depth=base_request%base_state%ponding_depth+eps*incoming_pond_direction
    minus_request%base_state%ponding_depth=base_request%base_state%ponding_depth-eps*incoming_pond_direction
    call bind_dynamic_top(plus_top,mean_method,previous_pond+eps*incoming_pond_direction,0.0_real64,0.0_real64,precipitation)
    call bind_dynamic_top(minus_top,mean_method,previous_pond-eps*incoming_pond_direction,0.0_real64,0.0_real64,precipitation)
    plus_request%evaluation%dynamic_top_boundary=>plus_top
    minus_request%evaluation%dynamic_top_boundary=>minus_top
    select case(mode)
    case(SW_STEP_CONTROL_BOTTOM_FLUX)
       plus_request%boundary%bottom_flux=base_request%boundary%bottom_flux+eps*direct_control
       minus_request%boundary%bottom_flux=base_request%boundary%bottom_flux-eps*direct_control
    case(SW_STEP_CONTROL_BOTTOM_HEAD)
       plus_request%boundary%bottom_head=base_request%boundary%bottom_head+eps*direct_control
       minus_request%boundary%bottom_head=base_request%boundary%bottom_head-eps*direct_control
    end select
    call solver%solve(plus_request,ws_plus,plus_result)
    call solver%solve(minus_request,ws_minus,minus_result)
    call require(plus_result%status==SW_SOLVE_CONVERGED .and. minus_result%status==SW_SOLVE_CONVERGED, &
         'dynamic centered FD solves converged')
    fd_h=(plus_result%candidate_state%pressure_head-minus_result%candidate_state%pressure_head)/(2.0_real64*eps)
    fd_theta=(plus_result%candidate_state%water_content-minus_result%candidate_state%water_content)/(2.0_real64*eps)
    fd_top_flux=(plus_result%top_flux-minus_result%top_flux)/(2.0_real64*eps)
    fd_bottom_flux=(plus_result%bottom_flux-minus_result%bottom_flux)/(2.0_real64*eps)
    fd_pond=(plus_result%candidate_state%ponding_depth-minus_result%candidate_state%ponding_depth)/(2.0_real64*eps)
  end subroutine centered_fd_dynamic

  subroutine check_capacity_limited_fail_closed()
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(b110_dynamic_top_boundary_solver_provider_t), target :: probe_top, top
    type(soil_water_solve_request_t) :: probe_request, request
    type(soil_water_solve_result_t) :: result
    type(soil_water_accepted_step_direction_request_t) :: drequest
    type(soil_water_accepted_step_direction_result_t) :: dresult
    type(soil_water_top_boundary_result_t) :: probe_result, top_result
    real(real64), parameter :: large_demand=1.0e9_real64
    real(real64), parameter :: target_qtop=-0.05_real64
    real(real64) :: capacity, scale

    ! First ask the unchanged value provider to materialize its own Emax at the
    ! exact base hydraulic state.  A very large demand makes bare evaporation
    ! capacity-limited without hard-coding a soil-specific Emax value.
    call bind_dynamic_top(probe_top,1,0.0_real64,large_demand,0.0_real64,0.0_real64)
    call make_request(SW_STEP_CONTROL_BOTTOM_HEAD,h0+20.0_real64,1,probe_top,probe_request)
    probe_request%base_state%ponding_depth=0.0_real64
    call probe_top%evaluate(probe_request%base_state%pressure_head(1),probe_request%base_state%water_content(1), &
         probe_request%base_state%ponding_depth,probe_request%boundary,probe_result)
    call require(probe_result%status==SW_TOP_BOUNDARY_AVAILABLE,'capacity probe available')
    capacity=probe_result%bare_soil_evaporation
    call require(ieee_is_finite(capacity) .and. capacity>0.0_real64 .and. capacity<large_demand, &
         'capacity probe materializes finite limited evaporation')

    ! Rebind the same provider physics with supply chosen from that measured
    ! capacity so q1=capacity-supply is a modest fixed surface flux.  This keeps
    ! the physical solve well conditioned while remaining strictly on the dry
    ! capacity-limited branch that F-SI37 must fail closed for sensitivity.
    call bind_dynamic_top(top,1,0.0_real64,large_demand,0.0_real64,capacity-target_qtop)
    call make_request(SW_STEP_CONTROL_BOTTOM_HEAD,h0+20.0_real64,1,top,request)
    request%base_state%ponding_depth=0.0_real64
    call top%evaluate(request%base_state%pressure_head(1),request%base_state%water_content(1), &
         request%base_state%ponding_depth,request%boundary,top_result)
    call require(top_result%status==SW_TOP_BOUNDARY_AVAILABLE .and. &
         top_result%regime==SW_TOP_BOUNDARY_REGIME_FLUX .and. trim(top_result%route)=='surface-flux', &
         'provider-derived capacity-limited surface-flux fixture')
    scale=max(1.0_real64,abs(capacity))
    call require(abs(top_result%bare_soil_evaporation-capacity)<=1.0e-12_real64*scale, &
         'capacity-limited evaporation preserved')
    call require(abs(top_result%actual_top_flux-target_qtop)<=1.0e-12_real64*scale, &
         'capacity-limited fixture has bounded physical top flux')

    drequest%requested=.true.; drequest%control_coordinate=SW_STEP_CONTROL_BOTTOM_HEAD
    allocate(drequest%incoming_pressure_head(numnod),drequest%incoming_water_content(numnod))
    drequest%incoming_pressure_head=incoming_h; drequest%incoming_water_content=incoming_theta
    drequest%incoming_ponding_depth=0.0_real64; drequest%direct_control_derivative=1.0_real64
    call solve_with_accepted_step_direction(solver,request,workspace,drequest,result,dresult)
    call require(result%status==SW_SOLVE_CONVERGED,'capacity-limited physical solve remains valid')
    call require(dresult%status==SW_STEP_DIRECTION_UNAVAILABLE .and. .not.dresult%available, &
         'capacity-limited dynamic derivative fails closed')
    call require(dresult%additional_tridiagonal_backsolves==0,'capacity-limited no tangent backsolve')
  end subroutine check_capacity_limited_fail_closed

  subroutine make_request(mode,control_value,mean_method,top,request)
    integer, intent(in) :: mode,mean_method
    real(real64), intent(in) :: control_value
    type(b110_dynamic_top_boundary_solver_provider_t), target, intent(in) :: top
    type(soil_water_solve_request_t), intent(out) :: request

    request=soil_water_solve_request_t()
    request%parameters=>parameters
    request%base_state=initial_state
    request%step_duration=total_dt
    request%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER
    request%boundary%bottom_mode=mode
    request%boundary%top_flux=0.0_real64
    request%boundary%top_head=h0
    request%boundary%bottom_flux=0.0_real64
    request%boundary%bottom_head=h0
    if(mode==SW_STEP_CONTROL_BOTTOM_FLUX) request%boundary%bottom_flux=control_value
    if(mode==SW_STEP_CONTROL_BOTTOM_HEAD) request%boundary%bottom_head=control_value
    request%physical%macropore_active=.false.
    request%numerical%max_iterations=20
    request%numerical%max_backtracking=8
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
    request%evaluation%dynamic_top_boundary=>top
  end subroutine make_request

  subroutine bind_dynamic_top(top,mean_method,pond_before,bare_demand,pond_demand,supply)
    type(b110_dynamic_top_boundary_solver_provider_t), intent(out) :: top
    integer, intent(in) :: mean_method
    real(real64), intent(in) :: pond_before,bare_demand,pond_demand,supply
    call bind_b110_dynamic_top_boundary_solver_provider(top,parameters,hydraulic_parameters,mean_method,pond_before, &
         total_dt,supply,0.0_real64,0.0_real64,0.0_real64,bare_demand,pond_demand,1000.0_real64,0.5_real64,1.0_real64)
  end subroutine bind_dynamic_top

  subroutine make_incoming_direction(dh,dtheta)
    real(real64), intent(out) :: dh(:),dtheta(:)
    real(real64) :: water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    integer :: i
    call constitutive%evaluate(initial_state%pressure_head,water,conductivity,capacity,dkdh)
    do i=1,numnod
       dh(i)=0.04_real64+0.10_real64*real(i-1,real64)/real(max(1,numnod-1),real64)
    end do
    dtheta=capacity*dh
  end subroutine make_incoming_direction

  subroutine configure_problem(initial_head,p,hp,cp,sp,state,qdra,qssdi,qrot,c)
    real(real64), intent(in) :: initial_head
    type(soil_water_parameter_set_t), target, intent(out) :: p
    type(b110_default_mvg_parameters_t), target, intent(out) :: hp
    type(b110_default_mvg_provider_t), target, intent(out) :: cp
    type(b110_source_sink_provider_t), target, intent(out) :: sp
    type(soil_water_physical_state_t), intent(out) :: state
    real(real64), allocatable, target, intent(out) :: qdra(:,:),qssdi(:),qrot(:)
    real(real64), allocatable, intent(out) :: c(:,:)
    real(real64) :: heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    integer :: k

    p%parameter_set_id=370002_int64
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
       heads(k)=initial_head+4.0_real64*real(k-1,real64)
    end do
    call cp%evaluate(heads,water,conductivity,capacity,dkdh)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water
    state%ponding_depth=previous_pond; state%groundwater_level=-2.0_real64
    allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
    qdra=0.0_real64; qssdi=0.0_real64; qrot=0.0_real64
    call bind_b110_source_sink_provider(sp,qdra,qssdi,qrot)
  end subroutine configure_problem

  logical function same_bits_scalar(a,b)
    real(real64), intent(in) :: a,b
    same_bits_scalar=transfer(a,0_int64)==transfer(b,0_int64)
  end function same_bits_scalar

  logical function same_bits_vector(a,b)
    real(real64), intent(in) :: a(:),b(:)
    integer :: i
    same_bits_vector=size(a)==size(b)
    if(.not.same_bits_vector)return
    do i=1,size(a)
       if(.not.same_bits_scalar(a(i),b(i)))then
          same_bits_vector=.false.; return
       end if
    end do
  end function same_bits_vector

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if(.not.condition)then
       write(*,'(A,1X,A)')'FSI37_DYNAMIC_FAIL',trim(label)
       error stop 1
    end if
  end subroutine require
end program test_fsi37_dynamic_surface_flux_direction
