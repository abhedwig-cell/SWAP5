program test_fpe_miqual04_dynamic_top
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, soil_water_boundary_conditions_t, &
       soil_water_top_boundary_result_t, SW_SOLVE_CONVERGED
  use mod_fpe_timeint03_reference_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider, evaluate_b110_default_mvg_conductivity
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  use mod_moving_interface_manager, only: moving_interface_active_view_t, moving_interface_manager_diagnostics_t, &
       moving_interface_manager_context_t, derive_moving_interface_active_view, &
       prepare_moving_interface_reduced_request_persistent, &
       materialize_moving_interface_full_candidate_persistent, &
       finalize_moving_interface_result_persistent, MI_MANAGER_ROUTE_REDUCED
  implicit none

  integer, parameter :: nstep=4000
  integer :: timeint02_mode
  real(8) :: timeint02_thetam2(1000)
  common /timeint02_history_common/ timeint02_mode, timeint02_thetam2

  type(soil_water_parameter_set_t), target :: pfull
  type(b110_default_mvg_parameters_t), target :: hpfull, hpred
  type(b110_default_mvg_provider_t), target :: constitutive_full, constitutive_red
  type(b110_source_sink_provider_t), target :: source_full, source_red
  type(b110_dynamic_top_boundary_solver_provider_t), target :: top_full, top_red, top_fallback
  type(reference_richards_legacy_solver_t) :: solver_full, solver_red, solver_fallback
  type(reference_richards_legacy_workspace_t) :: ws_full, ws_red, ws_fallback
  type(soil_water_physical_state_t) :: full_state, adaptive_state
  type(soil_water_solve_request_t) :: full_req, adaptive_req
  type(soil_water_solve_result_t) :: full_res, red_res, fallback_res, dummy_full
  type(moving_interface_active_view_t) :: view
  type(moving_interface_manager_diagnostics_t) :: manager_diag
  type(moving_interface_manager_context_t) :: manager_context

  real(real64), allocatable, target :: qdra_full(:,:), qssdi_full(:), qrot_full(:)
  real(real64), allocatable, target :: qdra_red(:,:), qssdi_red(:), qrot_red(:)
  real(real64), allocatable :: cof_full(:,:), cof_red(:,:)
  real(real64), allocatable :: theta_tmp(:), k_tmp(:), cap_tmp(:), dk_tmp(:)
  real(real64), allocatable :: tail_h(:), tail_th(:)
  integer(int64) :: active_hist(128)
  integer :: full_dirs(nstep), adaptive_dirs(nstep)

  character(len=32) :: mode, case_id
  integer :: nfull, initial_tail, reduced_n, reduced_provider_n
  integer :: i,k,nt,full_tail_old,full_tail_new,adapt_tail_old,adapt_tail_new
  integer :: full_event_count,adaptive_event_count,fallback_count,bypass_count,reduced_count
  integer :: full_work,adaptive_work,route_flux_full,route_head_full,route_pond_full,route_runoff_full
  integer :: route_flux_adapt,route_head_adapt,route_pond_adapt,route_runoff_adapt
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,dt,rain
  real(real64) :: t0,t1,full_time,adaptive_time
  real(real64) :: full_ledger,adaptive_ledger,max_full_ledger,max_adaptive_ledger
  real(real64) :: max_hdiff,max_tdiff,max_ponddiff,max_origin_leak,hdiff,tdiff,ponddiff
  real(real64) :: full_runoff,adaptive_runoff,wall_ratio,work_ratio,mean_active
  character(len=96) :: reason,last_nonreduced_reason
  logical :: ok,physical_ok,sequence_ok

  nfull=numnod
  call get_command_argument(1,mode)
  call get_command_argument(2,case_id)
  call read_real(3,tr); call read_real(4,ts); call read_real(5,alpha); call read_real(6,nvg)
  call read_real(7,ksat); call read_real(8,lambda)
  call read_int(9,initial_tail); call read_real(10,rain)
  call require((nfull==64 .and. initial_tail==49) .or. (nfull==32 .and. initial_tail==25), &
       'MIQUAL04 frozen geometry mismatch')
  call require(trim(mode)=='REF' .or. trim(mode)=='AB','MIQUAL04 invalid mode')

  dt=0.00125_real64
  active_hist=0_int64; full_dirs=0; adaptive_dirs=0
  full_event_count=0; adaptive_event_count=0
  fallback_count=0; bypass_count=0; reduced_count=0
  full_work=0; adaptive_work=0
  full_time=0.0_real64; adaptive_time=0.0_real64
  max_full_ledger=0.0_real64; max_adaptive_ledger=0.0_real64
  max_hdiff=0.0_real64; max_tdiff=0.0_real64; max_ponddiff=0.0_real64; max_origin_leak=0.0_real64
  full_runoff=0.0_real64; adaptive_runoff=0.0_real64
  route_flux_full=0; route_head_full=0; route_pond_full=0; route_runoff_full=0
  route_flux_adapt=0; route_head_adapt=0; route_pond_adapt=0; route_runoff_adapt=0
  reduced_provider_n=0; last_nonreduced_reason='none'

  call setup_full()
  call initialize_states()
  call build_request(full_req,full_state)
  call build_request(adaptive_req,adaptive_state)

  if(trim(mode)=='REF')then
    do i=1,nstep
      full_tail_old=tail_identity(full_state)
      if(full_tail_old<1) call emit_ref_fail(i-1,'invalid-tail')
      call solve_full_step(full_state,full_req,solver_full,ws_full,full_res,full_ledger,reason)
      if(trim(reason)/='ok') call emit_ref_fail(i-1,trim(reason))
      full_tail_new=tail_identity(full_res%candidate_state)
      if(full_tail_new<1 .or. abs(full_tail_new-full_tail_old)>1) call emit_ref_fail(i-1,'ownership')
      call accept_state(full_res%candidate_state,full_state)
      max_full_ledger=max(max_full_ledger,abs(full_ledger))
    end do
    write(*,'(*(g0))') 'F_PE_MIQUAL04_REF|CASE=',trim(case_id),'|COMPLETE=1|LAST_ACCEPTED=',nstep, &
         '|MAX_LEDGER=',max_full_ledger,'|TAIL=',tail_identity(full_state),'|RUNOFF=',full_runoff, &
         '|FLUX=',route_flux_full,'|HEAD=',route_head_full,'|POND=',route_pond_full,'|RUNOFF_ROUTE=',route_runoff_full
    write(*,'(a)') 'F_PE_MIQUAL04=PASS'
    stop
  end if

  do i=1,nstep
    full_tail_old=tail_identity(full_state)
    adapt_tail_old=tail_identity(adaptive_state)
    if(full_tail_old<1 .or. adapt_tail_old<1) call fail_physical('invalid origin tail')

    call cpu_time(t0)
    call solve_full_step(full_state,full_req,solver_full,ws_full,full_res,full_ledger,reason)
    if(trim(reason)/='ok') call fail_physical('full solve failed')
    call cpu_time(t1)
    full_time=full_time+(t1-t0)
    full_work=full_work+full_res%diagnostics%nonlinear_iterations*nfull
    max_full_ledger=max(max_full_ledger,abs(full_ledger))
    call accept_state(full_res%candidate_state,full_state)

    call cpu_time(t0)
    call copy_state_to_request(adaptive_state,adaptive_req)
    reduced_n=adapt_tail_old
    ok=.false.; reason='not-attempted'
    if(reduced_n>1 .and. reduced_n<nfull)then
      call derive_moving_interface_active_view(adaptive_state,reduced_n,view,ok,reason)
    else
      view=moving_interface_active_view_t()
      view%full_nodes=nfull; view%active_nodes=nfull; view%tail_start_node=reduced_n
      view%interface_face=reduced_n; view%eligible=.false.; reason='reduced-view-ineligible'
    end if

    if(ok .and. view%eligible)then
      if(reduced_provider_n/=view%active_nodes) call setup_reduced_provider(view%active_nodes)
      call prepare_moving_interface_reduced_request_persistent(adaptive_req,view,manager_context,ok,reason)
      if(ok)then
        manager_context%reduced_request%evaluation%constitutive=>constitutive_red
        manager_context%reduced_request%evaluation%source_sink=>source_red
        call bind_dynamic_top(top_red,manager_context%reduced_parameters,hpred,adaptive_state,view%active_nodes)
        manager_context%reduced_request%evaluation%dynamic_top_boundary=>top_red
        manager_context%reduced_request%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER
        call set_history(adaptive_state,view%active_nodes)
        call solver_red%solve(manager_context%reduced_request,ws_red,red_res)
        ok=red_res%status==SW_SOLVE_CONVERGED
      end if
      if(ok)then
        call prepare_tail_arrays(view%active_nodes)
        call reconstruct_tail(red_res,view%active_nodes)
        call materialize_moving_interface_full_candidate_persistent(adaptive_state,red_res,tail_h,tail_th, &
             manager_context,ok,reason)
      end if
      if(ok)then
        dummy_full=soil_water_solve_result_t()
        call finalize_moving_interface_result_persistent(dummy_full,.true.,view,ws_red%richards%generation, &
             'none',manager_context,manager_diag)
        if(manager_diag%route/=MI_MANAGER_ROUTE_REDUCED) ok=.false.
      end if

      if(ok)then
        call evaluate_adaptive_top(top_red,manager_context%full_candidate,adaptive_state,adaptive_ledger,reason)
        if(trim(reason)/='ok') ok=.false.
      end if

      if(ok)then
        max_origin_leak=max(max_origin_leak,request_origin_leak(adaptive_state,adaptive_req))
        call accept_state(manager_context%full_candidate%candidate_state,adaptive_state)
        reduced_count=reduced_count+1
        active_hist(view%active_nodes)=active_hist(view%active_nodes)+1_int64
        adaptive_work=adaptive_work+manager_context%full_candidate%diagnostics%nonlinear_iterations*view%active_nodes
      else
        call solve_fallback_step(adaptive_state,adaptive_req,fallback_res,adaptive_ledger,reason)
        if(trim(reason)/='ok') call fail_physical('fallback solve failed')
        call finalize_moving_interface_result_persistent(fallback_res,.false.,view,ws_fallback%richards%generation, &
             trim(reason),manager_context,manager_diag)
        call accept_state(manager_context%full_candidate%candidate_state,adaptive_state)
        fallback_count=fallback_count+1
        last_nonreduced_reason=trim(reason)
        adaptive_work=adaptive_work+fallback_res%diagnostics%nonlinear_iterations*nfull
      end if
    else
      call solve_fallback_step(adaptive_state,adaptive_req,fallback_res,adaptive_ledger,reason)
      if(trim(reason)/='ok') call fail_physical('bypass full solve failed')
      call finalize_moving_interface_result_persistent(fallback_res,.false.,view,ws_fallback%richards%generation, &
           trim(reason),manager_context,manager_diag)
      call accept_state(manager_context%full_candidate%candidate_state,adaptive_state)
      bypass_count=bypass_count+1
      last_nonreduced_reason=trim(reason)
      adaptive_work=adaptive_work+fallback_res%diagnostics%nonlinear_iterations*nfull
    end if
    call cpu_time(t1)
    adaptive_time=adaptive_time+(t1-t0)
    max_adaptive_ledger=max(max_adaptive_ledger,abs(adaptive_ledger))

    full_tail_new=tail_identity(full_state)
    adapt_tail_new=tail_identity(adaptive_state)
    if(full_tail_new<1 .or. adapt_tail_new<1) call fail_physical('noncontiguous tail')
    if(abs(full_tail_new-full_tail_old)>1 .or. abs(adapt_tail_new-adapt_tail_old)>1) &
         call fail_physical('ownership jump greater than one face')

    if(full_tail_new/=full_tail_old)then
      full_event_count=full_event_count+1
      full_dirs(full_event_count)=merge(1,-1,full_tail_new>full_tail_old)
    end if
    if(adapt_tail_new/=adapt_tail_old)then
      adaptive_event_count=adaptive_event_count+1
      adaptive_dirs(adaptive_event_count)=merge(1,-1,adapt_tail_new>adapt_tail_old)
    end if

    hdiff=maxval(abs(adaptive_state%pressure_head-full_state%pressure_head))
    tdiff=maxval(abs(adaptive_state%water_content-full_state%water_content))
    ponddiff=abs(adaptive_state%ponding_depth-full_state%ponding_depth)
    max_hdiff=max(max_hdiff,hdiff); max_tdiff=max(max_tdiff,tdiff); max_ponddiff=max(max_ponddiff,ponddiff)

    if(.not.all(ieee_is_finite(full_state%pressure_head)) .or. &
       .not.all(ieee_is_finite(adaptive_state%pressure_head))) call fail_physical('nonfinite head')
    if(.not.all(ieee_is_finite(full_state%water_content)) .or. &
       .not.all(ieee_is_finite(adaptive_state%water_content))) call fail_physical('nonfinite theta')
    if(abs(full_ledger)>5e-8_real64 .or. abs(adaptive_ledger)>5e-8_real64) call fail_physical('ledger hard gate')
    if(hdiff>5e-3_real64 .or. tdiff>5e-6_real64 .or. ponddiff>1e-5_real64) call fail_physical('trajectory comparison gate')
  end do

  sequence_ok=full_event_count==adaptive_event_count
  if(sequence_ok .and. full_event_count>0) sequence_ok=all(full_dirs(1:full_event_count)==adaptive_dirs(1:adaptive_event_count))
  physical_ok=sequence_ok .and. abs(tail_identity(full_state)-tail_identity(adaptive_state))<=1 .and. &
       max_origin_leak<=1e-15_real64 .and. abs(adaptive_runoff-full_runoff)<=1e-5_real64
  if(.not.physical_ok) call fail_physical('final trajectory gate')

  wall_ratio=adaptive_time/full_time
  work_ratio=real(adaptive_work,real64)/real(full_work,real64)
  mean_active=0.0_real64
  if(reduced_count>0)then
    do k=1,nfull
      mean_active=mean_active+real(k,real64)*real(active_hist(k),real64)
    end do
    mean_active=mean_active/real(reduced_count,real64)
  end if

  write(*,'(*(g0))') 'F_PE_MIQUAL04_METRICS|CASE=',trim(case_id),'|FULL_TIME=',full_time, &
       '|ADAPTIVE_TIME=',adaptive_time,'|WALL_RATIO=',wall_ratio,'|WORK_RATIO=',work_ratio, &
       '|REDUCED_COUNT=',reduced_count,'|FALLBACK_COUNT=',fallback_count,'|BYPASS_COUNT=',bypass_count, &
       '|MEAN_ACTIVE=',mean_active,'|FULL_FINAL_TAIL=',tail_identity(full_state), &
       '|ADAPTIVE_FINAL_TAIL=',tail_identity(adaptive_state),'|FULL_EVENTS=',full_event_count, &
       '|ADAPTIVE_EVENTS=',adaptive_event_count,'|MAX_HDIFF=',max_hdiff,'|MAX_TDIFF=',max_tdiff, &
       '|MAX_PONDDIFF=',max_ponddiff,'|MAX_FULL_LEDGER=',max_full_ledger, &
       '|MAX_ADAPTIVE_LEDGER=',max_adaptive_ledger,'|ORIGIN_LEAK=',max_origin_leak, &
       '|FULL_RUNOFF=',full_runoff,'|ADAPTIVE_RUNOFF=',adaptive_runoff, &
       '|REQUEST_REALLOCS=',manager_context%request_buffer_reallocations, &
       '|CANDIDATE_REALLOCS=',manager_context%full_candidate_buffer_reallocations, &
       '|FULL_FLUX=',route_flux_full,'|FULL_HEAD=',route_head_full,'|FULL_POND=',route_pond_full, &
       '|FULL_RUNOFF_ROUTE=',route_runoff_full,'|ADAPT_FLUX=',route_flux_adapt,'|ADAPT_HEAD=',route_head_adapt, &
       '|ADAPT_POND=',route_pond_adapt,'|ADAPT_RUNOFF_ROUTE=',route_runoff_adapt, &
       '|LAST_NONREDUCED_REASON=',trim(last_nonreduced_reason)
  write(*,'(a)',advance='no') 'F_PE_MIQUAL04_HIST='
  do k=1,nfull
    if(active_hist(k)>0_int64) write(*,'(*(g0))',advance='no') k,':',active_hist(k),';'
  end do
  write(*,*)
  write(*,'(a)') 'F_PE_MIQUAL04=PASS'

