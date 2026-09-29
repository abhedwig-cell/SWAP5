program test_fpe_timeint17_unsplit
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, soil_water_boundary_conditions_t, &
       soil_water_top_boundary_result_t, SW_SOLVE_CONVERGED
  use mod_fpe_timeint03_reference_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  use mod_fpe_timeint13_predicted_k_provider, only: fpe_timeint13_predicted_k_provider_t, &
       bind_fpe_timeint13_predicted_k_provider
  implicit none

  type(soil_water_parameter_set_t),target :: p
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t),target :: base_constitutive
  type(fpe_timeint13_predicted_k_provider_t),target :: predicted_constitutive
  type(b110_source_sink_provider_t),target :: source_sink
  type(b110_dynamic_top_boundary_solver_provider_t),target :: top
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: ws
  type(soil_water_physical_state_t) :: state

  real(real64),allocatable,target :: qdra(:,:),qssdi(:),qrot(:)
  real(real64),allocatable :: cof(:,:),theta_dot_n(:),theta_dot_p(:),theta_tilde(:),head_tilde(:)
  real(real64),allocatable :: k_origin(:),k_tilde(:),theta_tg(:),head_tg(:),check_theta(:)
  real(real64),allocatable :: tmp_theta(:),tmp_k(:),tmp_cap(:),tmp_dk(:)
  character(len=32) :: material_id,regime_id
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,hinit,rain
  real(real64),parameter :: dt=0.005_real64,horizon=0.12_real64,pmax=0.05_real64,rsro=0.05_real64
  integer :: steps,step,total_nl,total_back,total_jac,total_lin,total_alt
  integer :: route_switches,same_route_steps
  real(real64) :: max_same_route_ledger,cum_same_route_ledger,max_roundtrip,max_k_shift
  real(real64) :: min_pond,max_pond
  character(len=48) :: final_route

  call get_command_argument(1,material_id)
  call get_command_argument(2,regime_id)
  call read_real(3,tr); call read_real(4,ts); call read_real(5,alpha); call read_real(6,nvg)
  call read_real(7,ksat); call read_real(8,lambda); call read_real(9,hinit); call read_real(10,rain)

  steps=nint(horizon/dt)
  call setup()
  call initialize_state(hinit,state)
  allocate(theta_dot_n(numnod),theta_dot_p(numnod),theta_tilde(numnod),head_tilde(numnod))
  allocate(k_origin(numnod),k_tilde(numnod),theta_tg(numnod),head_tg(numnod),check_theta(numnod))
  allocate(tmp_theta(numnod),tmp_k(numnod),tmp_cap(numnod),tmp_dk(numnod))

  total_nl=0; total_back=0; total_jac=0; total_lin=0; total_alt=0
  route_switches=0; same_route_steps=0
  max_same_route_ledger=0.0_real64; cum_same_route_ledger=0.0_real64
  max_roundtrip=0.0_real64; max_k_shift=0.0_real64
  min_pond=state%ponding_depth; max_pond=state%ponding_depth; final_route='none'

  do step=1,steps
    call advance_one(step)
  end do

  write(*,'(*(g0))') 'F_PE_TIMEINT17_UNSPLIT_RESULT|MATERIAL=',trim(material_id),'|REGIME=',trim(regime_id), &
       '|STEPS=',steps,'|NL=',total_nl,'|BACK=',total_back,'|JAC=',total_jac,'|LIN=',total_lin,'|ALT=',total_alt, &
       '|WORK=',total_nl+total_back+total_jac+total_lin,'|ROUTE_SWITCHES=',route_switches, &
       '|SAME_ROUTE_STEPS=',same_route_steps,'|MAX_SAME_ROUTE_LEDGER=',max_same_route_ledger, &
       '|CUM_SAME_ROUTE_LEDGER=',cum_same_route_ledger,'|MAX_ROUNDTRIP=',max_roundtrip,'|MAX_K_SHIFT=',max_k_shift, &
       '|POND=',state%ponding_depth,'|MIN_POND=',min_pond,'|MAX_POND=',max_pond, &
       '|STORAGE=',sum(state%water_content*p%dz)+state%ponding_depth,'|TOP_H=',state%pressure_head(1), &
       '|TOP_THETA=',state%water_content(1),'|ROUTE=',trim(final_route)
  write(*,'(A)') 'F_PE_TIMEINT17_UNSPLIT=PASS'

