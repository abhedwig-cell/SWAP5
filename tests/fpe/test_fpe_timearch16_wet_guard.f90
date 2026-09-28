program test_fpe_timearch16_wet_guard
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, soil_water_boundary_conditions_t, &
       soil_water_top_boundary_result_t, SW_SOLVE_CONVERGED, SW_TOP_BOUNDARY_REGIME_FLUX, SW_TOP_BOUNDARY_REGIME_HEAD
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider, evaluate_b110_default_mvg_conductivity
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
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
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,h0,rain,horizon,dtmin,dtmax,dt0
  real(real64) :: fact_inc,fact_dec,fact_fail,headtol,eh_tol,epond_tol,erun_tol
  integer :: numbit_crit,maxit,maxback

  real(real64), parameter :: PMAX=0.05_real64, RSRO=0.05_real64
  real(real64), parameter :: BALTOL_CONFIGURED=1.0e-12_real64, BALTOL_DEPTH=2.8e-16_real64
  real(real64), parameter :: RH_TARGET=0.40_real64
  real(real64), parameter :: EPS_TIME=1.0e-13_real64

  integer :: attempts,accepted,rejected,growths,reductions,transition_refines,last_mode,fallback_entries,refine_count
  integer :: total_nl,total_back,total_jac,total_lin,retry_work_index,transition_discard_work
  logical :: auto_active
  real(real64) :: t,preferred_dt,attempt_dt,cumrun,maxledger,storage1,guard_threshold

  call get_command_argument(1,case_id)
  call get_command_argument(2,policy_id)
  call read_real(3,tr); call read_real(4,ts); call read_real(5,alpha); call read_real(6,nvg)
  call read_real(7,ksat); call read_real(8,lambda); call read_real(9,h0); call read_real(10,rain)
  call read_real(11,horizon); call read_real(12,dtmin); call read_real(13,dtmax); call read_real(14,dt0)
  call read_int(15,numbit_crit); call read_int(16,maxit); call read_int(17,maxback)
  call read_real(18,fact_inc); call read_real(19,fact_dec); call read_real(20,fact_fail); call read_real(21,headtol)
  call get_command_argument(22,mode)
  call read_real(23,eh_tol); call read_real(24,epond_tol); call read_real(25,erun_tol)

  call require(dtmin>0.0_real64 .and. dtmax>=dtmin .and. dt0>0.0_real64,'invalid timestep policy')
  call setup()
  call initialize_state(h0,state)

  t=0.0_real64; preferred_dt=dt0; attempt_dt=dt0
  attempts=0; accepted=0; rejected=0; growths=0; reductions=0
  transition_refines=0; last_mode=0; fallback_entries=0; auto_active=.true.
  refine_count=4
  guard_threshold=-5.0_real64
  if(index(trim(mode),'M20')>0) guard_threshold=-20.0_real64
  if(index(trim(mode),'M10')>0) guard_threshold=-10.0_real64
  total_nl=0; total_back=0; total_jac=0; total_lin=0; retry_work_index=0; transition_discard_work=0
  cumrun=0.0_real64; maxledger=0.0_real64

  do while(t<horizon-EPS_TIME)
    call execute_interval()
    call require(attempts<10000,'attempt limit')
  end do

  storage1=sum(state%water_content*p%dz)+state%ponding_depth
  write(*,'(*(g0))') 'F_PE_TIMEARCH16_RESULT|CASE=',trim(case_id),'|POLICY=',trim(policy_id), &
    '|ATTEMPTS=',attempts,'|ACCEPTED=',accepted,'|REJECTED=',rejected, &
    '|TRANSITION_REFINES=',transition_refines,'|FALLBACK_ENTRIES=',fallback_entries,'|RETRY_WORK=',retry_work_index, &
    '|TRANSITION_DISCARD_WORK=',transition_discard_work, &
    '|GROWTHS=',growths,'|REDUCTIONS=',reductions,'|NL=',total_nl,'|BACK=',total_back, &
    '|JAC=',total_jac,'|LIN=',total_lin,'|CUM_RUNOFF=',cumrun, &
    '|TOP_H=',state%pressure_head(1),'|MID_H=',state%pressure_head((numnod+1)/2), &
    '|BOTTOM_H=',state%pressure_head(numnod),'|POND=',state%ponding_depth, &
    '|STORAGE=',storage1,'|MAX_LEDGER=',maxledger
  write(*,'(A)') 'F_PE_TIMEARCH16_CASE=PASS'

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
    p%parameter_set_id=26092831_int64; p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),c(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod); c=0.0_real64
    mm=1.0_real64-1.0_real64/nvg
    do k=1,numnod
      c(1,k)=tr; c(2,k)=ts; c(3,k)=ksat; c(4,k)=alpha; c(5,k)=lambda; c(6,k)=nvg; c(7,k)=mm
      c(8,k)=alpha; c(9,k)=0.0_real64; c(10,k)=ksat; c(11,k)=0.999_real64; c(12,k)=0.99_real64*ksat
      c(22,k)=-1.0e6_real64; c(23,k)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp,c)
    allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
    qdra=0.0_real64; qssdi=0.0_real64; qrot=0.0_real64
    call bind_b110_source_sink_provider(source_sink,qdra,qssdi,qrot)
  end subroutine

  subroutine initialize_state(h,s)
    real(real64),intent(in)::h
    type(soil_water_physical_state_t),intent(out)::s
    real(real64)::heads(numnod),water(numnod),kk(numnod),cap(numnod),dk(numnod)
    call bind_b110_default_mvg_provider(constitutive,hp,dt0)
    heads=h
    call constitutive%evaluate(heads,water,kk,cap,dk)
    s%active_nodes=numnod
    allocate(s%pressure_head(numnod),s%water_content(numnod))
    s%pressure_head=heads; s%water_content=water
    s%ponding_depth=0.0_real64; s%groundwater_level=-999.0_real64
  end subroutine

  subroutine solve_one(s0,step_dt,s1,runoff,ledger,nl,back,jac,lin,surface_mode,ok)
    type(soil_water_physical_state_t),intent(in)::s0
    real(real64),intent(in)::step_dt
    type(soil_water_physical_state_t),intent(out)::s1
    real(real64),intent(out)::runoff,ledger
    integer,intent(out)::nl,back,jac,lin,surface_mode
    logical,intent(out)::ok

    type(b110_dynamic_top_boundary_solver_provider_t),target :: top
    type(soil_water_solve_request_t)::req
    type(soil_water_solve_result_t)::res
    type(reference_richards_legacy_workspace_t)::ws
    type(soil_water_boundary_conditions_t)::bc
    type(soil_water_top_boundary_result_t)::final_top
    real(real64)::fixed_k,storage0,storage_end,effective_baltol
    logical::k_ok

    runoff=0.0_real64; ledger=0.0_real64
    nl=0; back=0; jac=0; lin=0; surface_mode=0; ok=.false.

    call bind_b110_default_mvg_provider(constitutive,hp,step_dt)
    call evaluate_b110_default_mvg_conductivity(hp,1,s0%pressure_head(1),fixed_k,k_ok)
    if(.not.k_ok)return
    call bind_b110_dynamic_top_boundary_solver_provider(top,p,hp,1,s0%ponding_depth,step_dt, &
      rain,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,PMAX,RSRO,1.0_real64,fixed_k)

    req=soil_water_solve_request_t()
    req%parameters=>p; req%base_state=s0; req%step_duration=step_dt
    req%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER
    req%boundary%bottom_mode=2; req%boundary%bottom_flux=0.0_real64
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=maxit; req%numerical%max_backtracking=maxback
    req%numerical%conductivity_implicit_mode=0; req%numerical%conductivity_mean_method=1
    effective_baltol=max(BALTOL_CONFIGURED,BALTOL_DEPTH/step_dt)
    req%numerical%min_step_duration=dtmin
    req%numerical%compartment_balance_tolerance=effective_baltol
    req%numerical%total_balance_tolerance=effective_baltol
    req%numerical%head_abs_tolerance=headtol; req%numerical%head_rel_tolerance=headtol
    req%numerical%ponding_tolerance=BALTOL_CONFIGURED
    req%evaluation%constitutive=>constitutive; req%evaluation%source_sink=>source_sink
    req%evaluation%dynamic_top_boundary=>top

    storage0=sum(s0%water_content*p%dz)+s0%ponding_depth
    call solver%solve(req,ws,res)
    nl=res%diagnostics%nonlinear_iterations
    back=res%diagnostics%backtracking_attempts
    jac=res%diagnostics%jacobian_builds
    lin=res%diagnostics%linear_solves
    if(res%status/=SW_SOLVE_CONVERGED)return

    bc=soil_water_boundary_conditions_t()
    call top%evaluate(res%candidate_state%pressure_head(1),res%candidate_state%water_content(1), &
      res%candidate_state%ponding_depth,bc,final_top)
    if(final_top%status<=0)return

    storage_end=sum(res%candidate_state%water_content*p%dz)+res%candidate_state%ponding_depth
    ledger=storage_end-storage0-rain*step_dt+final_top%runoff_depth-res%bottom_flux*step_dt
    if(.not.ieee_is_finite(ledger) .or. abs(ledger)>5.0e-8_real64)return

    runoff=final_top%runoff_depth
    if(final_top%regime==SW_TOP_BOUNDARY_REGIME_FLUX)then
      surface_mode=1
    else if(final_top%regime==SW_TOP_BOUNDARY_REGIME_HEAD)then
      if(final_top%runoff_depth>1.0e-12_real64)then
        surface_mode=3
      else
        surface_mode=2
      end if
    else
      return
    end if
    s1=res%candidate_state
    ok=.true.
  end subroutine

  subroutine add_work(nl,back,jac,lin)
    integer,intent(in)::nl,back,jac,lin
    total_nl=total_nl+nl; total_back=total_back+back
    total_jac=total_jac+jac; total_lin=total_lin+lin
  end subroutine

  subroutine execute_interval()
    type(soil_water_physical_state_t)::origin,full_state,sub_state,next_state,chosen
    real(real64)::try_dt,sub_dt,run_full,run_sub,led_full,led_sub
    real(real64)::rh,factor,new_pref,total_run
    integer::nl,back,jac,lin,full_mode,sub_mode,full_work,w,i,last_nl
    logical::ok_full,ok_sub,needs_transition

    origin=state
    try_dt=min(attempt_dt,horizon-t)
    attempts=attempts+1

    call solve_one(origin,try_dt,full_state,run_full,led_full,nl,back,jac,lin,full_mode,ok_full)
    full_work=nl+back+jac+lin
    call add_work(nl,back,jac,lin)

    if(trim(mode)=='REFERENCE')then
      if(.not.ok_full)then
        rejected=rejected+1
        retry_work_index=retry_work_index+full_work
        new_pref=attempt_dt
        if(new_pref>fact_fail*dtmin)then
          new_pref=new_pref/fact_fail
        else
          new_pref=dtmin
        end if
        call require(new_pref<attempt_dt-EPS_TIME,'reference nonconvergence at dtmin')
        reductions=reductions+1
        preferred_dt=new_pref;attempt_dt=new_pref
        return
      end if
      chosen=full_state
      cumrun=cumrun+run_full;maxledger=max(maxledger,abs(led_full))
      accepted=accepted+1;t=t+try_dt;state=chosen;last_mode=full_mode
      new_pref=try_dt
      if(nl<=numbit_crit)new_pref=min(new_pref*fact_inc,dtmax)
      if(nl>=maxit)new_pref=max(new_pref*fact_dec,dtmin)
      if(new_pref>preferred_dt+EPS_TIME)growths=growths+1
      if(new_pref<preferred_dt-EPS_TIME)reductions=reductions+1
      preferred_dt=new_pref;attempt_dt=new_pref
      return
    end if

    if(.not.auto_active)then
      if(.not.ok_full)then
        rejected=rejected+1
        retry_work_index=retry_work_index+full_work
        new_pref=max(dtmin,try_dt/fact_fail)
        call require(new_pref<try_dt-EPS_TIME,'legacy fallback nonconvergence at floor')
        reductions=reductions+1
        preferred_dt=new_pref;attempt_dt=new_pref
        return
      end if
      chosen=full_state
      cumrun=cumrun+run_full;maxledger=max(maxledger,abs(led_full))
      accepted=accepted+1;t=t+try_dt;state=chosen;last_mode=full_mode
      new_pref=try_dt
      if(nl<=numbit_crit)new_pref=min(new_pref*fact_inc,dtmax)
      if(nl>=maxit)new_pref=max(new_pref*fact_dec,dtmin)
      if(new_pref>preferred_dt+EPS_TIME)growths=growths+1
      if(new_pref<preferred_dt-EPS_TIME)reductions=reductions+1
      preferred_dt=new_pref;attempt_dt=new_pref
      return
    end if

    if(.not.ok_full)then
      rejected=rejected+1
      retry_work_index=retry_work_index+full_work
      auto_active=.false.;fallback_entries=fallback_entries+1
      new_pref=min(dtmax,max(dtmin,0.5_real64*try_dt))
      call require(new_pref<try_dt-EPS_TIME,'auto failure fallback did not reduce')
      reductions=reductions+1
      preferred_dt=new_pref;attempt_dt=new_pref
      return
    end if

    if(last_mode==0)then
      needs_transition=.false.
    else
      needs_transition=last_mode==1 .and. full_mode/=1
    end if

    if(needs_transition)then
      transition_refines=transition_refines+1
      transition_discard_work=transition_discard_work+full_work
      sub_dt=try_dt/real(refine_count,real64)
      sub_state=origin
      total_run=0.0_real64
      last_nl=0
      do i=1,refine_count
        call solve_one(sub_state,sub_dt,next_state,run_sub,led_sub,nl,back,jac,lin,sub_mode,ok_sub)
        w=nl+back+jac+lin
        call add_work(nl,back,jac,lin)
        if(.not.ok_sub)then
          rejected=rejected+1
          retry_work_index=retry_work_index+w
          auto_active=.false.;fallback_entries=fallback_entries+1
          new_pref=min(dtmax,max(dtmin,0.5_real64*try_dt))
          call require(new_pref<try_dt-EPS_TIME,'transition refinement fallback did not reduce')
          reductions=reductions+1
          preferred_dt=new_pref;attempt_dt=new_pref
          return
        end if
        total_run=total_run+run_sub
        maxledger=max(maxledger,abs(led_sub))
        sub_state=next_state
        last_mode=sub_mode
        last_nl=nl
      end do
      chosen=sub_state
      cumrun=cumrun+total_run
      accepted=accepted+1;t=t+try_dt;state=chosen
      auto_active=.false.;fallback_entries=fallback_entries+1
      new_pref=sub_dt
      if(last_nl<=numbit_crit)new_pref=min(new_pref*fact_inc,dtmax)
      if(last_nl>=maxit)new_pref=max(new_pref*fact_dec,dtmin)
      if(new_pref>preferred_dt+EPS_TIME)growths=growths+1
      if(new_pref<preferred_dt-EPS_TIME)reductions=reductions+1
      preferred_dt=new_pref;attempt_dt=new_pref
      return
    end if

    chosen=full_state
    cumrun=cumrun+run_full;maxledger=max(maxledger,abs(led_full))
    accepted=accepted+1;t=t+try_dt;state=chosen;last_mode=full_mode

    if(full_mode/=1 .or. chosen%pressure_head(1)>guard_threshold)then
      auto_active=.false.;fallback_entries=fallback_entries+1
      new_pref=try_dt
      if(nl<=numbit_crit)new_pref=min(new_pref*fact_inc,dtmax)
      if(nl>=maxit)new_pref=max(new_pref*fact_dec,dtmin)
    else
      rh=maxval(abs(chosen%pressure_head-origin%pressure_head)/max(10.0_real64,abs(origin%pressure_head)))
      factor=min(2.0_real64,max(0.5_real64,sqrt(RH_TARGET/max(rh,1.0e-12_real64))))
      new_pref=max(dtmin,preferred_dt*factor)
    end if

    if(new_pref>preferred_dt+EPS_TIME)growths=growths+1
    if(new_pref<preferred_dt-EPS_TIME)reductions=reductions+1
    preferred_dt=new_pref;attempt_dt=new_pref
  end subroutine

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'F_PE_TIMEARCH16_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine
end program test_fpe_timearch16_wet_guard
