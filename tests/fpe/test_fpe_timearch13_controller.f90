program test_fpe_timearch13_controller
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, soil_water_boundary_conditions_t, &
       soil_water_top_boundary_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider, evaluate_b110_default_mvg_conductivity
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t, &
       b110_dynamic_top_boundary_result_t, evaluate_b110_dynamic_top_boundary, &
       B110_DYN_TOP_AVAILABLE, B110_DYN_TOP_REGIME_HEAD
  implicit none

  type(soil_water_parameter_set_t),target :: p
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t),target :: constitutive
  type(b110_source_sink_provider_t),target :: source_sink
  type(reference_richards_legacy_solver_t) :: solver
  type(soil_water_physical_state_t) :: state

  real(real64),allocatable,target :: qdra(:,:),qssdi(:),qrot(:)
  real(real64),allocatable :: c(:,:)
  character(len=32) :: case_id,mode
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,h0,rain,horizon
  real(real64) :: dtmin,dtmax,dt0,fact_inc,fact_dec,fact_fail,headtol
  integer :: numbit_crit,maxit,maxback
  real(real64), parameter :: PMAX=0.05_real64, RSRO=0.05_real64
  real(real64), parameter :: BALTOL_CONFIGURED=1.0e-12_real64, BALTOL_DEPTH=2.8e-16_real64
  real(real64), parameter :: RETRY_FLOOR=0.001_real64, R_TARGET=0.40_real64
  real(real64), parameter :: EPS_TIME=1.0e-13_real64

  real(real64) :: t,dt,preferred_dt,cumrun,maxledger,storage1
  real(real64) :: prev_top_head
  logical :: prev_top_available,retry_override
  integer :: attempts,accepted,rejected,growths,reductions,risk_count,safe_count
  integer :: total_nl,total_back,total_jac,total_lin,retry_work

  call get_command_argument(1,case_id)
  call get_command_argument(2,mode)
  call read_real(3,tr); call read_real(4,ts); call read_real(5,alpha); call read_real(6,nvg)
  call read_real(7,ksat); call read_real(8,lambda); call read_real(9,h0); call read_real(10,rain)
  call read_real(11,horizon); call read_real(12,dtmin); call read_real(13,dtmax); call read_real(14,dt0)
  call read_int(15,numbit_crit); call read_int(16,maxit); call read_int(17,maxback)
  call read_real(18,fact_inc); call read_real(19,fact_dec); call read_real(20,fact_fail); call read_real(21,headtol)

  call setup()
  call initialize_state(h0,state)

  t=0.0_real64
  if(trim(mode)=='REFERENCE')then
    dt=min(max(dt0,dtmin),dtmax)
    preferred_dt=dt
  else
    preferred_dt=0.005_real64
    dt=preferred_dt
  end if
  prev_top_available=.false.; prev_top_head=state%pressure_head(1)
  retry_override=.false.
  attempts=0;accepted=0;rejected=0;growths=0;reductions=0;risk_count=0;safe_count=0
  total_nl=0;total_back=0;total_jac=0;total_lin=0;retry_work=0
  cumrun=0.0_real64;maxledger=0.0_real64

  do while(t<horizon-EPS_TIME)
    call execute_attempt()
    call require(attempts<10000,'attempt limit')
  end do

  storage1=sum(state%water_content*p%dz)+state%ponding_depth
  write(*,'(*(g0))') 'F_PE_TIMEARCH13_RESULT|CASE=',trim(case_id),'|MODE=',trim(mode), &
    '|ATTEMPTS=',attempts,'|ACCEPTED=',accepted,'|REJECTED=',rejected, &
    '|GROWTHS=',growths,'|REDUCTIONS=',reductions,'|RISK=',risk_count,'|SAFE=',safe_count, &
    '|NL=',total_nl,'|BACK=',total_back,'|JAC=',total_jac,'|LIN=',total_lin,'|RETRY_WORK=',retry_work, &
    '|CUM_RUNOFF=',cumrun,'|TOP_H=',state%pressure_head(1),'|MID_H=',state%pressure_head((numnod+1)/2), &
    '|BOTTOM_H=',state%pressure_head(numnod),'|POND=',state%ponding_depth,'|STORAGE=',storage1,'|MAX_LEDGER=',maxledger
  write(*,'(A)') 'F_PE_TIMEARCH13=PASS'