contains
  subroutine read_real(i,x)
    integer,intent(in)::i
    real(real64),intent(out)::x
    character(len=64)::s
    call get_command_argument(i,s); read(s,*)x
  end subroutine

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

  subroutine initialize_state(h,s)
    real(real64),intent(in)::h
    type(soil_water_physical_state_t),intent(out)::s
    real(real64)::heads(numnod),th(numnod),kk(numnod),cp(numnod),dk(numnod)
    call bind_b110_default_mvg_provider(base_constitutive,hp,dt)
    heads=h
    call base_constitutive%evaluate(heads,th,kk,cp,dk)
    s%active_nodes=numnod
    allocate(s%pressure_head(numnod),s%water_content(numnod))
    s%pressure_head=heads; s%water_content=th
    s%ponding_depth=0.0_real64; s%groundwater_level=-999.0_real64
  end subroutine

  subroutine origin_rates(s,theta_dot,pond_dot,kout,tres)
    type(soil_water_physical_state_t),intent(in)::s
    real(real64),intent(out)::theta_dot(:),pond_dot,kout(:)
    type(soil_water_top_boundary_result_t),intent(out)::tres
    type(soil_water_boundary_conditions_t)::bc
    real(real64)::th(numnod),cp(numnod),dk(numnod),g(numnod),km,grad,runoff_rate
    integer::i
    call bind_b110_default_mvg_provider(base_constitutive,hp,dt)
    call base_constitutive%evaluate(s%pressure_head,th,kout,cp,dk)
    call require(maxval(abs(th-s%water_content))<=1.0e-12_real64,'origin theta/head mismatch')
    call bind_b110_dynamic_top_boundary_solver_provider(top,p,hp,1,s%ponding_depth,dt,rain, &
         0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,pmax,rsro,1.0_real64,kout(1))
    bc=soil_water_boundary_conditions_t()
    call top%evaluate(s%pressure_head(1),s%water_content(1),s%ponding_depth,bc,tres)
    call require(tres%status>0,'origin top unavailable')
    g=0.0_real64
    km=0.5_real64*(kout(1)+kout(2))
    grad=(s%pressure_head(1)-s%pressure_head(2))/p%node_distance(2)+1.0_real64
    g(1)=tres%actual_top_flux+km*grad
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
    theta_dot=-g/p%dz
    runoff_rate=tres%runoff_depth/dt
    pond_dot=tres%net_potential_surface_flux+tres%actual_top_flux-runoff_rate
  end subroutine

  subroutine advance_one(step_index)
    integer,intent(in)::step_index
    type(soil_water_solve_request_t)::req
    type(soil_water_solve_result_t)::res
    type(soil_water_boundary_conditions_t)::bc
    type(soil_water_top_boundary_result_t)::origin_top,end_top
    real(real64)::pond0,pond_dot_n,pond_dot_p,pond_tilde,pond_tg
    real(real64)::effective_baltol,storage0,storage1,ledger,rt,runoff_tg
    integer::i

    pond0=state%ponding_depth
    call origin_rates(state,theta_dot_n,pond_dot_n,k_origin,origin_top)
    theta_tilde=state%water_content+dt*theta_dot_n
    pond_tilde=pond0+dt*pond_dot_n
    call require(all(theta_tilde>tr) .and. all(theta_tilde<ts),'predicted theta outside retention domain')
    call require(pond_tilde>=-1.0e-10_real64,'predicted negative ponding')
    do i=1,numnod
      head_tilde(i)=inverse_default_mvg(i,theta_tilde(i))
    end do
    call bind_b110_default_mvg_provider(base_constitutive,hp,dt)
    call base_constitutive%evaluate(head_tilde,tmp_theta,k_tilde,tmp_cap,tmp_dk)
    call require(maxval(abs(tmp_theta-theta_tilde))<=1.0e-12_real64,'predictor roundtrip failed')
    call require(all(ieee_is_finite(k_tilde)) .and. all(k_tilde>0.0_real64),'invalid predicted K')
    max_k_shift=max(max_k_shift,maxval(abs(k_tilde-k_origin)))
    call bind_fpe_timeint13_predicted_k_provider(predicted_constitutive,base_constitutive,k_tilde)
    call bind_b110_dynamic_top_boundary_solver_provider(top,p,hp,1,pond0,dt,rain,0.0_real64,0.0_real64,0.0_real64, &
         0.0_real64,0.0_real64,pmax,rsro,1.0_real64,k_tilde(1))

    req=soil_water_solve_request_t()
    req%parameters=>p; req%base_state=state; req%step_duration=dt
    req%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER
    req%boundary%bottom_mode=2; req%boundary%bottom_flux=0.0_real64
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=8; req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0; req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-6_real64
    effective_baltol=max(1.0e-12_real64,2.8e-16_real64/dt)
    req%numerical%compartment_balance_tolerance=effective_baltol
    req%numerical%total_balance_tolerance=effective_baltol
    req%numerical%head_abs_tolerance=1.0e-9_real64; req%numerical%head_rel_tolerance=1.0e-9_real64
    req%numerical%ponding_tolerance=1.0e-10_real64
    req%evaluation%constitutive=>predicted_constitutive
    req%evaluation%source_sink=>source_sink
    req%evaluation%dynamic_top_boundary=>top

    storage0=sum(state%water_content*p%dz)+pond0
    call solver%solve(req,ws,res)
    total_nl=total_nl+res%diagnostics%nonlinear_iterations
    total_back=total_back+res%diagnostics%backtracking_attempts
    total_jac=total_jac+res%diagnostics%jacobian_builds
    total_lin=total_lin+res%diagnostics%linear_solves
    total_alt=total_alt+res%diagnostics%alternative_solver_calls
    if(res%status/=SW_SOLVE_CONVERGED)then
      write(*,'(*(g0))') 'F_PE_TIMEINT17_UNSPLIT_FAILURE|STEP=',step_index,'|STATUS=',res%status, &
           '|ORIGIN_ROUTE=',trim(origin_top%route),'|NL=',res%diagnostics%nonlinear_iterations
      call require(.false.,'endpoint solve failed')
    end if

    bc=soil_water_boundary_conditions_t()
    call top%evaluate(res%candidate_state%pressure_head(1),res%candidate_state%water_content(1), &
         res%candidate_state%ponding_depth,bc,end_top)
    call require(end_top%status>0,'endpoint top unavailable')

    theta_dot_p=(res%candidate_state%water_content-state%water_content)/dt
    pond_dot_p=(res%candidate_state%ponding_depth-pond0)/dt
    theta_tg=state%water_content+0.5_real64*dt*(theta_dot_n+theta_dot_p)
    pond_tg=pond0+0.5_real64*dt*(pond_dot_n+pond_dot_p)
    call require(all(theta_tg>tr) .and. all(theta_tg<ts),'TG theta outside retention domain')
    call require(pond_tg>=-1.0e-10_real64,'TG negative ponding')
    do i=1,numnod
      head_tg(i)=inverse_default_mvg(i,theta_tg(i))
    end do
    call bind_b110_default_mvg_provider(base_constitutive,hp,dt)
    call base_constitutive%evaluate(head_tg,check_theta,tmp_k,tmp_cap,tmp_dk)
    rt=maxval(abs(check_theta-theta_tg)); max_roundtrip=max(max_roundtrip,rt)
    call require(rt<=1.0e-12_real64,'TG roundtrip failed')

    state=res%candidate_state
    state%pressure_head=head_tg
    state%water_content=theta_tg
    state%ponding_depth=max(0.0_real64,pond_tg)
    final_route=end_top%route

    if(trim(origin_top%route)/=trim(end_top%route))then
      route_switches=route_switches+1
    else
      same_route_steps=same_route_steps+1
      runoff_tg=0.5_real64*(origin_top%runoff_depth+end_top%runoff_depth)
      storage1=sum(state%water_content*p%dz)+state%ponding_depth
      ledger=storage1-storage0-rain*dt+runoff_tg-res%bottom_flux*dt
      max_same_route_ledger=max(max_same_route_ledger,abs(ledger))
      cum_same_route_ledger=cum_same_route_ledger+ledger
    end if
    min_pond=min(min_pond,state%ponding_depth); max_pond=max(max_pond,state%ponding_depth)
  end subroutine

  pure real(real64) function inverse_default_mvg(node,theta) result(head)
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
      write(*,'(A,1X,A)')'F_PE_TIMEINT17_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine
end program test_fpe_timeint17_unsplit
