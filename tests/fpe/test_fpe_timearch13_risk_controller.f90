program test_fpe_timearch13_risk_controller
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
       b110_dynamic_top_boundary_result_t, evaluate_b110_dynamic_top_boundary, B110_DYN_TOP_AVAILABLE, &
       B110_DYN_TOP_REGIME_HEAD
  implicit none

  type(soil_water_parameter_set_t),target :: p
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t),target :: constitutive
  type(b110_source_sink_provider_t),target :: source_sink
  type(reference_richards_legacy_solver_t) :: solver
  type(soil_water_physical_state_t) :: state
  real(real64),allocatable,target :: qdra(:,:),qssdi(:),qrot(:)
  real(real64),allocatable :: c(:,:)

  character(len=32) :: case_id,policy_id,mode
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,h0,rain,horizon
  real(real64) :: retry_floor,legacy_dtmax,initial_dt,headtol
  real(real64) :: fact_inc,fact_dec,fact_fail
  integer :: numbit_crit,maxit,maxback

  real(real64), parameter :: PMAX=0.05_real64,RSRO=0.05_real64,RH_TARGET=0.40_real64
  real(real64), parameter :: BALTOL_CONFIGURED=1.0e-12_real64,BALTOL_DEPTH=2.8e-16_real64
  real(real64), parameter :: EPS_TIME=1.0e-13_real64

  integer :: attempts,accepted,rejected,growths,reductions,total_nl,total_back,total_jac,total_lin
  integer :: retry_nl,retry_back,retry_jac,retry_lin,risk_events
  real(real64) :: t,preferred_dt,attempt_dt,cumrun,maxledger,storage1

  call get_command_argument(1,case_id); call get_command_argument(2,policy_id)
  call read_real(3,tr); call read_real(4,ts); call read_real(5,alpha); call read_real(6,nvg)
  call read_real(7,ksat); call read_real(8,lambda); call read_real(9,h0); call read_real(10,rain)
  call read_real(11,horizon); call read_real(12,retry_floor); call read_real(13,legacy_dtmax)
  call read_real(14,initial_dt); call read_int(15,numbit_crit); call read_int(16,maxit); call read_int(17,maxback)
  call read_real(18,fact_inc); call read_real(19,fact_dec); call read_real(20,fact_fail); call read_real(21,headtol)
  call get_command_argument(22,mode)

  call require(retry_floor>0.0_real64 .and. legacy_dtmax>=retry_floor .and. initial_dt>0.0_real64,'invalid controls')
  call setup()
  call initialize_state(h0,state)

  t=0.0_real64
  preferred_dt=initial_dt
  attempt_dt=initial_dt
  attempts=0;accepted=0;rejected=0;growths=0;reductions=0
  total_nl=0;total_back=0;total_jac=0;total_lin=0
  retry_nl=0;retry_back=0;retry_jac=0;retry_lin=0;risk_events=0
  cumrun=0.0_real64;maxledger=0.0_real64

  do while(t<horizon-EPS_TIME)
    call execute_attempt()
    call require(attempts<10000,'attempt limit')
  end do

  storage1=sum(state%water_content*p%dz)+state%ponding_depth
  write(*,'(*(g0))') 'F_PE_TIMEARCH13_RESULT|CASE=',trim(case_id),'|POLICY=',trim(policy_id), &
    '|ATTEMPTS=',attempts,'|ACCEPTED=',accepted,'|REJECTED=',rejected,'|RISK_EVENTS=',risk_events, &
    '|GROWTHS=',growths,'|REDUCTIONS=',reductions,'|NL=',total_nl,'|BACK=',total_back,'|JAC=',total_jac,'|LIN=',total_lin, &
    '|RETRY_NL=',retry_nl,'|RETRY_BACK=',retry_back,'|RETRY_JAC=',retry_jac,'|RETRY_LIN=',retry_lin, &
    '|CUM_RUNOFF=',cumrun,'|TOP_H=',state%pressure_head(1),'|MID_H=',state%pressure_head((numnod+1)/2), &
    '|BOTTOM_H=',state%pressure_head(numnod),'|POND=',state%ponding_depth,'|STORAGE=',storage1,'|MAX_LEDGER=',maxledger
  write(*,'(A)') 'F_PE_TIMEARCH13_CASE=PASS'

