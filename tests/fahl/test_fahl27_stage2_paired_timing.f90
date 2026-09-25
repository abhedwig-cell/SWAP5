program test_fahl27_stage2_paired_timing
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, &
       fmr_serialized_physical_observation_t, fmr_new_b110_committed_state
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: h0=-75.0_real64, hbot=-50.0_real64, duration=0.25_real64
  real(real64), parameter :: mass_tol=1.0e-12_real64
  integer, parameter :: NREPLAY=8192, NPAIR=7
  integer(int64), parameter :: column_id=527001_int64

  type(fmr_b110_physical_parameters_t) :: p_off,p_on
  type(fmr_b110_physical_forcing_t) :: forcing
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(canonical_numerical_config_t) :: config
  type(kernel_committed_state_t) :: committed_off,committed_on
  type(kernel_checkpoint_t) :: cp_off,cp_on
  type(kernel_result_t) :: result_off,result_on
  type(kernel_candidate_state_t) :: cand_off,cand_on
  type(kernel_diagnostics_t) :: diag_off,diag_on
  type(fmr_serialized_reference_backend_t) :: backend_off,backend_on
  type(fmr_serialized_physical_observation_t) :: obs_off,obs_on
  type(fixed_flux_top_boundary_provider_t),target :: top
  class(transaction_state_t),allocatable :: state_off,state_on
  logical :: ok,av_off,av_on
  real(real64) :: k0,max_dh,max_dw
  real(real64) :: times_off(NPAIR),times_on(NPAIR),ratios(NPAIR)
  integer :: r

  call init_parameters(p_off)
  p_on=p_off
  p_on%adaptive_hydraulics_active=.true.
  call initial_k(p_off,k0)
  call init_forcing(forcing,-k0)
  call init_column(column,template)
  call init_config(config)

  call init_committed(committed_off,p_off,ok); call require(ok,'off committed')
  call init_committed(committed_on,p_on,ok); call require(ok,'on committed')
  call fmr_capture_checkpoint(committed_off,cp_off,ok); call require(ok,'off checkpoint')
  call fmr_capture_checkpoint(committed_on,cp_on,ok); call require(ok,'on checkpoint')

  call backend_off%initialize(top)
  call backend_on%initialize(top)
  call backend_off%run_trial(column,template,p_off,committed_off,forcing,config,0.0_real64,duration,cp_off, &
       result_off,cand_off,diag_off)
  call backend_on%run_trial(column,template,p_on,committed_on,forcing,config,0.0_real64,duration,cp_on, &
       result_on,cand_on,diag_on)

  call require(result_off%status==CANONICAL_STATUS_COMPLETED .and. result_off%completed,'off complete')
  call require(result_on%status==CANONICAL_STATUS_COMPLETED .and. result_on%completed,'on complete')
  call require(result_off%mass%complete .and. result_on%mass%complete,'mass complete')
  call require(abs(result_off%mass%residual)<=mass_tol .and. abs(result_on%mass%residual)<=mass_tol,'mass gate')
  call require(cand_off%ready() .and. cand_on%ready(),'candidates ready')

  call cand_off%snapshot(state_off,av_off); call cand_on%snapshot(state_on,av_on)
  call require(av_off .and. av_on,'snapshots')
  call compare_states(state_off,state_on,max_dh,max_dw)
  call require(max_dh<=0.05_real64,'head envelope')
  call require(max_dw<=1.0e-4_real64,'theta envelope')

  obs_off=backend_off%observation()
  obs_on=backend_on%observation()
  call require(obs_off%solver_executed .and. obs_on%solver_executed,'solver executed')
  call require(obs_off%solver_status==obs_on%solver_status,'solver status')
  call require(obs_off%solver_diagnostics%nonlinear_iterations==obs_on%solver_diagnostics%nonlinear_iterations, &
       'same nonlinear iterations')
  call require(obs_off%solver_diagnostics%backtracking_attempts==obs_on%solver_diagnostics%backtracking_attempts, &
       'same backtracking')
  call require(abs(obs_on%bottom_flux-obs_off%bottom_flux)<=1.0e-5_real64,'bottom flux envelope')
  call require(abs(obs_on%top_flux-obs_off%top_flux)<=1.0e-5_real64,'top flux envelope')

  write(*,'(A,ES14.6,1X,A,ES14.6,1X,A,ES14.6)') 'FAHL27_FMR MAX_DH=',max_dh, &
       'MAX_DTHETA=',max_dw,'DBOTTOM=',abs(obs_on%bottom_flux-obs_off%bottom_flux)
  write(*,'(A,I0,1X,A,I0)') 'FAHL27_FMR ITER=',obs_on%solver_diagnostics%nonlinear_iterations, &
       'BACKTRACK=',obs_on%solver_diagnostics%backtracking_attempts
  write(*,'(A)') 'FAHL27_FMR_OPT_IN_RUNTIME=PASS'
  do r=1,NPAIR
    if(mod(r,2)==1)then
      call time_batch(.false.,times_off(r))
      call time_batch(.true.,times_on(r))
    else
      call time_batch(.true.,times_on(r))
      call time_batch(.false.,times_off(r))
    end if
    ratios(r)=times_on(r)/times_off(r)
    write(*,'(A,I0,2(1X,ES18.10),1X,F10.6)') 'FAHL27_FMR_PAIR ',r,times_off(r),times_on(r),ratios(r)
  end do
  call sort7(ratios)
  write(*,'(A,F10.6)') 'FAHL27_FMR_MEDIAN_RATIO ',ratios(4)
  write(*,'(A,F10.6)') 'FAHL27_FMR_MEDIAN_REDUCTION ',1.0_real64-ratios(4)
  call require(ratios(4)<0.98_real64,'application speed gate')
  write(*,'(A)') 'FAHL27_STAGE2_FMR_TIMING=PASS'