contains

  subroutine read_real(i,x)
    integer,intent(in)::i
    real(real64),intent(out)::x
    character(len=64)::s
    call get_command_argument(i,s); read(s,*)x
  end subroutine

  subroutine read_int(i,x)
    integer,intent(in)::i
    integer,intent(out)::x
    character(len=64)::s
    call get_command_argument(i,s); read(s,*)x
  end subroutine

  subroutine setup()
    integer::k
    real(real64)::mm
    p%parameter_set_id=26092813_int64;p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),c(24,numnod))
    p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod);c=0.0_real64
    mm=1.0_real64-1.0_real64/nvg
    do k=1,numnod
      c(1,k)=tr;c(2,k)=ts;c(3,k)=ksat;c(4,k)=alpha;c(5,k)=lambda;c(6,k)=nvg;c(7,k)=mm
      c(8,k)=alpha;c(9,k)=0.0_real64;c(10,k)=ksat;c(11,k)=0.999_real64;c(12,k)=0.99_real64*ksat
      c(22,k)=-1.0e6_real64;c(23,k)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp,c)
    allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
    qdra=0.0_real64;qssdi=0.0_real64;qrot=0.0_real64
    call bind_b110_source_sink_provider(source_sink,qdra,qssdi,qrot)
  end subroutine

  subroutine initialize_state(h,s)
    real(real64),intent(in)::h
    type(soil_water_physical_state_t),intent(out)::s
    real(real64)::heads(numnod),water(numnod),kk(numnod),cap(numnod),dk(numnod)
    call bind_b110_default_mvg_provider(constitutive,hp,max(dt0,1.0e-6_real64))
    heads=h
    call constitutive%evaluate(heads,water,kk,cap,dk)
    s%active_nodes=numnod
    allocate(s%pressure_head(numnod),s%water_content(numnod))
    s%pressure_head=heads;s%water_content=water;s%ponding_depth=0.0_real64;s%groundwater_level=-999.0_real64
  end subroutine

  subroutine solve_one(s0,step_dt,s1,runoff,ledger,nl,back,jac,lin,ok)
    type(soil_water_physical_state_t),intent(in)::s0
    real(real64),intent(in)::step_dt
    type(soil_water_physical_state_t),intent(out)::s1
    real(real64),intent(out)::runoff,ledger
    integer,intent(out)::nl,back,jac,lin
    logical,intent(out)::ok
    type(b110_dynamic_top_boundary_solver_provider_t),target :: top
    type(soil_water_solve_request_t)::req
    type(soil_water_solve_result_t)::res
    type(reference_richards_legacy_workspace_t)::ws
    type(soil_water_boundary_conditions_t)::bc
    type(soil_water_top_boundary_result_t)::final_top
    real(real64)::fixed_k,storage0,storage_end,effective_baltol
    logical::k_ok

    runoff=0.0_real64;ledger=0.0_real64;nl=0;back=0;jac=0;lin=0;ok=.false.
    call bind_b110_default_mvg_provider(constitutive,hp,step_dt)
    call evaluate_b110_default_mvg_conductivity(hp,1,s0%pressure_head(1),fixed_k,k_ok)
    if(.not.k_ok)return
    call bind_b110_dynamic_top_boundary_solver_provider(top,p,hp,1,s0%ponding_depth,step_dt, &
      rain,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,PMAX,RSRO,1.0_real64,fixed_k)
    req=soil_water_solve_request_t();req%parameters=>p;req%base_state=s0;req%step_duration=step_dt
    req%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER;req%boundary%bottom_mode=2;req%boundary%bottom_flux=0.0_real64
    req%physical%macropore_active=.false.;req%numerical%max_iterations=maxit;req%numerical%max_backtracking=maxback
    req%numerical%conductivity_implicit_mode=0;req%numerical%conductivity_mean_method=1
    effective_baltol=max(BALTOL_CONFIGURED,BALTOL_DEPTH/step_dt)
    req%numerical%min_step_duration=max(dtmin,RETRY_FLOOR)
    req%numerical%compartment_balance_tolerance=effective_baltol
    req%numerical%total_balance_tolerance=effective_baltol
    req%numerical%head_abs_tolerance=headtol;req%numerical%head_rel_tolerance=headtol
    req%numerical%ponding_tolerance=BALTOL_CONFIGURED
    req%evaluation%constitutive=>constitutive;req%evaluation%source_sink=>source_sink;req%evaluation%dynamic_top_boundary=>top
    storage0=sum(s0%water_content*p%dz)+s0%ponding_depth
    call solver%solve(req,ws,res)
    nl=res%diagnostics%nonlinear_iterations;back=res%diagnostics%backtracking_attempts
    jac=res%diagnostics%jacobian_builds;lin=res%diagnostics%linear_solves
    if(res%status/=SW_SOLVE_CONVERGED)return
    bc=soil_water_boundary_conditions_t()
    call top%evaluate(res%candidate_state%pressure_head(1),res%candidate_state%water_content(1), &
      res%candidate_state%ponding_depth,bc,final_top)
    if(final_top%status<=0)return
    storage_end=sum(res%candidate_state%water_content*p%dz)+res%candidate_state%ponding_depth
    ledger=storage_end-storage0-rain*step_dt+final_top%runoff_depth-res%bottom_flux*step_dt
    if(.not.ieee_is_finite(ledger) .or. abs(ledger)>5.0e-8_real64)return
    runoff=final_top%runoff_depth;s1=res%candidate_state;ok=.true.
  end subroutine

  subroutine predict_risk(s0,step_dt,pred_head,use_linear,risk,ok)
    type(soil_water_physical_state_t),intent(in)::s0
    real(real64),intent(in)::step_dt,pred_head
    logical,intent(in)::use_linear
    logical,intent(out)::risk,ok
    type(b110_dynamic_top_boundary_request_t)::request
    type(b110_dynamic_top_boundary_result_t)::pred
    real(real64)::fixed_k,head_eval
    logical::k_ok
    risk=.true.;ok=.false.
    call evaluate_b110_default_mvg_conductivity(hp,1,s0%pressure_head(1),fixed_k,k_ok)
    if(.not.k_ok)return
    head_eval=s0%pressure_head(1)
    if(use_linear)head_eval=pred_head
    request%conductivity_mean_method=1
    request%pressure_head_top_cm=head_eval
    request%water_content_top=s0%water_content(1)
    request%candidate_ponding_depth_cm=s0%ponding_depth
    request%previous_ponding_depth_cm=s0%ponding_depth
    request%step_duration_day=step_dt
    request%precipitation_rate_cm_per_day=rain
    request%ponding_max_cm=PMAX
    request%runoff_resistance_day=RSRO
    request%runoff_exponent=1.0_real64
    request%fixed_top_node_conductivity_cm_per_day=fixed_k
    call evaluate_b110_dynamic_top_boundary(p,hp,request,pred)
    if(pred%status/=B110_DYN_TOP_AVAILABLE)return
    ok=.true.
    risk=pred%regime==B110_DYN_TOP_REGIME_HEAD .or. pred%runoff_potential
  end subroutine

  subroutine execute_attempt()
    type(soil_water_physical_state_t)::origin,candidate
    real(real64)::try_dt,runoff,ledger,rh,factor,raw_next,next_pref,pred_head
    real(real64)::old_pref,old_top,accepted_dt
    integer::nl,back,jac,lin,work
    logical::ok,risk,pred_ok,use_linear,use_half

    origin=state;old_top=origin%pressure_head(1);old_pref=preferred_dt
    try_dt=min(dt,horizon-t);attempts=attempts+1
    call solve_one(origin,try_dt,candidate,runoff,ledger,nl,back,jac,lin,ok)
    work=nl+back+jac+lin
    total_nl=total_nl+nl;total_back=total_back+back;total_jac=total_jac+jac;total_lin=total_lin+lin

    if(.not.ok)then
      rejected=rejected+1;retry_work=retry_work+work
      if(try_dt<=RETRY_FLOOR+EPS_TIME) call require(.false.,'nonconvergence at retry floor')
      dt=max(RETRY_FLOOR,0.5_real64*try_dt)
      retry_override=.true.;reductions=reductions+1
      return
    end if

    accepted_dt=try_dt
    cumrun=cumrun+runoff;maxledger=max(maxledger,abs(ledger))
    accepted=accepted+1;t=t+accepted_dt;state=candidate

    if(trim(mode)=='REFERENCE')then
      next_pref=accepted_dt
      if(nl<=numbit_crit)next_pref=min(next_pref*fact_inc,dtmax)
      if(nl>=maxit)next_pref=max(next_pref*fact_dec,dtmin)
      preferred_dt=next_pref;dt=preferred_dt
      prev_top_head=old_top;prev_top_available=.true.
      return
    end if

    rh=maxval(abs(candidate%pressure_head-origin%pressure_head)/max(10.0_real64,abs(origin%pressure_head)))
    factor=min(2.0_real64,max(0.5_real64,sqrt(R_TARGET/max(rh,1.0e-12_real64))))
    raw_next=old_pref*factor

    use_linear=index(trim(mode),'LINEAR_')==1
    use_half=index(trim(mode),'_HALF')>0
    pred_head=candidate%pressure_head(1)
    if(use_linear .and. prev_top_available)then
      pred_head=candidate%pressure_head(1)+(candidate%pressure_head(1)-old_top)/accepted_dt*raw_next
    end if

    call predict_risk(candidate,raw_next,pred_head,use_linear,risk,pred_ok)
    if(.not.pred_ok)risk=.true.

    if(risk)then
      risk_count=risk_count+1
      if(use_half)then
        next_pref=min(raw_next,max(RETRY_FLOOR,0.5_real64*accepted_dt))
      else
        next_pref=min(raw_next,accepted_dt)
      end if
    else
      safe_count=safe_count+1
      next_pref=raw_next
    end if

    if(next_pref>accepted_dt+EPS_TIME)growths=growths+1
    if(next_pref<accepted_dt-EPS_TIME)reductions=reductions+1
    preferred_dt=next_pref;dt=preferred_dt
    prev_top_head=old_top;prev_top_available=.true.
    retry_override=.false.
  end subroutine

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'F_PE_TIMEARCH13_FAIL',trim(msg);error stop 1
    end if
  end subroutine
end program test_fpe_timearch13_controller