contains

  subroutine read_real(i,x)
    integer,intent(in)::i; real(real64),intent(out)::x
    character(len=64)::s
    call get_command_argument(i,s); read(s,*)x
  end subroutine

  subroutine read_int(i,x)
    integer,intent(in)::i; integer,intent(out)::x
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
    call bind_b110_default_mvg_provider(constitutive,hp,initial_dt)
    heads=h
    call constitutive%evaluate(heads,water,kk,cap,dk)
    s%active_nodes=numnod
    allocate(s%pressure_head(numnod),s%water_content(numnod))
    s%pressure_head=heads;s%water_content=water;s%ponding_depth=0.0_real64;s%groundwater_level=-999.0_real64
  end subroutine

  subroutine boundary_risk(s,previous_head,accepted_dt,proposal_dt,risk,available)
    type(soil_water_physical_state_t),intent(in)::s
    real(real64),intent(in)::previous_head(:),accepted_dt,proposal_dt
    logical,intent(out)::risk,available
    type(b110_dynamic_top_boundary_request_t)::request
    type(b110_dynamic_top_boundary_result_t)::result
    real(real64)::fixed_k,predict_head
    logical::ok

    risk=.true.;available=.false.
    call evaluate_b110_default_mvg_conductivity(hp,1,s%pressure_head(1),fixed_k,ok)
    if(.not.ok)return

    if(index(trim(mode),'LINEAR')==1)then
      predict_head=s%pressure_head(1)+(s%pressure_head(1)-previous_head(1))/accepted_dt*proposal_dt
    else
      predict_head=s%pressure_head(1)
    end if
    if(.not.ieee_is_finite(predict_head))return

    request%conductivity_mean_method=1
    request%pressure_head_top_cm=predict_head
    request%water_content_top=s%water_content(1)
    request%candidate_ponding_depth_cm=s%ponding_depth
    request%previous_ponding_depth_cm=s%ponding_depth
    request%step_duration_day=proposal_dt
    request%precipitation_rate_cm_per_day=rain
    request%irrigation_rate_cm_per_day=0.0_real64
    request%snowmelt_rate_cm_per_day=0.0_real64
    request%runon_rate_cm_per_day=0.0_real64
    request%potential_bare_soil_evaporation_cm_per_day=0.0_real64
    request%potential_pond_evaporation_cm_per_day=0.0_real64
    request%ponding_max_cm=PMAX
    request%runoff_resistance_day=RSRO
    request%runoff_exponent=1.0_real64
    request%fixed_top_node_conductivity_cm_per_day=fixed_k
    call evaluate_b110_dynamic_top_boundary(p,hp,request,result)
    if(result%status/=B110_DYN_TOP_AVAILABLE)return

    available=.true.
    risk=result%regime==B110_DYN_TOP_REGIME_HEAD .or. result%runoff_potential
  end subroutine

  subroutine execute_attempt()
    type(b110_dynamic_top_boundary_solver_provider_t),target :: top
    type(soil_water_solve_request_t)::req
    type(soil_water_solve_result_t)::res
    type(reference_richards_legacy_workspace_t)::ws
    type(soil_water_boundary_conditions_t)::bc
    type(soil_water_top_boundary_result_t)::final_top
    real(real64),allocatable :: old_head(:)
    real(real64)::fixed_k,try_dt,ledger,new_pref,effective_baltol,storage0,storage_end
    real(real64)::factor,rh,raw_proposal
    integer::nl0,back0,jac0,lin0
    logical::ok,risk,risk_available

    try_dt=min(attempt_dt,horizon-t)
    attempts=attempts+1
    allocate(old_head(state%active_nodes));old_head=state%pressure_head

    call bind_b110_default_mvg_provider(constitutive,hp,try_dt)
    call evaluate_b110_default_mvg_conductivity(hp,1,state%pressure_head(1),fixed_k,ok)
    call require(ok,'fixed conductivity')
    call bind_b110_dynamic_top_boundary_solver_provider(top,p,hp,1,state%ponding_depth,try_dt, &
      rain,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,PMAX,RSRO,1.0_real64,fixed_k)

    req=soil_water_solve_request_t()
    req%parameters=>p;req%base_state=state;req%step_duration=try_dt
    req%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER;req%boundary%bottom_mode=2;req%boundary%bottom_flux=0.0_real64
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=maxit;req%numerical%max_backtracking=maxback
    req%numerical%conductivity_implicit_mode=0;req%numerical%conductivity_mean_method=1
    effective_baltol=max(BALTOL_CONFIGURED,BALTOL_DEPTH/try_dt)
    req%numerical%min_step_duration=retry_floor
    req%numerical%compartment_balance_tolerance=effective_baltol
    req%numerical%total_balance_tolerance=effective_baltol
    req%numerical%head_abs_tolerance=headtol;req%numerical%head_rel_tolerance=headtol
    req%numerical%ponding_tolerance=BALTOL_CONFIGURED
    req%evaluation%constitutive=>constitutive;req%evaluation%source_sink=>source_sink;req%evaluation%dynamic_top_boundary=>top

    storage0=sum(state%water_content*p%dz)+state%ponding_depth
    call solver%solve(req,ws,res)
    nl0=res%diagnostics%nonlinear_iterations;back0=res%diagnostics%backtracking_attempts
    jac0=res%diagnostics%jacobian_builds;lin0=res%diagnostics%linear_solves
    total_nl=total_nl+nl0;total_back=total_back+back0;total_jac=total_jac+jac0;total_lin=total_lin+lin0

    if(res%status/=SW_SOLVE_CONVERGED)then
      rejected=rejected+1
      retry_nl=retry_nl+nl0;retry_back=retry_back+back0;retry_jac=retry_jac+jac0;retry_lin=retry_lin+lin0
      new_pref=max(retry_floor,try_dt/fact_fail)
      call require(new_pref<try_dt-EPS_TIME,'nonconvergence at retry floor')
      if(new_pref<attempt_dt-EPS_TIME)reductions=reductions+1
      attempt_dt=new_pref
      return
    end if

    bc=soil_water_boundary_conditions_t()
    call top%evaluate(res%candidate_state%pressure_head(1),res%candidate_state%water_content(1), &
      res%candidate_state%ponding_depth,bc,final_top)
    call require(final_top%status>0,'final top')

    storage_end=sum(res%candidate_state%water_content*p%dz)+res%candidate_state%ponding_depth
    ledger=storage_end-storage0-rain*try_dt+final_top%runoff_depth-res%bottom_flux*try_dt
    call require(ieee_is_finite(ledger).and.abs(ledger)<=5.0e-8_real64,'ledger')

    accepted=accepted+1
    cumrun=cumrun+final_top%runoff_depth
    maxledger=max(maxledger,abs(ledger))
    t=t+try_dt
    state=res%candidate_state

    if(trim(mode)=='LEGACY')then
      new_pref=try_dt
      if(nl0<=numbit_crit)new_pref=min(new_pref*fact_inc,legacy_dtmax)
      if(nl0>=maxit)new_pref=max(new_pref*fact_dec,retry_floor)
    else
      rh=maxval(abs(state%pressure_head-old_head)/max(10.0_real64,abs(old_head)))
      factor=min(2.0_real64,max(0.5_real64,sqrt(RH_TARGET/max(rh,1.0e-12_real64))))
      raw_proposal=max(retry_floor,preferred_dt*factor)
      call boundary_risk(state,old_head,try_dt,raw_proposal,risk,risk_available)
      if(.not.risk_available)risk=.true.
      if(risk)then
        risk_events=risk_events+1
        if(index(trim(mode),'_HALF')>0)then
          new_pref=min(raw_proposal,max(retry_floor,0.5_real64*try_dt))
        else
          new_pref=min(raw_proposal,try_dt)
        end if
      else
        new_pref=raw_proposal
      end if
    end if

    if(new_pref>preferred_dt+EPS_TIME)growths=growths+1
    if(new_pref<preferred_dt-EPS_TIME)reductions=reductions+1
    preferred_dt=new_pref
    attempt_dt=new_pref
  end subroutine

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'F_PE_TIMEARCH13_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine
end program test_fpe_timearch13_risk_controller