contains
  subroutine time_batch(adaptive,elapsed)
    logical,intent(in)::adaptive
    real(real64),intent(out)::elapsed
    real(real64)::t0,t1
    integer::i
    call cpu_time(t0)
    if(adaptive)then
      do i=1,NREPLAY
        call backend_on%run_trial(column,template,p_on,committed_on,forcing,config,0.0_real64,duration,cp_on, &
             result_on,cand_on,diag_on)
        if(result_on%status/=CANONICAL_STATUS_COMPLETED) error stop 'timed adaptive trial failed'
      end do
    else
      do i=1,NREPLAY
        call backend_off%run_trial(column,template,p_off,committed_off,forcing,config,0.0_real64,duration,cp_off, &
             result_off,cand_off,diag_off)
        if(result_off%status/=CANONICAL_STATUS_COMPLETED) error stop 'timed analytical trial failed'
      end do
    end if
    call cpu_time(t1)
    elapsed=(t1-t0)/real(NREPLAY,real64)
  end subroutine time_batch

  subroutine sort7(v)
    real(real64),intent(inout)::v(7)
    real(real64)::tmp
    integer::i,j
    do i=1,6
      do j=i+1,7
        if(v(j)<v(i))then;tmp=v(i);v(i)=v(j);v(j)=tmp;end if
      end do
    end do
  end subroutine sort7


  subroutine init_parameters(p)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer::i
    p%parameter_set_id=527001_int64; p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod);p%cofgen=0.0_real64
    do i=1,numnod
      p%cofgen(1,i)=0.032_real64;p%cofgen(2,i)=0.423_real64;p%cofgen(3,i)=4.75_real64
      p%cofgen(4,i)=0.0135_real64;p%cofgen(5,i)=0.365_real64;p%cofgen(6,i)=1.455_real64
      p%cofgen(7,i)=1.0_real64-1.0_real64/p%cofgen(6,i);p%cofgen(8,i)=p%cofgen(4,i)
      p%cofgen(9,i)=0.0_real64;p%cofgen(10,i)=p%cofgen(3,i);p%cofgen(11,i)=0.999_real64
      p%cofgen(12,i)=0.99_real64*p%cofgen(3,i);p%cofgen(22,i)=-1.0e6_real64;p%cofgen(23,i)=1.0e-12_real64
    end do
    p%bottom_mode=5;p%swkimpl=0;p%swkmean=1;p%swsophy=0
    p%max_iterations=16;p%max_backtracking=8;p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=mass_tol;p%total_balance_tolerance=mass_tol
    p%head_abs_tolerance=mass_tol;p%head_rel_tolerance=mass_tol;p%ponding_tolerance=mass_tol
    p%root_extraction_active=.false.;p%macropore_active=.false.;p%snow_active=.false.
    p%hysteresis_active=.false.;p%tabulated_hydraulics_active=.false.;p%adaptive_hydraulics_active=.false.
    p%elasticity_active=.false.;p%frost_active=.false.;p%soil_temperature_active=.false.;p%drainage_response_active=.false.
  end subroutine

  subroutine initial_k(p,k)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    real(real64),intent(out)::k
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::prov
    real(real64)::hh(numnod),ww(numnod),kk(numnod),cc(numnod),dd(numnod)
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(prov,hp,duration)
    hh=h0;call prov%evaluate(hh,ww,kk,cc,dd);k=kk(1)
  end subroutine

  subroutine init_forcing(f,qtop)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    real(real64),intent(in)::qtop
    f%top_flux=qtop;f%top_head=h0;f%bottom_flux=0.0_real64;f%bottom_head=hbot
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64;f%subsurface_irrigation_source=0.0_real64;f%root_extraction_sink=0.0_real64
  end subroutine

  subroutine init_column(c,t)
    type(fmr_logical_column_t),intent(out)::c
    type(fmr_template_t),intent(out)::t
    t%template_id=527011_int64;t%physics_topology_id=527012_int64;t%vertical_layout_id=527013_int64
    t%state_layout_id=527014_int64;t%solver_interface_id=527015_int64;t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE;t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=column_id;c%template_id=t%template_id;c%parameter_ref=1_int64;c%state_handle=1_int64
    c%forcing_handle=1_int64;c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine

  subroutine init_config(c)
    type(canonical_numerical_config_t),intent(out)::c
    c%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF;c%transaction%temporal_tolerance=1.0e-6_real64
    c%transaction%mass_tolerance=mass_tol;c%transaction%retry_scale=0.5_real64;c%transaction%max_retries=8
    c%max_committed_substeps=32;c%progress_tolerance=0.0_real64
    c%model_temporal_indicator_budget_available=.false.;c%model_temporal_indicator_budget=0.0_real64
    c%accepted_trajectory_direction%requested=.false.
  end subroutine

  subroutine init_committed(committed,p,ok)
    type(kernel_committed_state_t),intent(out)::committed
    type(fmr_b110_physical_parameters_t),intent(in)::p
    logical,intent(out)::ok
    type(fmr_b110_physical_state_t)::st
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::prov
    real(real64)::hh(numnod),ww(numnod),kk(numnod),cc(numnod),dd(numnod)
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(prov,hp,duration)
    hh=h0;call prov%evaluate(hh,ww,kk,cc,dd)
    st%active_nodes=numnod;allocate(st%pressure_head(numnod),st%water_content(numnod))
    st%pressure_head=hh;st%water_content=ww;st%ponding_depth=0.0_real64;st%groundwater_level=-2.0_real64
    call fmr_new_b110_committed_state(committed,column_id,st,0.0_real64,ok)
  end subroutine

  subroutine compare_states(a,b,dh,dw)
    class(transaction_state_t),intent(in)::a,b
    real(real64),intent(out)::dh,dw
    dh=huge(1.0_real64);dw=huge(1.0_real64)
    select type(x=>a)
    type is(fmr_b110_physical_state_t)
      select type(y=>b)
      type is(fmr_b110_physical_state_t)
        dh=maxval(abs(x%pressure_head-y%pressure_head));dw=maxval(abs(x%water_content-y%water_content))
      class default
        call require(.false.,'on state type')
      end select
    class default
      call require(.false.,'off state type')
    end select
  end subroutine

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'FAHL27_FMR_TIMING_FAIL',trim(msg);error stop 1
    end if
  end subroutine
end program test_fahl27_stage2_paired_timing
