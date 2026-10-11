program test_fpe_timeint17c_route_path
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, soil_water_boundary_conditions_t, &
       soil_water_top_boundary_result_t, constitutive_hydraulics_provider_t, SW_SOLVE_CONVERGED
  use mod_fpe_timeint03_reference_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  use mod_fpe_timeint13_predicted_k_provider, only: fpe_timeint13_predicted_k_provider_t, &
       bind_fpe_timeint13_predicted_k_provider
  use mod_fpe_timeint17c_logging_top_provider, only: fpe_timeint17c_logging_top_provider_t, &
       bind_fpe_timeint17c_logging_top_provider, reset_fpe_timeint17c_log, summarize_fpe_timeint17c_log
  implicit none

  integer,parameter :: R_FLUX=1,R_HEAD=2,R_RUNOFF=3
  real(real64),parameter :: pmax=0.05_real64,rsro=0.05_real64

  type(soil_water_parameter_set_t),target :: p
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t),target :: base_constitutive
  type(fpe_timeint13_predicted_k_provider_t),target :: predicted_constitutive
  type(b110_source_sink_provider_t),target :: source_sink
  type(b110_dynamic_top_boundary_solver_provider_t),target :: top
  type(fpe_timeint17c_logging_top_provider_t),target :: logging_top
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: ws
  type(soil_water_physical_state_t) :: state

  real(real64),allocatable,target :: qdra(:,:),qssdi(:),qrot(:)
  real(real64),allocatable :: cof(:,:),tmp_theta(:),tmp_k(:),tmp_cap(:),tmp_dk(:)
  real(real64),allocatable :: theta_dot_n(:),theta_dot_p(:),theta_tilde(:),head_tilde(:),k_origin(:),k_tilde(:)
  real(real64),allocatable :: theta_tg(:),head_tg(:),check_theta(:),k_accept(:)
  character(len=32) :: material_id,mode,route_id
  character(len=64) :: terminal_reason
  integer :: last_solver_status,last_origin_route,last_pred_route,last_endpoint_route,last_accept_route
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,h0,p0,rain,dt,horizon
  integer :: steps,step,target_route,total_nl,total_back,total_jac,total_lin
  integer :: transition_step
  logical :: eligible
  real(real64) :: maxledger,cumledger,max_roundtrip,max_native_rate,max_surface_rate_residual
  real(real64) :: max_k_shift,cumrunoff
  integer :: log_evals,log_distinct,log_transitions,log_first,log_last
  integer :: log_flux_count,log_head_count,log_runoff_count,log_atmos_count,log_other_count
  integer :: log_unavailable,log_derivative_missing
  real(real64) :: log_min_head,log_max_head,log_min_theta,log_max_theta
  real(real64) :: log_min_pond,log_max_pond,log_min_returned_pond,log_max_returned_pond
  real(real64) :: log_min_flux,log_max_flux,log_min_runoff,log_max_runoff
  real(real64) :: log_min_derivative,log_max_derivative

  call get_command_argument(1,material_id)
  call get_command_argument(2,mode)
  call get_command_argument(3,route_id)
  call read_real(4,tr); call read_real(5,ts); call read_real(6,alpha); call read_real(7,nvg)
  call read_real(8,ksat); call read_real(9,lambda); call read_real(10,h0); call read_real(11,p0)
  call read_real(12,rain); call read_real(13,dt); call read_real(14,horizon)

  target_route=route_from_name(trim(route_id))
  call require(target_route>0,'invalid target route')
  call require(trim(mode)=='TG' .or. trim(mode)=='KLAG','invalid mode')
  steps=nint(horizon/dt)
  call require(abs(real(steps,real64)*dt-horizon)<=1.0e-12_real64,'dt does not divide horizon')

  call setup()
  call initialize_state(h0,p0,state)
  allocate(tmp_theta(numnod),tmp_k(numnod),tmp_cap(numnod),tmp_dk(numnod))
  allocate(theta_dot_n(numnod),theta_dot_p(numnod),theta_tilde(numnod),head_tilde(numnod))
  allocate(k_origin(numnod),k_tilde(numnod),theta_tg(numnod),head_tg(numnod),check_theta(numnod),k_accept(numnod))

  total_nl=0; total_back=0; total_jac=0; total_lin=0
  maxledger=0.0_real64; cumledger=0.0_real64; max_roundtrip=0.0_real64
  max_native_rate=0.0_real64; max_surface_rate_residual=0.0_real64; max_k_shift=0.0_real64
  cumrunoff=0.0_real64; eligible=.true.; transition_step=0
  log_evals=0;log_distinct=0;log_transitions=0;log_first=0;log_last=0
  log_flux_count=0;log_head_count=0;log_runoff_count=0;log_atmos_count=0;log_other_count=0
  log_unavailable=0;log_derivative_missing=0
  log_min_head=0.0_real64;log_max_head=0.0_real64;log_min_theta=0.0_real64;log_max_theta=0.0_real64
  log_min_pond=0.0_real64;log_max_pond=0.0_real64
  log_min_returned_pond=0.0_real64;log_max_returned_pond=0.0_real64
  log_min_flux=0.0_real64;log_max_flux=0.0_real64;log_min_runoff=0.0_real64;log_max_runoff=0.0_real64
  log_min_derivative=0.0_real64;log_max_derivative=0.0_real64
  terminal_reason='COMPLETE_SAME_ROUTE'
  last_solver_status=0; last_origin_route=0; last_pred_route=0; last_endpoint_route=0; last_accept_route=0

  do step=1,steps
    if(trim(mode)=='TG')then
      call advance_tg(step)
    else
      call advance_klag(step)
    end if
    if(.not.eligible) exit
  end do

  write(*,'(*(g0))') 'F_PE_TIMEINT17C_RESULT|MATERIAL=',trim(material_id),'|MODE=',trim(mode), &
       '|ROUTE=',trim(route_id),'|DT=',dt,'|HORIZON=',horizon,'|ELIGIBLE=',merge(1,0,eligible), &
       '|TRANSITION_STEP=',transition_step,'|STEPS_DONE=',min(step,steps),'|TERMINAL_REASON=',trim(terminal_reason), &
       '|SOLVER_STATUS=',last_solver_status,'|ORIGIN_ROUTE_CODE=',last_origin_route, &
       '|PRED_ROUTE_CODE=',last_pred_route,'|ENDPOINT_ROUTE_CODE=',last_endpoint_route, &
       '|ACCEPT_ROUTE_CODE=',last_accept_route, &
       '|TOP_H=',state%pressure_head(1),'|TOP_THETA=',state%water_content(1), &
       '|MID_H=',state%pressure_head((numnod+1)/2),'|BOTTOM_H=',state%pressure_head(numnod), &
       '|POND=',state%ponding_depth,'|STORAGE=',sum(state%water_content*p%dz)+state%ponding_depth, &
       '|RUNOFF=',cumrunoff,'|NL=',total_nl,'|BACK=',total_back,'|JAC=',total_jac,'|LIN=',total_lin, &
       '|WORK=',total_nl+total_back+total_jac+total_lin,'|MAX_LEDGER=',maxledger,'|CUM_LEDGER=',cumledger, &
       '|MAX_ROUNDTRIP=',max_roundtrip,'|MAX_NATIVE_RATE=',max_native_rate, &
       '|MAX_SURFACE_RATE_RESIDUAL=',max_surface_rate_residual,'|MAX_K_SHIFT=',max_k_shift, &
       '|LOG_EVALS=',log_evals,'|LOG_DISTINCT_ROUTES=',log_distinct,'|LOG_ROUTE_TRANSITIONS=',log_transitions, &
       '|LOG_FIRST_ROUTE=',log_first,'|LOG_LAST_ROUTE=',log_last,'|LOG_FLUX_COUNT=',log_flux_count, &
       '|LOG_HEAD_COUNT=',log_head_count,'|LOG_RUNOFF_COUNT=',log_runoff_count,'|LOG_ATMOS_COUNT=',log_atmos_count, &
       '|LOG_OTHER_COUNT=',log_other_count,'|LOG_UNAVAILABLE=',log_unavailable, &
       '|LOG_DERIVATIVE_MISSING=',log_derivative_missing,'|LOG_MIN_HEAD=',log_min_head,'|LOG_MAX_HEAD=',log_max_head, &
       '|LOG_MIN_THETA=',log_min_theta,'|LOG_MAX_THETA=',log_max_theta,'|LOG_MIN_POND=',log_min_pond, &
       '|LOG_MAX_POND=',log_max_pond,'|LOG_MIN_RETURNED_POND=',log_min_returned_pond, &
       '|LOG_MAX_RETURNED_POND=',log_max_returned_pond,'|LOG_MIN_FLUX=',log_min_flux,'|LOG_MAX_FLUX=',log_max_flux, &
       '|LOG_MIN_RUNOFF=',log_min_runoff,'|LOG_MAX_RUNOFF=',log_max_runoff, &
       '|LOG_MIN_DERIVATIVE=',log_min_derivative,'|LOG_MAX_DERIVATIVE=',log_max_derivative
  write(*,'(A)') 'F_PE_TIMEINT17C=PASS'

