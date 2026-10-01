program test_fpe_miqual07_serialized_benchmark
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t, kernel_executor_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_BASE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state
  use mod_fmr_moving_interface_runtime_adapter, only: fmr_moving_interface_runtime_timing_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_timestep_numerical_profile, only: timestep_numerical_profile_t, make_moving_interface_manager_profile
  use mod_moving_interface_manager, only: MI_MANAGER_ROUTE_REDUCED, MI_MANAGER_ROUTE_FULL_FALLBACK, &
       MI_MANAGER_ROUTE_FULL_BYPASS
  implicit none

  integer, parameter :: nstep=4000, tail_start=13
  character(len=32) :: variant, workload
  real(real64) :: dt, top_flux, cpu0, cpu1
  type(fmr_b110_physical_parameters_t),target::parameters
  type(fmr_b110_physical_forcing_t)::forcing
  type(fmr_b110_physical_state_t)::initial, final_state
  type(fmr_serialized_reference_backend_t)::backend
  type(fixed_flux_top_boundary_provider_t),target::top
  type(timestep_numerical_profile_t)::profile
  type(kernel_committed_state_t)::committed
  type(kernel_checkpoint_t)::checkpoint
  type(kernel_result_t)::result
  type(kernel_candidate_state_t)::candidate
  type(kernel_diagnostics_t)::diagnostics
  type(kernel_executor_t)::committer
  type(fmr_logical_column_t)::column
  type(fmr_template_t)::template
  type(canonical_numerical_config_t)::config
  type(fmr_serialized_physical_observation_t)::obs
  type(fmr_moving_interface_runtime_timing_t)::mi_timing
  class(transaction_state_t),allocatable::snapshot
  logical::ok,available,did_commit,complete
  integer::i,last_accepted,attempts,retries,total_nl,total_jac,total_lin,total_back
  integer::reduced_count,fallback_count,bypass_count
  integer::active_n,work_index,final_tail
  real(real64)::max_mass_residual,storage,theta_top,theta_mid,theta_bottom
  character(len=64)::fail_reason,last_reason

  call require(numnod==16,'MIQUAL07 requires N=16')
  call get_command_argument(1,variant)
  call get_command_argument(2,workload)
  call configure_workload()

  call initialize_parameters(parameters)
  call initialize_state(parameters,initial)
  call initialize_forcing(forcing)
  call fmr_new_b110_committed_state(committed,770007_int64,initial,0.0_real64,ok)
  call require(ok,'committed initialize')

  template%template_id=770001_int64
  template%physics_topology_id=770002_int64
  template%vertical_layout_id=770003_int64
  template%state_layout_id=770004_int64
  template%solver_interface_id=770005_int64
  template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
  template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
  template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE

  column%column_id=770007_int64
  column%template_id=template%template_id
  column%parameter_ref=1_int64
  column%state_handle=1_int64
  column%forcing_handle=1_int64
  column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE

  config%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
  config%transaction%temporal_tolerance=1.0_real64
  config%transaction%mass_tolerance=1.0e-10_real64
  config%transaction%max_retries=2
  config%transaction%retry_scale=0.5_real64
  config%max_committed_substeps=4
  config%progress_tolerance=0.0_real64

  call backend%initialize(top)
  if(trim(variant)=='MANAGER')then
    profile=make_moving_interface_manager_profile('MOVING_INTERFACE_MANAGER',.true.)
    call backend%configure_moving_interface_profile(profile,ok)
    call require(ok,'manager profile accepted')
  else
    call require(trim(variant)=='LEGACY','invalid variant')
  end if

  complete=.true.; fail_reason='none'; last_reason='none'; last_accepted=0
  attempts=0; retries=0; total_nl=0; total_jac=0; total_lin=0; total_back=0
  reduced_count=0; fallback_count=0; bypass_count=0
  work_index=0; max_mass_residual=0.0_real64

  call cpu_time(cpu0)
  do i=1,nstep
    call committed%capture_checkpoint(checkpoint,available)
    if(.not.available)then
      complete=.false.;fail_reason='checkpoint';exit
    end if

    call backend%run_trial(column,template,parameters,committed,forcing,config, &
         real(i-1,real64)*dt,real(i,real64)*dt,checkpoint,result,candidate,diagnostics)
    obs=backend%observation()

    attempts=attempts+diagnostics%attempts
    retries=retries+diagnostics%retries
    total_nl=total_nl+diagnostics%nonlinear_iterations
    total_jac=total_jac+diagnostics%jacobian_builds
    total_lin=total_lin+diagnostics%linear_solves
    total_back=total_back+diagnostics%backtracking_attempts
    max_mass_residual=max(max_mass_residual,diagnostics%max_abs_step_mass_residual)

    active_n=numnod
    if(trim(variant)=='MANAGER')then
      select case(obs%moving_interface_manager_route)
      case(MI_MANAGER_ROUTE_REDUCED)
        reduced_count=reduced_count+1
        active_n=max(1,obs%moving_interface_active_nodes)
      case(MI_MANAGER_ROUTE_FULL_FALLBACK)
        fallback_count=fallback_count+1
      case(MI_MANAGER_ROUTE_FULL_BYPASS)
        bypass_count=bypass_count+1
      end select
      last_reason=trim(obs%moving_interface_reason)
    end if
    work_index=work_index+diagnostics%nonlinear_iterations*active_n

    if(.not.candidate%ready())then
      complete=.false.;fail_reason='candidate';exit
    end if
    call committer%commit_candidate(committed,candidate,diagnostics,did_commit)
    if(.not.did_commit)then
      complete=.false.;fail_reason='commit';exit
    end if
    last_accepted=i
  end do
  call cpu_time(cpu1)

  call committed%snapshot(snapshot,available)
  call require(available,'final snapshot')
  select type(s=>snapshot)
  type is(fmr_b110_physical_state_t)
    final_state=s
  class default
    call require(.false.,'final snapshot type')
  end select

  storage=sum(final_state%water_content*parameters%dz)+final_state%ponding_depth
  theta_top=final_state%water_content(1)
  theta_mid=final_state%water_content((numnod+1)/2)
  theta_bottom=final_state%water_content(numnod)
  final_tail=tail_identity(final_state,parameters%cofgen(2,:))
  mi_timing=fmr_moving_interface_runtime_timing_t()
  if(trim(variant)=='MANAGER') call backend%moving_interface_timing_snapshot(mi_timing)

  write(*,'(*(g0))') 'F_PE_MIQUAL07_RESULT|VARIANT=',trim(variant),'|WORKLOAD=',trim(workload), &
       '|COMPLETE=',merge(1,0,complete),'|LAST_ACCEPTED=',last_accepted,'|FAIL_REASON=',trim(fail_reason), &
       '|CPU=',cpu1-cpu0,'|ATTEMPTS=',attempts,'|RETRIES=',retries,'|NL=',total_nl,'|JAC=',total_jac, &
       '|LIN=',total_lin,'|BACK=',total_back,'|WORK=',work_index,'|REDUCED=',reduced_count, &
       '|FALLBACK=',fallback_count,'|BYPASS=',bypass_count,'|MAX_MASS=',max_mass_residual, &
       '|TOP_H=',final_state%pressure_head(1),'|MID_H=',final_state%pressure_head((numnod+1)/2), &
       '|BOTTOM_H=',final_state%pressure_head(numnod),'|TOP_TH=',theta_top,'|MID_TH=',theta_mid, &
       '|BOTTOM_TH=',theta_bottom,'|STORAGE=',storage,'|POND=',final_state%ponding_depth, &
       '|TAIL=',final_tail,'|LAST_REASON=',trim(last_reason), &
       '|MI_CLOCK_RATE=',mi_timing%clock_rate,'|MI_CALLS=',mi_timing%successful_reduced_calls, &
       '|MI_TOTAL_TICKS=',mi_timing%adapter_total_ticks,'|MI_SOLVE_TICKS=',mi_timing%reduced_solve_ticks
  write(*,'(a)',advance='no') 'F_PE_MIQUAL07_H='
  do i=1,numnod
    write(*,'(es26.17e3)',advance='no') final_state%pressure_head(i)
    if(i<numnod) write(*,'(a)',advance='no') ','
  end do
  write(*,*)
  write(*,'(a)',advance='no') 'F_PE_MIQUAL07_TH='
  do i=1,numnod
    write(*,'(es26.17e3)',advance='no') final_state%water_content(i)
    if(i<numnod) write(*,'(a)',advance='no') ','
  end do
  write(*,*)
  write(*,'(a)') 'F_PE_MIQUAL07=PASS'

