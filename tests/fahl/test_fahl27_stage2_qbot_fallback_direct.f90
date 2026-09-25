program test_fahl27_stage2_qbot_fallback_direct
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, &
       fmr_new_b110_committed_state
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_adaptive_hydraulic_provider, only: b110_adaptive_hydraulic_cache_stats
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: h0=-75.0_real64, duration=0.25_real64, mass_tolerance=1.0e-12_real64
  integer(int64), parameter :: column_id=427002_int64
  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_forcing_t) :: forcing
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(canonical_numerical_config_t) :: config
  type(kernel_committed_state_t) :: committed_off, committed_on
  type(kernel_checkpoint_t) :: checkpoint_off, checkpoint_on
  type(kernel_result_t) :: result_off, result_on
  type(kernel_candidate_state_t) :: candidate_off, candidate_on
  type(kernel_diagnostics_t) :: diagnostics_off, diagnostics_on
  type(fmr_serialized_reference_backend_t) :: backend_off, backend_on
  type(fixed_flux_top_boundary_provider_t), target :: top
  class(transaction_state_t), allocatable :: state_off, state_on
  real(real64) :: k0, qeq
  integer :: builds,hits,misses,entries
  logical :: ok,avail_off,avail_on

  call initialize_parameters(parameters)
  call determine_initial_conductivity(parameters,k0)
  qeq=-k0
  call initialize_forcing(forcing,qeq)
  call initialize_column_template(column,template)
  call initialize_config(config)

  call initialize_committed(committed_off,parameters,ok); call require(ok,'off state')
  call fmr_capture_checkpoint(committed_off,checkpoint_off,ok); call require(ok,'off checkpoint')
  call backend_off%initialize(top)
  call backend_off%run_trial(column,template,parameters,committed_off,forcing,config,0.0_real64,duration, &
       checkpoint_off,result_off,candidate_off,diagnostics_off)
  call require(result_off%status==CANONICAL_STATUS_COMPLETED .and. result_off%completed,'off completed')

  parameters%adaptive_hydraulics_active=.true.
  call initialize_committed(committed_on,parameters,ok); call require(ok,'on state')
  call fmr_capture_checkpoint(committed_on,checkpoint_on,ok); call require(ok,'on checkpoint')
  call backend_on%initialize(top)
  call backend_on%run_trial(column,template,parameters,committed_on,forcing,config,0.0_real64,duration, &
       checkpoint_on,result_on,candidate_on,diagnostics_on)
  call require(result_on%status==CANONICAL_STATUS_COMPLETED .and. result_on%completed,'on completed')

  call require(candidate_off%ready().and.candidate_on%ready(),'candidates ready')
  call require(result_off%mass%complete.and.result_on%mass%complete,'mass complete')
  call require(abs(result_off%mass%residual)<=mass_tolerance.and.abs(result_on%mass%residual)<=mass_tolerance,'mass gate')
  call candidate_off%snapshot(state_off,avail_off); call candidate_on%snapshot(state_on,avail_on)
  call require(avail_off.and.avail_on,'snapshots')
  call require_physical_identity(state_off,state_on)
  call require(same_bits(result_off%mass%storage_start,result_on%mass%storage_start).and. &
       same_bits(result_off%mass%storage_end,result_on%mass%storage_end).and. &
       same_bits(result_off%mass%total_in,result_on%mass%total_in).and. &
       same_bits(result_off%mass%total_out,result_on%mass%total_out).and. &
       same_bits(result_off%mass%residual,result_on%mass%residual),'mass bit identity')
  call require(diagnostics_off%nonlinear_iterations==diagnostics_on%nonlinear_iterations,'iteration identity')
  call require(diagnostics_off%backtracking_attempts==diagnostics_on%backtracking_attempts,'backtracking identity')

  call b110_adaptive_hydraulic_cache_stats(builds,hits,misses,entries)
  call require(builds==0.and.hits==0.and.misses==0.and.entries==0,'adaptive cache untouched')
  write(*,'(A,I0,A,I0,A,I0,A,I0)') 'FAHL27_QBOT_CACHE BUILDS=',builds,' HITS=',hits,' MISSES=',misses,' ENTRIES=',entries
  write(*,'(A)') 'FAHL27_QBOT_DEFAULT_OFF_IDENTITY=PASS'
  write(*,'(A)') 'FAHL27_QBOT_ANALYTICAL_FALLBACK=PASS'