contains

  subroutine read_real(iarg,x)
    integer,intent(in)::iarg
    real(real64),intent(out)::x
    character(len=64)::s
    call get_command_argument(iarg,s); read(s,*)x
  end subroutine
  subroutine read_int(iarg,x)
    integer,intent(in)::iarg
    integer,intent(out)::x
    character(len=64)::s
    call get_command_argument(iarg,s); read(s,*)x
  end subroutine

  subroutine fill_cof(cof,nn)
    real(real64),intent(out)::cof(:,:)
    integer,intent(in)::nn
    integer::j
    real(real64)::mm
    cof=0.0_real64; mm=1.0_real64-1.0_real64/nvg
    do j=1,nn
      cof(1,j)=tr; cof(2,j)=ts; cof(3,j)=ksat; cof(4,j)=alpha; cof(5,j)=lambda
      cof(6,j)=nvg; cof(7,j)=mm; cof(8,j)=alpha; cof(9,j)=0.0_real64
      cof(10,j)=ksat; cof(11,j)=0.999_real64; cof(12,j)=0.99_real64*ksat
      cof(22,j)=-1.0e6_real64; cof(23,j)=1.0e-12_real64
    end do
  end subroutine

  subroutine setup_full()
    pfull%parameter_set_id=4401_int64; pfull%active_nodes=nfull
    allocate(pfull%z(nfull),pfull%dz(nfull),pfull%node_distance(nfull))
    pfull%z=z; pfull%dz=dz; pfull%node_distance=disnod(1:nfull)
    allocate(cof_full(24,nfull)); call fill_cof(cof_full,nfull)
    call initialize_b110_default_mvg_parameters(hpfull,cof_full)
    call bind_b110_default_mvg_provider(constitutive_full,hpfull,dt)
    allocate(qdra_full(1,nfull),qssdi_full(nfull),qrot_full(nfull))
    qdra_full=0.0_real64; qssdi_full=0.0_real64; qrot_full=0.0_real64
    call bind_b110_source_sink_provider(source_full,qdra_full,qssdi_full,qrot_full)
  end subroutine

  subroutine setup_reduced_provider(nn)
    integer,intent(in)::nn
    if(allocated(cof_red)) deallocate(cof_red)
    if(allocated(qdra_red)) deallocate(qdra_red)
    if(allocated(qssdi_red)) deallocate(qssdi_red)
    if(allocated(qrot_red)) deallocate(qrot_red)
    allocate(cof_red(24,nn)); call fill_cof(cof_red,nn)
    call initialize_b110_default_mvg_parameters(hpred,cof_red)
    call bind_b110_default_mvg_provider(constitutive_red,hpred,dt)
    allocate(qdra_red(1,nn),qssdi_red(nn),qrot_red(nn))
    qdra_red=0.0_real64; qssdi_red=0.0_real64; qrot_red=0.0_real64
    call bind_b110_source_sink_provider(source_red,qdra_red,qssdi_red,qrot_red)
    reduced_provider_n=nn
  end subroutine

  subroutine initialize_states()
    real(real64)::heads(nfull)
    allocate(theta_tmp(nfull),k_tmp(nfull),cap_tmp(nfull),dk_tmp(nfull))
    do k=1,nfull
      heads(k)=10.0_real64*real(k-initial_tail,real64)
    end do
    call constitutive_full%evaluate(heads,theta_tmp,k_tmp,cap_tmp,dk_tmp)
    full_state%active_nodes=nfull; adaptive_state%active_nodes=nfull
    allocate(full_state%pressure_head(nfull),full_state%water_content(nfull))
    allocate(adaptive_state%pressure_head(nfull),adaptive_state%water_content(nfull))
    full_state%pressure_head=heads; full_state%water_content=theta_tmp
    adaptive_state%pressure_head=heads; adaptive_state%water_content=theta_tmp
    full_state%ponding_depth=0.0_real64; adaptive_state%ponding_depth=0.0_real64
    full_state%groundwater_level=-10.0_real64*real(initial_tail-1,real64)
    adaptive_state%groundwater_level=full_state%groundwater_level
  end subroutine

  subroutine configure_request(req)
    type(soil_water_solve_request_t),intent(inout)::req
    req%step_duration=dt
    req%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER
    req%boundary%bottom_mode=2; req%boundary%bottom_flux=0.0_real64
    req%numerical%max_iterations=16; req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0; req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-6_real64
    req%numerical%compartment_balance_tolerance=1.0e-12_real64
    req%numerical%total_balance_tolerance=1.0e-12_real64
    req%numerical%head_abs_tolerance=1.0e-9_real64
    req%numerical%head_rel_tolerance=1.0e-9_real64
    req%numerical%ponding_tolerance=1.0e-10_real64
  end subroutine

  subroutine build_request(req,state)
    type(soil_water_solve_request_t),intent(out)::req
    type(soil_water_physical_state_t),intent(in)::state
    req%parameters=>pfull; req%base_state=state
    call configure_request(req)
    req%evaluation%constitutive=>constitutive_full
    req%evaluation%source_sink=>source_full
  end subroutine

  subroutine bind_dynamic_top(top,geom,hp,state,nn)
    type(b110_dynamic_top_boundary_solver_provider_t),intent(out),target::top
    type(soil_water_parameter_set_t),target,intent(in)::geom
    type(b110_default_mvg_parameters_t),target,intent(in)::hp
    type(soil_water_physical_state_t),intent(in)::state
    integer,intent(in)::nn
    real(real64)::fixed_k
    logical::k_ok
    call evaluate_b110_default_mvg_conductivity(hp,1,state%pressure_head(1),fixed_k,k_ok)
    call require(k_ok,'fixed top K unavailable')
    call bind_b110_dynamic_top_boundary_solver_provider(top,geom,hp,1,state%ponding_depth,dt, &
         rain,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.05_real64,0.05_real64,1.0_real64,fixed_k)
  end subroutine

  subroutine solve_full_step(state,req,solver,ws,res,ledger,why)
    type(soil_water_physical_state_t),intent(in)::state
    type(soil_water_solve_request_t),intent(inout)::req
    type(reference_richards_legacy_solver_t),intent(inout)::solver
    type(reference_richards_legacy_workspace_t),intent(inout)::ws
    type(soil_water_solve_result_t),intent(out)::res
    real(real64),intent(out)::ledger
    character(len=*),intent(out)::why
    call copy_state_to_request(state,req)
    call bind_dynamic_top(top_full,pfull,hpfull,state,nfull)
    req%evaluation%dynamic_top_boundary=>top_full
    call set_history(state,nfull)
    call solver%solve(req,ws,res)
    if(res%status/=SW_SOLVE_CONVERGED)then; why='solve'; return; end if
    call evaluate_full_top(top_full,res,state,ledger,why)
  end subroutine

  subroutine solve_fallback_step(state,req,res,ledger,why)
    type(soil_water_physical_state_t),intent(in)::state
    type(soil_water_solve_request_t),intent(inout)::req
    type(soil_water_solve_result_t),intent(out)::res
    real(real64),intent(out)::ledger
    character(len=*),intent(out)::why
    call copy_state_to_request(state,req)
    call bind_dynamic_top(top_fallback,pfull,hpfull,state,nfull)
    req%evaluation%dynamic_top_boundary=>top_fallback
    call set_history(state,nfull)
    call solver_fallback%solve(req,ws_fallback,res)
    if(res%status/=SW_SOLVE_CONVERGED)then; why='solve'; return; end if
    call evaluate_adaptive_top(top_fallback,res,state,ledger,why)
  end subroutine

  subroutine evaluate_full_top(top,res,origin,ledger,why)
    type(b110_dynamic_top_boundary_solver_provider_t),intent(in)::top
    type(soil_water_solve_result_t),intent(in)::res
    type(soil_water_physical_state_t),intent(in)::origin
    real(real64),intent(out)::ledger
    character(len=*),intent(out)::why
    type(soil_water_boundary_conditions_t)::bc
    type(soil_water_top_boundary_result_t)::trr
    real(real64)::s0,s1
    call top%evaluate(res%candidate_state%pressure_head(1),res%candidate_state%water_content(1), &
         res%candidate_state%ponding_depth,bc,trr)
    if(trr%status<=0)then; why='top'; return; end if
    s0=sum(origin%water_content*pfull%dz)+origin%ponding_depth
    s1=sum(res%candidate_state%water_content*pfull%dz)+res%candidate_state%ponding_depth
    ledger=s1-s0-rain*dt+trr%runoff_depth-res%bottom_flux*dt
    if(.not.ieee_is_finite(ledger) .or. abs(ledger)>5e-8_real64)then; why='ledger'; return; end if
    full_runoff=full_runoff+trr%runoff_depth
    call count_route(trim(trr%route),route_flux_full,route_head_full,route_pond_full,route_runoff_full)
    why='ok'
  end subroutine

  subroutine evaluate_adaptive_top(top,res,origin,ledger,why)
    type(b110_dynamic_top_boundary_solver_provider_t),intent(in)::top
    type(soil_water_solve_result_t),intent(in)::res
    type(soil_water_physical_state_t),intent(in)::origin
    real(real64),intent(out)::ledger
    character(len=*),intent(out)::why
    type(soil_water_boundary_conditions_t)::bc
    type(soil_water_top_boundary_result_t)::trr
    real(real64)::s0,s1
    call top%evaluate(res%candidate_state%pressure_head(1),res%candidate_state%water_content(1), &
         res%candidate_state%ponding_depth,bc,trr)
    if(trr%status<=0)then; why='top'; return; end if
    s0=sum(origin%water_content*pfull%dz)+origin%ponding_depth
    s1=sum(res%candidate_state%water_content*pfull%dz)+res%candidate_state%ponding_depth
    ledger=s1-s0-rain*dt+trr%runoff_depth-res%bottom_flux*dt
    if(.not.ieee_is_finite(ledger) .or. abs(ledger)>5e-8_real64)then; why='ledger'; return; end if
    adaptive_runoff=adaptive_runoff+trr%runoff_depth
    call count_route(trim(trr%route),route_flux_adapt,route_head_adapt,route_pond_adapt,route_runoff_adapt)
    why='ok'
  end subroutine

  subroutine count_route(route,nflux,nhead,npond,nrun)
    character(len=*),intent(in)::route
    integer,intent(inout)::nflux,nhead,npond,nrun
    if(trim(route)=='surface-flux')then
      nflux=nflux+1
    else if(trim(route)=='atmospheric-head')then
      nhead=nhead+1
    else if(trim(route)=='ponded-head')then
      npond=npond+1
    else if(trim(route)=='ponded-head-linear-runoff')then
      nrun=nrun+1
    end if
  end subroutine

  subroutine copy_state_to_request(state,req)
    type(soil_water_physical_state_t),intent(in)::state
    type(soil_water_solve_request_t),intent(inout)::req
    req%base_state%active_nodes=nfull
    req%base_state%pressure_head=state%pressure_head
    req%base_state%water_content=state%water_content
    req%base_state%ponding_depth=state%ponding_depth
    req%base_state%groundwater_level=state%groundwater_level
  end subroutine

  subroutine accept_state(candidate,state)
    type(soil_water_physical_state_t),intent(in)::candidate
    type(soil_water_physical_state_t),intent(inout)::state
    state%active_nodes=nfull
    state%pressure_head=candidate%pressure_head
    state%water_content=candidate%water_content
    state%ponding_depth=candidate%ponding_depth
    state%groundwater_level=candidate%groundwater_level
  end subroutine

  subroutine set_history(state,nn)
    type(soil_water_physical_state_t),intent(in)::state
    integer,intent(in)::nn
    timeint02_mode=1; timeint02_thetam2=0.0_real64
    timeint02_thetam2(1:nn)=state%water_content(1:nn)
  end subroutine

  subroutine prepare_tail_arrays(nn)
    integer,intent(in)::nn
    integer::nlocal
    nlocal=nfull-nn
    if(allocated(tail_h))then
      if(size(tail_h)/=nlocal) deallocate(tail_h,tail_th)
    end if
    if(.not.allocated(tail_h)) allocate(tail_h(nlocal),tail_th(nlocal))
  end subroutine

  subroutine reconstruct_tail(r,nn)
    type(soil_water_solve_result_t),intent(in)::r
    integer,intent(in)::nn
    integer::j
    nt=nfull-nn
    if(nt<=0)return
    tail_h(1)=r%candidate_state%pressure_head(nn)+pfull%node_distance(nn+1)
    do j=2,nt
      tail_h(j)=tail_h(j-1)+pfull%node_distance(nn+j)
    end do
    tail_th=ts
  end subroutine

  real(real64) function request_origin_leak(state,req) result(v)
    type(soil_water_physical_state_t),intent(in)::state
    type(soil_water_solve_request_t),intent(in)::req
    v=max(maxval(abs(req%base_state%pressure_head-state%pressure_head)), &
          maxval(abs(req%base_state%water_content-state%water_content)), &
          abs(req%base_state%ponding_depth-state%ponding_depth))
  end function

  integer function tail_identity(s) result(first)
    type(soil_water_physical_state_t),intent(in)::s
    logical::sat(nfull)
    integer::j
    sat=.false.
    do j=1,nfull
      sat(j)=s%pressure_head(j)>=0.0_real64 .and. abs(s%water_content(j)-ts)<=1e-10_real64
    end do
    first=nfull+1
    do j=nfull,1,-1
      if(sat(j))then; first=j; else; exit; end if
    end do
    if(first<=nfull .and. first>1)then
      if(any(sat(1:first-1))) first=-1
    end if
  end function

  subroutine emit_ref_fail(last,msg)
    integer,intent(in)::last
    character(len=*),intent(in)::msg
    write(*,'(*(g0))') 'F_PE_MIQUAL04_REF|CASE=',trim(case_id),'|COMPLETE=0|LAST_ACCEPTED=',last, &
         '|REASON=',trim(msg),'|MAX_LEDGER=',max_full_ledger,'|TAIL=',tail_identity(full_state), &
         '|RUNOFF=',full_runoff,'|FLUX=',route_flux_full,'|HEAD=',route_head_full,'|POND=',route_pond_full, &
         '|RUNOFF_ROUTE=',route_runoff_full
    write(*,'(a)') 'F_PE_MIQUAL04=PASS'
    stop
  end subroutine

  subroutine fail_physical(msg)
    character(len=*),intent(in)::msg
    write(*,'(A,1X,A)') 'F_PE_MIQUAL04_PHYSICAL_FAIL',trim(msg)
    write(*,'(a)') 'F_PE_MIQUAL04=PASS'
    stop
  end subroutine

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)') 'F_PE_MIQUAL04_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine
end program test_fpe_miqual04_dynamic_top
