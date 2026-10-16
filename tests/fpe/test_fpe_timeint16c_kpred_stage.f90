program test_fpe_timeint16c_kpred_stage
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_fpe_timeint03_reference_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_fpe_timeint13_predicted_k_provider, only: fpe_timeint13_predicted_k_provider_t, &
       bind_fpe_timeint13_predicted_k_provider
  implicit none

  type(soil_water_parameter_set_t),target :: p
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t),target :: base_constitutive
  type(fpe_timeint13_predicted_k_provider_t),target :: predicted_constitutive
  type(b110_source_sink_provider_t),target :: source_sink
  type(fixed_flux_top_boundary_provider_t),target :: top
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: ws
  type(soil_water_physical_state_t) :: state

  real(real64),allocatable,target :: qdra(:,:),qssdi(:),qrot(:)
  real(real64),allocatable :: cof(:,:),tmp_theta(:),tmp_k(:),tmp_cap(:),tmp_dk(:)
  real(real64),allocatable :: theta_dot_n(:),theta_dot_p(:),theta_tilde(:),head_tilde(:),k_origin(:),k_tilde(:)
  real(real64),allocatable :: theta_tg(:),head_tg(:),check_theta(:)
  character(len=32) :: material_id
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,rain,dt,horizon
  integer :: steps,step,total_nl,total_back,total_jac,total_lin
  real(real64) :: maxledger,cumledger,max_roundtrip,max_k_shift,max_native_rate

  call get_command_argument(1,material_id)
  call read_real(2,tr); call read_real(3,ts); call read_real(4,alpha); call read_real(5,nvg)
  call read_real(6,ksat); call read_real(7,lambda); call read_real(8,rain); call read_real(9,dt)

  horizon=0.04_real64
  steps=nint(horizon/dt)
  call require(abs(real(steps,real64)*dt-horizon)<=1.0e-12_real64,'dt does not divide horizon')

  call setup()
  call initialize_state(-100.0_real64,state)
  allocate(tmp_theta(numnod),tmp_k(numnod),tmp_cap(numnod),tmp_dk(numnod))
  allocate(theta_dot_n(numnod),theta_dot_p(numnod),theta_tilde(numnod),head_tilde(numnod))
  allocate(k_origin(numnod),k_tilde(numnod),theta_tg(numnod),head_tg(numnod),check_theta(numnod))

  total_nl=0; total_back=0; total_jac=0; total_lin=0
  maxledger=0.0_real64; cumledger=0.0_real64; max_roundtrip=0.0_real64
  max_k_shift=0.0_real64; max_native_rate=0.0_real64

  do step=1,steps
    call advance_one()
  end do

  write(*,'(*(g0))') 'F_PE_TIMEINT16C_RESULT|MATERIAL=',trim(material_id),'|RAIN=',rain,'|DT=',dt, &
       '|STEPS=',steps,'|TOP_H=',state%pressure_head(1),'|MID_H=',state%pressure_head((numnod+1)/2), &
       '|BOTTOM_H=',state%pressure_head(numnod),'|TOP_THETA=',state%water_content(1), &
       '|MID_THETA=',state%water_content((numnod+1)/2),'|BOTTOM_THETA=',state%water_content(numnod), &
       '|STORAGE=',sum(state%water_content*p%dz)+state%ponding_depth, &
       '|NL=',total_nl,'|BACK=',total_back,'|JAC=',total_jac,'|LIN=',total_lin, &
       '|WORK=',total_nl+total_back+total_jac+total_lin,'|MAX_LEDGER=',maxledger, &
       '|CUM_LEDGER=',cumledger,'|MAX_ROUNDTRIP=',max_roundtrip,'|MAX_K_SHIFT=',max_k_shift, &
       '|MAX_NATIVE_RATE=',max_native_rate
  write(*,'(A)') 'F_PE_TIMEINT16C=PASS'

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
    p%parameter_set_id=26092916_int64; p%active_nodes=numnod
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

  subroutine physical_theta_derivative(s,theta_dot,kout)
    type(soil_water_physical_state_t),intent(in)::s
    real(real64),intent(out)::theta_dot(:),kout(:)
    real(real64)::th(numnod),cp(numnod),dk(numnod),g(numnod),km,grad
    integer::i

    call bind_b110_default_mvg_provider(base_constitutive,hp,dt)
    call base_constitutive%evaluate(s%pressure_head,th,kout,cp,dk)
    call require(maxval(abs(th-s%water_content))<=1.0e-12_real64,'origin theta/head inconsistency')

    g=0.0_real64
    if(numnod>1)then
      km=0.5_real64*(kout(1)+kout(2))
      grad=(s%pressure_head(1)-s%pressure_head(2))/p%node_distance(2)+1.0_real64
      g(1)=-rain+km*grad
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
      g(1)=-rain
    end if
    theta_dot=-g/p%dz
    call require(abs(sum(theta_dot*p%dz)-rain)<=5.0e-8_real64,'origin mass-rate identity failed')
  end subroutine

  subroutine advance_one()
    type(soil_water_solve_request_t)::req
    type(soil_water_solve_result_t)::res
    real(real64)::effective_baltol,storage0,storage1,ledger,rt
    integer::i

    call physical_theta_derivative(state,theta_dot_n,k_origin)

    theta_tilde=state%water_content+dt*theta_dot_n
    call require(all(theta_tilde>tr) .and. all(theta_tilde<ts),'predicted theta outside unsaturated retention domain')
    do i=1,numnod
      head_tilde(i)=inverse_default_mvg(i,theta_tilde(i))
    end do
    call bind_b110_default_mvg_provider(base_constitutive,hp,dt)
    call base_constitutive%evaluate(head_tilde,tmp_theta,k_tilde,tmp_cap,tmp_dk)
    call require(maxval(abs(tmp_theta-theta_tilde))<=1.0e-12_real64,'predicted-state retention roundtrip failed')
    call require(all(ieee_is_finite(k_tilde)) .and. all(k_tilde>0.0_real64),'invalid predicted K')
    max_k_shift=max(max_k_shift,maxval(abs(k_tilde-k_origin)))

    call bind_fpe_timeint13_predicted_k_provider(predicted_constitutive,base_constitutive,k_tilde)

    req=soil_water_solve_request_t()
    req%parameters=>p; req%base_state=state; req%step_duration=dt
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX; req%boundary%top_flux=-rain
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
    req%evaluation%top_boundary=>top

    storage0=sum(state%water_content*p%dz)+state%ponding_depth
    call solver%solve(req,ws,res)
    total_nl=total_nl+res%diagnostics%nonlinear_iterations
    total_back=total_back+res%diagnostics%backtracking_attempts
    total_jac=total_jac+res%diagnostics%jacobian_builds
    total_lin=total_lin+res%diagnostics%linear_solves

    call require(res%status==SW_SOLVE_CONVERGED,'predicted-K endpoint solve failed')
    call require(all(ieee_is_finite(res%candidate_state%pressure_head)),'nonfinite endpoint head')
    if(res%native_balance_rate_residual_available) &
         max_native_rate=max(max_native_rate,abs(res%native_balance_rate_residual_cm_per_day))

    theta_dot_p=(res%candidate_state%water_content-state%water_content)/dt
    theta_tg=state%water_content+0.5_real64*dt*(theta_dot_n+theta_dot_p)
    call require(all(theta_tg>tr) .and. all(theta_tg<ts),'TG theta outside unsaturated retention domain')

    do i=1,numnod
      head_tg(i)=inverse_default_mvg(i,theta_tg(i))
    end do
    call bind_b110_default_mvg_provider(base_constitutive,hp,dt)
    call base_constitutive%evaluate(head_tg,check_theta,tmp_k,tmp_cap,tmp_dk)
    rt=maxval(abs(check_theta-theta_tg))
    max_roundtrip=max(max_roundtrip,rt)
    call require(rt<=1.0e-12_real64,'TG retention roundtrip failed')

    state=res%candidate_state
    state%pressure_head=head_tg
    state%water_content=theta_tg

    storage1=sum(state%water_content*p%dz)+state%ponding_depth
    ledger=storage1-storage0-rain*dt
    maxledger=max(maxledger,abs(ledger))
    cumledger=cumledger+ledger
    call require(abs(ledger)<=5.0e-8_real64,'physical interval ledger failed')
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
      write(*,'(A,1X,A)')'F_PE_TIMEINT16C_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine
end program test_fpe_timeint16c_kpred_stage
