program test_fahl_governance_prescribed_head_trajectory_fallback
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_executor_t, kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_execute_serialized_resolved_physical_column
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_soil_water_accepted_step_direction_contract, only: SW_STEP_CONTROL_BOTTOM_FLUX
  use mod_b110_adaptive_hydraulic_provider, only: b110_adaptive_hydraulic_cache_stats
  implicit none

  ! F-AHL27 routing fixture intentionally uses stationary prescribed-head
  ! conditions. Nonlinear head perturbations are qualified separately by the
  ! frozen 12-case Stage-2 matrix; this test isolates resolved FMR routing,
  ! commit semantics and default-off versus explicit-opt-in identity.
  real(real64), parameter :: h0=-75.0_real64, dt=0.25_real64
  real(real64), parameter :: mass_gate=1.0e-12_real64
  integer(int64), parameter :: column_id=527027_int64

  type(fmr_serialized_column_result_t) :: off_result,on_result
  type(fmr_serialized_physical_observation_t) :: off_obs,on_obs
  type(kernel_committed_state_t) :: off_committed,on_committed
  class(transaction_state_t),allocatable :: off_state,on_state
  logical :: off_av,on_av
  real(real64) :: dh,dw

  call execute_case(.false.,off_result,off_obs,off_committed)
  call execute_case(.true.,on_result,on_obs,on_committed)

  write(*,'(A,L1,1X,A,L1,1X,A,I0,1X,A,I0,1X,A,A)') 'FAHL27_OFF_DEBUG completed=',off_result%completed, &
       'committed=',off_result%committed,'kernel=',off_result%kernel_status,'substeps=',off_result%accepted_substeps, &
       'admission=',trim(off_result%admission_status)
  write(*,'(A,L1,1X,A,L1,1X,A,I0,1X,A,I0,1X,A,A)') 'FAHL27_ON_DEBUG completed=',on_result%completed, &
       'committed=',on_result%committed,'kernel=',on_result%kernel_status,'substeps=',on_result%accepted_substeps, &
       'admission=',trim(on_result%admission_status)
  call require(off_result%completed .and. off_result%committed,'analytical resolved runtime completed')
  call require(on_result%completed .and. on_result%committed,'adaptive resolved runtime completed')
  call require(off_result%mass%complete .and. on_result%mass%complete,'mass ledgers complete')
  call require(abs(off_result%mass%residual)<=mass_gate .and. abs(on_result%mass%residual)<=mass_gate,'mass gates')
  call require(off_obs%solver_executed .and. on_obs%solver_executed,'solvers executed')
  call require(off_obs%solver_status==on_obs%solver_status,'same solver status')
  call require(off_obs%solver_diagnostics%nonlinear_iterations==on_obs%solver_diagnostics%nonlinear_iterations, &
       'same nonlinear iterations')
  call require(off_obs%solver_diagnostics%backtracking_attempts==on_obs%solver_diagnostics%backtracking_attempts, &
       'same backtracking')
  call require(abs(off_obs%top_flux-on_obs%top_flux)<=1.0e-5_real64,'top flux envelope')
  call require(abs(off_obs%bottom_flux-on_obs%bottom_flux)<=1.0e-5_real64,'bottom flux envelope')

  call off_committed%snapshot(off_state,off_av)
  call on_committed%snapshot(on_state,on_av)
  call require(off_av .and. on_av,'committed snapshots available')
  call compare_states(off_state,on_state,dh,dw)
  call require(dh<=0.05_real64,'committed head envelope')
  call require(dw<=1.0e-4_real64,'committed theta envelope')

  write(*,'(A,ES14.6,1X,A,ES14.6,1X,A,ES14.6)') 'FAHL27_RESOLVED MAX_DH=',dh, &
       'MAX_DTHETA=',dw,'DBOTTOM=',abs(off_obs%bottom_flux-on_obs%bottom_flux)
  write(*,'(A,I0,1X,A,I0,1X,A,I0)') 'FAHL27_RESOLVED ACCEPTED_SUBSTEPS=',on_result%accepted_substeps, &
       'ITER=',on_obs%solver_diagnostics%nonlinear_iterations,'BACKTRACK=',on_obs%solver_diagnostics%backtracking_attempts
  block
    integer :: builds,hits,misses,entries
    call b110_adaptive_hydraulic_cache_stats(builds,hits,misses,entries)
    call require(builds==0 .and. hits==0 .and. misses==0 .and. entries==0, &
         'prescribed-head trajectory request must leave AHL cache untouched')
    write(*,'(A,I0,A,I0,A,I0,A,I0)') 'FAHL_TRAJECTORY_HEAD_CACHE BUILDS=',builds,' HITS=',hits, &
         ' MISSES=',misses,' ENTRIES=',entries
  end block
  write(*,'(A)') 'FAHL_PRESCRIBED_HEAD_TRAJECTORY_ANALYTICAL_FALLBACK=PASS'