contains
  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer::i
    p%parameter_set_id=427002_int64;p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod);p%cofgen=0.0_real64
    do i=1,numnod
      p%cofgen(1,i)=0.032_real64;p%cofgen(2,i)=0.423_real64;p%cofgen(3,i)=4.75_real64
      p%cofgen(4,i)=0.0135_real64;p%cofgen(5,i)=0.365_real64;p%cofgen(6,i)=1.455_real64
      p%cofgen(7,i)=1.0_real64-1.0_real64/p%cofgen(6,i);p%cofgen(8,i)=p%cofgen(4,i)
      p%cofgen(9,i)=0.0_real64;p%cofgen(10,i)=p%cofgen(3,i);p%cofgen(11,i)=0.999_real64
      p%cofgen(12,i)=0.99_real64*p%cofgen(3,i);p%cofgen(22,i)=-1.0e6_real64;p%cofgen(23,i)=1.0e-12_real64
    end do
    p%bottom_mode=2;p%swkimpl=0;p%swkmean=1;p%swsophy=0
    p%max_iterations=16;p%max_backtracking=8;p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=mass_tolerance;p%total_balance_tolerance=mass_tolerance
    p%head_abs_tolerance=mass_tolerance;p%head_rel_tolerance=mass_tolerance;p%ponding_tolerance=mass_tolerance
    p%root_extraction_active=.false.;p%macropore_active=.false.;p%snow_active=.false.
    p%hysteresis_active=.false.;p%tabulated_hydraulics_active=.false.;p%adaptive_hydraulics_active=.false.
    p%elasticity_active=.false.;p%frost_active=.false.;p%soil_temperature_active=.false.;p%drainage_response_active=.false.
  end subroutine

  subroutine determine_initial_conductivity(p,k)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    real(real64),intent(out)::k
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::h(numnod),w(numnod),kk(numnod),cc(numnod),dk(numnod)
    call initialize_b110_default_mvg_parameters(hp,p%cofgen);call bind_b110_default_mvg_provider(provider,hp,duration)
    h=h0;call provider%evaluate(h,w,kk,cc,dk);k=kk(1)
  end subroutine

  subroutine initialize_forcing(f,q)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    real(real64),intent(in)::q
    f%top_flux=q;f%top_head=h0;f%bottom_flux=q;f%bottom_head=-999999.0_real64
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64;f%subsurface_irrigation_source=0.0_real64;f%root_extraction_sink=0.0_real64
  end subroutine

  subroutine initialize_column_template(col,t)
    type(fmr_logical_column_t),intent(out)::col;type(fmr_template_t),intent(out)::t
    t%template_id=427001_int64;t%physics_topology_id=427002_int64;t%vertical_layout_id=427003_int64
    t%state_layout_id=427004_int64;t%solver_interface_id=427005_int64;t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE;t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    col%column_id=column_id;col%template_id=t%template_id;col%parameter_ref=1_int64;col%state_handle=1_int64
    col%forcing_handle=1_int64;col%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine

  subroutine initialize_config(cfg)
    type(canonical_numerical_config_t),intent(out)::cfg
    cfg%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF;cfg%transaction%temporal_tolerance=1.0e-6_real64
    cfg%transaction%mass_tolerance=mass_tolerance;cfg%transaction%retry_scale=0.5_real64;cfg%transaction%max_retries=8
    cfg%max_committed_substeps=32;cfg%progress_tolerance=0.0_real64
    cfg%model_temporal_indicator_budget_available=.false.;cfg%model_temporal_indicator_budget=0.0_real64
    cfg%accepted_trajectory_direction%requested=.false.
  end subroutine

  subroutine initialize_committed(c,p,ok)
    type(kernel_committed_state_t),intent(out)::c;type(fmr_b110_physical_parameters_t),intent(in)::p;logical,intent(out)::ok
    type(fmr_b110_physical_state_t)::st
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::h(numnod),w(numnod),kk(numnod),cc(numnod),dk(numnod)
    h=h0;call initialize_b110_default_mvg_parameters(hp,p%cofgen);call bind_b110_default_mvg_provider(provider,hp,duration)
    call provider%evaluate(h,w,kk,cc,dk)
    st%active_nodes=numnod;allocate(st%pressure_head(numnod),st%water_content(numnod))
    st%pressure_head=h;st%water_content=w;st%ponding_depth=0.0_real64;st%groundwater_level=-2.0_real64
    call fmr_new_b110_committed_state(c,column_id,st,0.0_real64,ok)
  end subroutine

  subroutine require_physical_identity(a,b)
    class(transaction_state_t),intent(in)::a,b
    select type(x=>a);type is(fmr_b110_physical_state_t)
      select type(y=>b);type is(fmr_b110_physical_state_t)
        call require(x%active_nodes==y%active_nodes,'node identity')
        call require(same_vector_bits(x%pressure_head,y%pressure_head),'head identity')
        call require(same_vector_bits(x%water_content,y%water_content),'water identity')
        call require(same_bits(x%ponding_depth,y%ponding_depth),'ponding identity')
        call require(same_bits(x%groundwater_level,y%groundwater_level),'gwl identity')
      class default;call require(.false.,'state type on')
      end select
    class default;call require(.false.,'state type off')
    end select
  end subroutine
  pure logical function same_bits(a,b);real(real64),intent(in)::a,b;same_bits=transfer(a,0_int64)==transfer(b,0_int64);end function
  pure logical function same_vector_bits(a,b)
    real(real64),intent(in)::a(:),b(:);integer::i
    same_vector_bits=.false.;if(size(a)/=size(b))return
    do i=1,size(a);if(.not.same_bits(a(i),b(i)))return;end do;same_vector_bits=.true.
  end function
  subroutine require(ok,msg);logical,intent(in)::ok;character(len=*),intent(in)::msg
    if(.not.ok)then;write(*,'(A,1X,A)')'FAHL27_QBOT_FAIL',trim(msg);error stop 1;end if
  end subroutine
end program test_fahl27_stage2_qbot_fallback_direct