contains

  subroutine read_real(i,x)
    integer,intent(in)::i
    real(real64),intent(out)::x
    character(len=64)::s
    call get_command_argument(i,s); read(s,*)x
  end subroutine

  integer function route_from_name(name) result(r)
    character(len=*),intent(in)::name
    select case(name)
    case('FLUX'); r=R_FLUX
    case('HEAD'); r=R_HEAD
    case('RUNOFF'); r=R_RUNOFF
    case default; r=0
    end select
  end function

  subroutine setup()
    integer::i
    real(real64)::mm
    p%parameter_set_id=26092917_int64; p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),cof(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod)
    cof=0.0_real64; mm=1.0_real64-1.0_real64/nvg
    do i=1,numnod
      cof(1,i)=tr; cof(2,i)=ts; cof(3,i)=ksat; cof(4,i)=alpha; cof(5,i)=lambda; cof(6,i)=nvg; cof(7,i)=mm
      cof(8,i)=alpha; cof(9,i)=0.0_real64; cof(10,i)=ksat; cof(11,i)=0.999_real64; cof(12,i)=0.99_real64*ksat
      cof(22,i)=-1.0e6_real64; cof(23,i)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp,cof)
    allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
    qdra=0.0_real64; qssdi=0.0_real64; qrot=0.0_real64
    call bind_b110_source_sink_provider(source_sink,qdra,qssdi,qrot)
  end subroutine

  subroutine initialize_state(h,pd,s)
    real(real64),intent(in)::h,pd
    type(soil_water_physical_state_t),intent(out)::s
    real(real64)::heads(numnod),th(numnod),kk(numnod),cp(numnod),dk(numnod)
    call bind_b110_default_mvg_provider(base_constitutive,hp,dt)
    heads=h
    call base_constitutive%evaluate(heads,th,kk,cp,dk)
    s%active_nodes=numnod
    allocate(s%pressure_head(numnod),s%water_content(numnod))
    s%pressure_head=heads; s%water_content=th
    s%ponding_depth=pd; s%groundwater_level=-999.0_real64
  end subroutine

  subroutine exact_state_k(s,kout)
    type(soil_water_physical_state_t),intent(in)::s
    real(real64),intent(out)::kout(:)
    call bind_b110_default_mvg_provider(base_constitutive,hp,dt)
    call base_constitutive%evaluate(s%pressure_head,tmp_theta,kout,tmp_cap,tmp_dk)
  end subroutine

  subroutine surface_operator(head_top,pond,k_top,qtop,pdot,runoff_rate,route)
    real(real64),intent(in)::head_top,pond,k_top
    real(real64),intent(out)::qtop,pdot,runoff_rate
    integer,intent(out)::route
    real(real64)::kface,qhead
    kface=0.5_real64*(ksat+k_top)
    qhead=-kface*((pond-head_top)/p%node_distance(1)+1.0_real64)
    if(pond>pmax+1.0e-12_real64)then
      route=R_RUNOFF
      runoff_rate=(pond-pmax)/rsro
      qtop=qhead
      pdot=rain+qtop-runoff_rate
    else if(pond>1.0e-12_real64)then
      route=R_HEAD
      runoff_rate=0.0_real64
      qtop=qhead
      pdot=rain+qtop
    else if(rain+qhead>1.0e-12_real64)then
      route=R_HEAD
      runoff_rate=0.0_real64
      qtop=qhead
      pdot=rain+qtop
    else
      route=R_FLUX
      runoff_rate=0.0_real64
      qtop=-rain
      pdot=0.0_real64
    end if
  end subroutine

  subroutine origin_derivative(s,kout,tdot,pdot,runoff_rate,route,qtop)
    type(soil_water_physical_state_t),intent(in)::s
    real(real64),intent(out)::kout(:),tdot(:),pdot,runoff_rate,qtop
    integer,intent(out)::route
    real(real64)::g(numnod),km,grad
    integer::i
    call exact_state_k(s,kout)
    call surface_operator(s%pressure_head(1),s%ponding_depth,kout(1),qtop,pdot,runoff_rate,route)
    g=0.0_real64
    if(numnod>1)then
      km=0.5_real64*(kout(1)+kout(2))
      grad=(s%pressure_head(1)-s%pressure_head(2))/p%node_distance(2)+1.0_real64
      g(1)=qtop+km*grad
      do i=2,numnod-1
        km=0.5_real64*(kout(i-1)+kout(i))
        grad=(s%pressure_head(i-1)-s%pressure_head(i))/p%node_distance(i)+1.0_real64
        g(i)=-km*grad
        km=0.5_real64*(kout(i)+kout(i+1))
        grad=(s%pressure_head(i)-s%pressure_head(i+1))/p%node_distance(i+1)+1.0_real64
        g(i)=g(i)+km*grad
      end do
      km=0.5_real64*(kout(numnod-1)+kout(numnod))
      grad=(s%pressure_head(numnod-1)-s%pressure_head(numnod))/p%node_distance(numnod)+1.0_real64
      g(numnod)=-km*grad
    else
      g(1)=qtop
    end if
    tdot=-g/p%dz
  end subroutine

  subroutine build_request(req,provider,constitutive,stepdt,prevpond,fixedk)
    type(soil_water_solve_request_t),intent(out)::req
    type(b110_dynamic_top_boundary_solver_provider_t),target,intent(out)::provider
    class(constitutive_hydraulics_provider_t),target,intent(inout)::constitutive
    real(real64),intent(in)::stepdt,prevpond,fixedk
    real(real64)::baltol
    call bind_b110_dynamic_top_boundary_solver_provider(provider,p,hp,1,prevpond,stepdt, &
         rain,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,pmax,rsro,1.0_real64,fixedk)
    req=soil_water_solve_request_t()
    req%parameters=>p; req%base_state=state; req%step_duration=stepdt
    req%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER
    req%boundary%bottom_mode=2; req%boundary%bottom_flux=0.0_real64
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=8; req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0; req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-7_real64
    baltol=max(1.0e-12_real64,2.8e-16_real64/stepdt)
    req%numerical%compartment_balance_tolerance=baltol
    req%numerical%total_balance_tolerance=baltol
    req%numerical%head_abs_tolerance=1.0e-9_real64; req%numerical%head_rel_tolerance=1.0e-9_real64
    req%numerical%ponding_tolerance=1.0e-10_real64
    req%evaluation%constitutive=>constitutive
    req%evaluation%source_sink=>source_sink
    call bind_fpe_timeint17c_logging_top_provider(logging_top,provider)
    req%evaluation%dynamic_top_boundary=>logging_top
  end subroutine

  subroutine advance_tg(step_index)
    integer,intent(in)::step_index
    type(soil_water_solve_request_t)::req
    type(soil_water_solve_result_t)::res
    type(soil_water_boundary_conditions_t)::bc
    type(soil_water_top_boundary_result_t)::topres
    integer::r0,rtilde,rp,ra,i
    real(real64)::pdot_n,pdot_p,run_n,run_p,qtop_n,qtop_p
    real(real64)::storage0,storage1,ledger,runint,rt,qtmp,pdtmp,runtmp
    type(soil_water_physical_state_t)::predstate,acceptstate

    call origin_derivative(state,k_origin,theta_dot_n,pdot_n,run_n,r0,qtop_n)
    last_origin_route=r0
    if(r0/=target_route)then
      terminal_reason='ORIGIN_ROUTE_MISMATCH'
      eligible=.false.; transition_step=step_index; return
    end if

    theta_tilde=state%water_content+dt*theta_dot_n
    if(any(theta_tilde<=tr) .or. any(theta_tilde>=ts))then
      terminal_reason='PREDICTED_RETENTION_DOMAIN_FAILED'
      eligible=.false.; transition_step=step_index; return
    end if
    do i=1,numnod
      head_tilde(i)=inverse_default_mvg(i,theta_tilde(i))
    end do
    predstate=state
    predstate%water_content=theta_tilde
    predstate%pressure_head=head_tilde
    predstate%ponding_depth=state%ponding_depth+dt*pdot_n
    if(predstate%ponding_depth<0.0_real64)then
      terminal_reason='PREDICTED_PONDING_NEGATIVE'
      eligible=.false.; transition_step=step_index; return
    end if
    call exact_state_k(predstate,k_tilde)
    max_k_shift=max(max_k_shift,maxval(abs(k_tilde-k_origin)))
    call surface_operator(predstate%pressure_head(1),predstate%ponding_depth,k_tilde(1),qtmp,pdtmp,runtmp,rtilde)
    last_pred_route=rtilde
    if(rtilde/=target_route)then
      terminal_reason='FORWARD_PREDICTOR_ROUTE_MISMATCH'
      eligible=.false.; transition_step=step_index; return
    end if

    call bind_b110_default_mvg_provider(base_constitutive,hp,dt)
    call bind_fpe_timeint13_predicted_k_provider(predicted_constitutive,base_constitutive,k_tilde)
    call build_request(req,top,predicted_constitutive,dt,state%ponding_depth,k_tilde(1))

    storage0=sum(state%water_content*p%dz)+state%ponding_depth
    call reset_fpe_timeint17c_log()
    call solver%solve(req,ws,res)
    call summarize_fpe_timeint17c_log(log_evals,log_distinct,log_transitions,log_first,log_last, &
         log_flux_count,log_head_count,log_runoff_count,log_atmos_count,log_other_count,log_unavailable, &
         log_derivative_missing,log_min_head,log_max_head,log_min_theta,log_max_theta,log_min_pond,log_max_pond, &
         log_min_returned_pond,log_max_returned_pond,log_min_flux,log_max_flux,log_min_runoff,log_max_runoff, &
         log_min_derivative,log_max_derivative)
    total_nl=total_nl+res%diagnostics%nonlinear_iterations
    total_back=total_back+res%diagnostics%backtracking_attempts
    total_jac=total_jac+res%diagnostics%jacobian_builds
    total_lin=total_lin+res%diagnostics%linear_solves
    last_solver_status=res%status
    if(res%status/=SW_SOLVE_CONVERGED)then
      terminal_reason='ENDPOINT_SOLVE_FAILURE'
      eligible=.false.; transition_step=step_index; return
    end if
    if(res%native_balance_rate_residual_available) max_native_rate=max(max_native_rate,abs(res%native_balance_rate_residual_cm_per_day))

    bc=soil_water_boundary_conditions_t()
    call top%evaluate(res%candidate_state%pressure_head(1),res%candidate_state%water_content(1), &
         res%candidate_state%ponding_depth,bc,topres)
    if(topres%status<=0)then
      terminal_reason='ENDPOINT_TOP_UNAVAILABLE'
      eligible=.false.; transition_step=step_index; return
    end if
    rp=route_from_provider(trim(topres%route))
    last_endpoint_route=rp
    if(rp/=target_route)then
      terminal_reason='ENDPOINT_PROVIDER_ROUTE_MISMATCH'
      eligible=.false.; transition_step=step_index; return
    end if

    theta_dot_p=(res%candidate_state%water_content-state%water_content)/dt
    pdot_p=(res%candidate_state%ponding_depth-state%ponding_depth)/dt
    call surface_operator(res%candidate_state%pressure_head(1),res%candidate_state%ponding_depth,k_tilde(1), &
         qtop_p,qtmp,run_p,ra)
    max_surface_rate_residual=max(max_surface_rate_residual,abs(pdot_p-qtmp))
    if(ra/=target_route)then
      terminal_reason='ENDPOINT_INSTANTANEOUS_ROUTE_MISMATCH'
      eligible=.false.; transition_step=step_index; return
    end if

    theta_tg=state%water_content+0.5_real64*dt*(theta_dot_n+theta_dot_p)
    do i=1,numnod
      head_tg(i)=inverse_default_mvg(i,theta_tg(i))
    end do
    acceptstate=res%candidate_state
    acceptstate%water_content=theta_tg
    acceptstate%pressure_head=head_tg
    acceptstate%ponding_depth=state%ponding_depth+0.5_real64*dt*(pdot_n+pdot_p)
    if(acceptstate%ponding_depth<0.0_real64)then
      terminal_reason='ACCEPTED_PONDING_NEGATIVE'
      eligible=.false.; transition_step=step_index; return
    end if

    call exact_state_k(acceptstate,k_accept)
    call surface_operator(acceptstate%pressure_head(1),acceptstate%ponding_depth,k_accept(1),qtmp,pdtmp,runtmp,ra)
    last_accept_route=ra
    if(ra/=target_route)then
      terminal_reason='ACCEPTED_ROUTE_MISMATCH'
      eligible=.false.; transition_step=step_index; return
    end if

    call bind_b110_default_mvg_provider(base_constitutive,hp,dt)
    call base_constitutive%evaluate(head_tg,check_theta,tmp_k,tmp_cap,tmp_dk)
    rt=maxval(abs(check_theta-theta_tg)); max_roundtrip=max(max_roundtrip,rt)
    call require(rt<=1.0e-12_real64,'TG retention roundtrip failed')

    storage1=sum(acceptstate%water_content*p%dz)+acceptstate%ponding_depth
    runint=0.5_real64*dt*(run_n+run_p)
    ledger=storage1-storage0-rain*dt+runint-res%bottom_flux*dt
    maxledger=max(maxledger,abs(ledger)); cumledger=cumledger+ledger; cumrunoff=cumrunoff+runint
    state=acceptstate
  end subroutine

  subroutine advance_klag(step_index)
    integer,intent(in)::step_index
    type(soil_water_solve_request_t)::req
    type(soil_water_solve_result_t)::res
    type(soil_water_boundary_conditions_t)::bc
    type(soil_water_top_boundary_result_t)::topres
    integer::r0,rp
    real(real64)::pdot0,run0,qtop0,storage0,storage1,ledger
    call origin_derivative(state,k_origin,theta_dot_n,pdot0,run0,r0,qtop0)
    last_origin_route=r0
    if(r0/=target_route)then
      terminal_reason='ORIGIN_ROUTE_MISMATCH'
      eligible=.false.; transition_step=step_index; return
    end if
    call bind_b110_default_mvg_provider(base_constitutive,hp,dt)
    call bind_fpe_timeint13_predicted_k_provider(predicted_constitutive,base_constitutive,k_origin)
    call build_request(req,top,predicted_constitutive,dt,state%ponding_depth,k_origin(1))
    storage0=sum(state%water_content*p%dz)+state%ponding_depth
    call reset_fpe_timeint17c_log()
    call solver%solve(req,ws,res)
    call summarize_fpe_timeint17c_log(log_evals,log_distinct,log_transitions,log_first,log_last, &
         log_flux_count,log_head_count,log_runoff_count,log_atmos_count,log_other_count,log_unavailable, &
         log_derivative_missing,log_min_head,log_max_head,log_min_theta,log_max_theta,log_min_pond,log_max_pond, &
         log_min_returned_pond,log_max_returned_pond,log_min_flux,log_max_flux,log_min_runoff,log_max_runoff, &
         log_min_derivative,log_max_derivative)
    total_nl=total_nl+res%diagnostics%nonlinear_iterations
    total_back=total_back+res%diagnostics%backtracking_attempts
    total_jac=total_jac+res%diagnostics%jacobian_builds
    total_lin=total_lin+res%diagnostics%linear_solves
    last_solver_status=res%status
    if(res%status/=SW_SOLVE_CONVERGED)then
      terminal_reason='ENDPOINT_SOLVE_FAILURE'
      eligible=.false.; transition_step=step_index; return
    end if
    bc=soil_water_boundary_conditions_t()
    call top%evaluate(res%candidate_state%pressure_head(1),res%candidate_state%water_content(1), &
         res%candidate_state%ponding_depth,bc,topres)
    if(topres%status<=0)then
      terminal_reason='ENDPOINT_TOP_UNAVAILABLE'
      eligible=.false.; transition_step=step_index; return
    end if
    rp=route_from_provider(trim(topres%route))
    last_endpoint_route=rp
    if(rp/=target_route)then
      terminal_reason='ENDPOINT_PROVIDER_ROUTE_MISMATCH'
      eligible=.false.; transition_step=step_index; return
    end if
    storage1=sum(res%candidate_state%water_content*p%dz)+res%candidate_state%ponding_depth
    ledger=storage1-storage0-rain*dt+topres%runoff_depth-res%bottom_flux*dt
    maxledger=max(maxledger,abs(ledger)); cumledger=cumledger+ledger; cumrunoff=cumrunoff+topres%runoff_depth
    state=res%candidate_state
  end subroutine

  integer function route_from_provider(name) result(r)
    character(len=*),intent(in)::name
    if(index(name,'surface-flux')>0)then
      r=R_FLUX
    else if(index(name,'linear-runoff')>0)then
      r=R_RUNOFF
    else if(index(name,'ponded-head')>0)then
      r=R_HEAD
    else
      r=0
    end if
  end function

  real(real64) function inverse_default_mvg(node,theta) result(head)
    integer,intent(in)::node
    real(real64),intent(in)::theta
    real(real64)::se,x
    if(theta>=hp%cofgen(2,node))then
      head=0.0_real64
    else if(theta>hp%cofgen(26,node))then
      head=-1.0e-2_real64+(theta-hp%cofgen(26,node))/hp%cofgen(27,node)
    else
      se=max(1.0e-15_real64,min(1.0_real64,(theta-hp%cofgen(1,node))/hp%cofgen(25,node)))
      x=(se**(-1.0_real64/hp%cofgen(7,node))-1.0_real64)**(1.0_real64/hp%cofgen(6,node))
      head=-x/hp%cofgen(4,node)
    end if
  end function

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)') 'F_PE_TIMEINT17C_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine
end program test_fpe_timeint17c_route_path