contains

  subroutine configure_workload()
    if(trim(workload)=='EQUILIBRIUM')then
      dt=0.00125_real64
      top_flux=0.0_real64
    else if(trim(workload)=='MILD_DYNAMIC')then
      dt=0.000125_real64
      top_flux=-0.01_real64
    else
      call require(.false.,'invalid workload')
    end if
  end subroutine configure_workload

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer::j
    real(real64),parameter::tr=0.01_real64,ts=0.336701_real64,alpha=0.030304_real64
    real(real64),parameter::nvg=2.887502_real64,ksat=17.418504_real64,lambda=0.0736_real64
    real(real64)::mm
    mm=1.0_real64-1.0_real64/nvg
    p%parameter_set_id=770007_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod);p%cofgen=0.0_real64
    do j=1,numnod
      p%cofgen(1,j)=tr;p%cofgen(2,j)=ts;p%cofgen(3,j)=ksat;p%cofgen(4,j)=alpha
      p%cofgen(5,j)=lambda;p%cofgen(6,j)=nvg;p%cofgen(7,j)=mm;p%cofgen(8,j)=alpha
      p%cofgen(9,j)=0.0_real64;p%cofgen(10,j)=ksat;p%cofgen(11,j)=0.999_real64
      p%cofgen(12,j)=0.99_real64*ksat;p%cofgen(22,j)=-1.0e6_real64;p%cofgen(23,j)=1.0e-12_real64
    end do
    p%bottom_mode=2;p%swkimpl=0;p%swkmean=1;p%swsophy=0
    p%max_iterations=16;p%max_backtracking=8;p%min_step_duration=1.0e-6_real64
    p%compartment_balance_tolerance=1.0e-12_real64;p%total_balance_tolerance=1.0e-12_real64
    p%head_abs_tolerance=1.0e-9_real64;p%head_rel_tolerance=1.0e-9_real64;p%ponding_tolerance=1.0e-10_real64
    p%root_extraction_active=.false.;p%macropore_active=.false.;p%snow_active=.false.
    p%hysteresis_active=.false.;p%tabulated_hydraulics_active=.false.;p%direct_retention_active=.false.
    p%ksatexm_extension_active=.false.;p%elasticity_active=.false.;p%frost_active=.false.
    p%soil_temperature_active=.false.;p%black_evaporation_active=.false.;p%boesten_evaporation_active=.false.
    p%drainage_response_active=.false.
  end subroutine initialize_parameters

  subroutine initialize_state(p,s)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(fmr_b110_physical_state_t),intent(out)::s
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::heads(numnod),water(numnod),kk(numnod),cap(numnod),dkv(numnod)
    integer::j
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,dt)
    do j=1,numnod
      heads(j)=10.0_real64*real(j-tail_start,real64)
    end do
    call provider%evaluate(heads,water,kk,cap,dkv)
    s%active_nodes=numnod
    allocate(s%pressure_head(numnod),s%water_content(numnod))
    s%pressure_head=heads;s%water_content=water
    s%ponding_depth=0.0_real64;s%groundwater_level=-120.0_real64
  end subroutine initialize_state

  subroutine initialize_forcing(f)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    f%top_flux=top_flux;f%top_head=0.0_real64;f%bottom_flux=0.0_real64;f%bottom_head=0.0_real64
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64;f%subsurface_irrigation_source=0.0_real64;f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  integer function tail_identity(s,theta_s) result(first)
    type(fmr_b110_physical_state_t),intent(in)::s
    real(real64),intent(in)::theta_s(:)
    logical::sat(numnod)
    integer::j
    sat=s%pressure_head>=0.0_real64 .and. abs(s%water_content-theta_s)<=1e-10_real64
    first=numnod+1
    do j=numnod,1,-1
      if(sat(j))then
        first=j
      else
        exit
      end if
    end do
    if(first<=numnod .and. first>1)then
      if(any(sat(1:first-1))) first=-1
    end if
  end function tail_identity

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(a,1x,a)')'F_PE_MIQUAL07_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine require
end program test_fpe_miqual07_serialized_benchmark