contains

  subroutine execute_case(adaptive,output,observation,committed)
    logical,intent(in)::adaptive
    type(fmr_serialized_column_result_t),intent(out)::output
    type(fmr_serialized_physical_observation_t),intent(out)::observation
    type(kernel_committed_state_t),intent(out)::committed
    type(fmr_serialized_reference_backend_t)::backend
    type(kernel_executor_t)::transaction_control
    type(fmr_logical_column_t)::column
    type(fmr_template_t)::template
    type(fmr_b110_physical_parameters_t)::parameters
    type(fmr_b110_physical_forcing_t)::forcing
    type(canonical_numerical_config_t)::config
    type(fmr_column_diagnostics_t)::diagnostic
    type(fmr_serialized_batch_diagnostics_t)::runtime
    type(fixed_flux_top_boundary_provider_t),target::top
    integer::active_calls
    logical::ok
    real(real64)::k0, hydro_bottom

    call initialize_parameters(parameters,adaptive)
    call determine_initial_conductivity(parameters,k0)
    call initialize_committed(committed,parameters,ok)
    call require(ok,'committed state initialized')
    hydro_bottom=h0+sum(disnod(2:numnod))
    call initialize_forcing(forcing,0.0_real64,hydro_bottom)
    call initialize_column(column,template)
    call initialize_config(config)
    config%accepted_trajectory_direction%requested=.true.
    config%accepted_trajectory_direction%control_coordinate=SW_STEP_CONTROL_BOTTOM_FLUX

    output=fmr_serialized_column_result_t()
    output%column_id=column_id;output%requested_t0=0.0_real64;output%requested_t1=dt
    diagnostic=fmr_column_diagnostics_t();diagnostic%column_id=column_id
    runtime=fmr_serialized_batch_diagnostics_t();active_calls=0

    call backend%initialize(top)
    call fmr_execute_serialized_resolved_physical_column(backend,transaction_control,column,template,parameters, &
         forcing,committed,config,0.0_real64,dt,output,diagnostic,runtime,active_calls)
    observation=backend%observation()
    write(*,'(A,L1,A,I0,A,I0,A,I0,A,I0,A,A,A,L1,A,I0,A,ES14.6)') &
         'FAHL27_CASE_DEBUG adaptive=',adaptive,' attempts=',diagnostic%attempts, &
         ' retries=',diagnostic%retries,' accepted=',diagnostic%accepted,' rejected=',diagnostic%rejected, &
         ' failure=',trim(diagnostic%failure_classification),' solver_executed=',observation%solver_executed, &
         ' solver_status=',observation%solver_status,' mass_residual=',diagnostic%unrounded_mass_residual
  end subroutine

  subroutine initialize_parameters(p,adaptive)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    logical,intent(in)::adaptive
    integer::i
    p%parameter_set_id=527027_int64;p%active_nodes=numnod
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
    p%compartment_balance_tolerance=mass_gate;p%total_balance_tolerance=mass_gate
    p%head_abs_tolerance=mass_gate;p%head_rel_tolerance=mass_gate;p%ponding_tolerance=mass_gate
    p%root_extraction_active=.false.;p%macropore_active=.false.;p%snow_active=.false.
    p%hysteresis_active=.false.;p%tabulated_hydraulics_active=.false.;p%adaptive_hydraulics_active=adaptive
    p%elasticity_active=.false.;p%frost_active=.false.;p%soil_temperature_active=.false.
    p%drainage_response_active=.false.;p%black_evaporation_active=.false.;p%boesten_evaporation_active=.false.
  end subroutine

  subroutine determine_initial_conductivity(p,k0)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    real(real64),intent(out)::k0
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::hh(numnod),ww(numnod),kk(numnod),cc(numnod),dd(numnod)
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,dt)
    hh=h0;call provider%evaluate(hh,ww,kk,cc,dd);k0=kk(1)
  end subroutine

  subroutine initialize_committed(committed,p,ok)
    type(kernel_committed_state_t),intent(out)::committed
    type(fmr_b110_physical_parameters_t),intent(in)::p
    logical,intent(out)::ok
    integer :: k
    type(fmr_b110_physical_state_t)::state
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::hh(numnod),ww(numnod),kk(numnod),cc(numnod),dd(numnod)
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,dt)
    hh(1)=h0
    do k=2,numnod
      hh(k)=hh(k-1)+p%node_distance(k)
    end do
    call provider%evaluate(hh,ww,kk,cc,dd)
    state%active_nodes=numnod;allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=hh;state%water_content=ww;state%ponding_depth=0.0_real64;state%groundwater_level=-2.0_real64
    call fmr_new_b110_committed_state(committed,column_id,state,0.0_real64,ok)
  end subroutine

  subroutine initialize_forcing(f,qtop,bottom_head)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    real(real64),intent(in)::qtop,bottom_head
    f%top_flux=qtop;f%top_head=h0;f%bottom_flux=0.0_real64;f%bottom_head=bottom_head
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64;f%subsurface_irrigation_source=0.0_real64;f%root_extraction_sink=0.0_real64
  end subroutine

  subroutine initialize_column(c,t)
    type(fmr_logical_column_t),intent(out)::c
    type(fmr_template_t),intent(out)::t
    t%template_id=527021_int64;t%physics_topology_id=527022_int64;t%vertical_layout_id=527023_int64
    t%state_layout_id=527024_int64;t%solver_interface_id=527025_int64;t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE;t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=column_id;c%template_id=t%template_id;c%parameter_ref=1_int64;c%state_handle=1_int64
    c%forcing_handle=1_int64;c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine

  subroutine initialize_config(c)
    type(canonical_numerical_config_t),intent(out)::c
    c%transaction%temporal_mode=TX_TEMPORAL_NONE;c%transaction%temporal_tolerance=0.0_real64
    c%transaction%mass_tolerance=mass_gate;c%transaction%retry_scale=0.5_real64;c%transaction%max_retries=8
    c%max_committed_substeps=32;c%progress_tolerance=0.0_real64
    c%model_temporal_indicator_budget_available=.false.;c%model_temporal_indicator_budget=0.0_real64
    c%accepted_trajectory_direction%requested=.false.
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
        call require(.false.,'adaptive state type')
      end select
    class default
      call require(.false.,'analytical state type')
    end select
  end subroutine

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'FAHL_TRAJECTORY_HEAD_FAIL',trim(msg);error stop 1
    end if
  end subroutine
end program test_fahl_governance_prescribed_head_trajectory_fallback
