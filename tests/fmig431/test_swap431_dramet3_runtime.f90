program test_swap431_dramet3_runtime
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: legacy_melt => melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot
  use mod_transaction_reference, only: transaction_state_t, TX_MASS_MISSING_NONE, TX_TEMPORAL_MODEL_CERTIFICATE, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_new_b110_temporal_indicator_committed_state, &
       fmr_b110_temporal_indicator_state_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK, FMR_SERIAL_DISPATCH_INVALID_REQUEST
  use mod_fmr_divdra_serialized_runtime, only: fmr_divdra_serialized_column_request_t, &
       fmr_divdra_serialized_binding_record_t, fmr_run_serialized_physical_multiswap_with_divdra
  use mod_fmr_divdra_serialized_composition, only: FMR_DIVDRA_COMPOSE_OK, FMR_DIVDRA_COMPOSE_INVALID_SHAPE, &
       FMR_DIVDRA_COMPOSE_COLUMN_ID_MISMATCH, FMR_DIVDRA_COMPOSE_SHARED_FORCING_HANDLE, &
       FMR_DIVDRA_COMPOSE_INVALID_PARAMETER_REF, FMR_DIVDRA_COMPOSE_INVALID_HYDRAULIC_VIEW_REF, &
       FMR_DIVDRA_COMPOSE_BIND_REJECTED
  use mod_fmr_divdra_runtime_binding, only: fmr_divdra_binding_diagnostics_t, &
       fmr_bind_single_level_signed_divdra, FMR_DIVDRA_BIND_OK
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t, fmr_export_committed_restart, &
       fmr_restore_committed_restart,FMR_RESTART_OK
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fmr_drainage_response_binding
  use mod_drainage_dramet3_response
  use mod_fmr_serialized_reference_backend,only:fmr_serialized_reference_backend_t,fmr_serialized_physical_observation_t
  use mod_fmr_serialized_multiswap_runtime,only:fmr_execute_serialized_resolved_physical_column,fmr_serialized_batch_diagnostics_t
  use mod_kernel_transactions,only:kernel_executor_t
  implicit none
  real(real64),parameter::qa_t0=7312.0625_real64,qa_t1=7312.3125_real64,qa_head=-123._real64,mass_gate=1.e-12_real64
  integer(int64),parameter::id1=510001_int64,id2=510002_int64
  integer::test_bottom_mode,levels,allocation,kind,cap,pattern,cases
  cases=0
  do test_bottom_mode=2,7,5
  do levels=1,3,2
  do allocation=1,3
  do kind=1,2
  do cap=0,1
  do pattern=1,3
    call verify_case()
    cases=cases+1
  end do
  end do
  end do
  end do
  end do
  call verify_lifecycle()
  call verify_two_columns()
  end do
  call verify_invalid()
  print '(A,I0)','DRAMET3_ACTUAL_RICHARDS_CASES=',cases
  print '(A)','DRAMET3_REAL_TRIAL_RUNTIME=PASS'
contains
  subroutine enable_native(p,f)
    type(fmr_b110_physical_parameters_t),intent(inout)::p
    type(fmr_b110_physical_forcing_t),intent(inout)::f
    integer::l,st
    real(real64)::base
    p%drainage_response_active=.true.
    allocate(p%drainage_response_levels(levels),f%drainage_response_controls(levels))
    deallocate(f%drainage_flux_by_level)
    do l=1,levels
      p%drainage_response_levels(l)%variant=FMR_DRAIN_VARIANT_DRAMET3
      p%drainage_response_levels(l)%dramet3%drain_bottom_cm=-4._real64
      p%drainage_response_levels(l)%dramet3%drainage_resistance_day=10000._real64*l
      p%drainage_response_levels(l)%dramet3%infiltration_resistance_day=23000._real64*l
      p%drainage_response_levels(l)%dramet3%allocation_mode=1+mod(allocation+l-2,3)
      p%drainage_response_levels(l)%dramet3%drain_type=kind
      p%drainage_response_levels(l)%dramet3%limit_channel_infiltration=cap==1
      base=-3.5_real64
      if(pattern==2)base=-1.0_real64
      if(pattern==3)base=-2.25_real64+.5_real64*(l-2)
      call initialize_dramet3_channel_control(p%drainage_response_levels(l)%dramet3_channel,qa_t0,40000._real64, &
           [40000._real64,40000.25_real64,40000.5_real64],[base,base+.25_real64,base-.25_real64],st)
      call require(st==0,'native channel initialization')
    end do
  end subroutine
  subroutine execute(c,t,p,f,s,cfg,start,finish,r,o)
    type(fmr_logical_column_t),intent(in)::c
    type(fmr_template_t),intent(in)::t
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(fmr_b110_physical_forcing_t),intent(in)::f
    type(kernel_committed_state_t),intent(inout)::s
    type(canonical_numerical_config_t),intent(in)::cfg
    real(real64),intent(in)::start,finish
    type(fmr_serialized_column_result_t),intent(out)::r
    type(fmr_serialized_physical_observation_t),intent(out)::o
    type(fmr_serialized_reference_backend_t)::backend
    type(kernel_executor_t)::executor
    type(fixed_flux_top_boundary_provider_t),target::top
    type(fmr_column_diagnostics_t)::d
    type(fmr_serialized_batch_diagnostics_t)::runtime
    integer::active
    active=0;r=fmr_serialized_column_result_t();r%column_id=c%column_id;r%requested_t0=start;r%requested_t1=finish
    call reset_legacy();call backend%initialize(top)
    call fmr_execute_serialized_resolved_physical_column(backend,executor,c,t,p,f,s,cfg,start,finish,r,d,runtime,active)
    o=backend%observation()
    call require(active==0,'no live worker remains')
  end subroutine
  subroutine verify_case()
    type(fmr_logical_column_t)::c(1)
    type(fmr_template_t)::t(1)
    type(fmr_b110_physical_parameters_t)::p(1)
    type(fmr_b110_physical_forcing_t)::f(1)
    type(kernel_committed_state_t)::s(1),half(1),clean(1)
    type(canonical_numerical_config_t)::cfg
    type(fmr_serialized_column_result_t)::r,replay,h1,h2
    type(fmr_serialized_physical_observation_t)::o
    real(real64)::query,channel
    integer::l,st
    call initialize_one(c,t,p,f,s,cfg);call enable_native(p(1),f(1));clean=s;half=s
    call execute(c(1),t(1),p(1),f(1),s(1),cfg,qa_t0,qa_t1,r,o)
    if(.not.r%committed)print *, 'NATIVE_DEBUG',levels,allocation,kind,cap,pattern,r%kernel_status,r%admission_status,r%mass%residual
    call require(r%committed.and.r%solver_executed.and.r%mass%complete,'actual Richards accepted')
    call require(abs(r%mass%residual)<=mass_gate,'hard mass')
    call require(o%drainage_response_active.and.o%drainage_response_mass_accounted_in_trial,'single existing ledger')
    call require(.not.o%frost_drainage_executed,'ordinary frost OFF')
    call require(o%drainage_response_evaluations>=1,'actual trial evaluation')
    do l=1,levels
      call p(1)%drainage_response_levels(l)%dramet3_channel%evaluate(qa_t1,query,channel,st)
      call require(o%drainage_response%level(l)%dramet3%legacy_query_t1900==query,'actual endpoint query')
      call require(o%drainage_response%level(l)%dramet3%resolved_channel_head_cm==max(-4._real64,channel),'actual endpoint OWLTAB')
    end do
    call execute(c(1),t(1),p(1),f(1),clean(1),cfg,qa_t0,qa_t1,replay,o)
    call require(same_result(r,replay).and.states_equal(s(1),clean(1)),'clean exact replay')
    call execute(c(1),t(1),p(1),f(1),half(1),cfg,qa_t0,(qa_t0+qa_t1)*.5_real64,h1,o)
    call require(h1%committed,'half interval accepted')
    do l=1,levels
      call p(1)%drainage_response_levels(l)%dramet3_channel%evaluate((qa_t0+qa_t1)*.5_real64,query,channel,st)
      call require(o%drainage_response%level(l)%dramet3%legacy_query_t1900==query,'half endpoint independent')
    end do
    call execute(c(1),t(1),p(1),f(1),half(1),cfg,(qa_t0+qa_t1)*.5_real64,qa_t1,h2,o)
    call require(h2%committed.and.abs(h1%mass%residual)<=mass_gate.and.abs(h2%mass%residual)<=mass_gate,'split mass')
    print '(A,6I3)','DRAMET3_PHYSICAL=',test_bottom_mode,levels,allocation,kind,cap,pattern
  end subroutine
  subroutine verify_lifecycle()
    type(fmr_logical_column_t)::c(1)
    type(fmr_template_t)::t(1)
    type(fmr_b110_physical_parameters_t)::p(1)
    type(fmr_b110_physical_forcing_t)::f(1)
    type(kernel_committed_state_t)::s(1),clean(1),restored(1)
    type(canonical_numerical_config_t)::cfg,badcfg
    type(fmr_serialized_column_result_t)::r,fresh,continued
    type(fmr_serialized_physical_observation_t)::o
    type(fmr_committed_restart_bundle_t)::bundle
    integer::st
    logical::ok
    levels=3;allocation=1;kind=2;cap=1;pattern=3
    call initialize_one(c,t,p,f,s,cfg);call enable_native(p(1),f(1));clean=s
    badcfg=cfg;badcfg%transaction%temporal_tolerance=1.e-30_real64;badcfg%transaction%max_retries=0
    badcfg%model_temporal_indicator_budget=1.e-30_real64
    call execute(c(1),t(1),p(1),f(1),s(1),badcfg,qa_t0,qa_t1,r,o)
    call require(.not.r%committed.and.r%solver_executed.and.r%temporal_rejections>0,'real rejected candidate')
    call require(states_equal(s(1),clean(1)).and.s(1)%current_revision()==0_int64,'rejected committed state exact')
    call execute(c(1),t(1),p(1),f(1),s(1),cfg,qa_t0,qa_t1,r,o)
    call execute(c(1),t(1),p(1),f(1),clean(1),cfg,qa_t0,qa_t1,fresh,o)
    call require(r%committed.and.same_result(r,fresh).and.states_equal(s(1),clean(1)),'rejected retry clean')
    call fmr_export_committed_restart(c,t,s,p(1)%parameter_set_id,bundle,ok,st)
    call require(ok.and.st==FMR_RESTART_OK,'committed restart export')
    call fmr_restore_committed_restart(bundle,p(1)%parameter_set_id,c,t,restored,ok,st)
    call require(ok.and.st==FMR_RESTART_OK,'empty registry restart restore')
    call execute(c(1),t(1),p(1),f(1),s(1),cfg,qa_t1,qa_t1+qa_t1-qa_t0,r,o)
    call execute(c(1),t(1),p(1),f(1),restored(1),cfg,qa_t1,qa_t1+qa_t1-qa_t0,continued,o)
    call require(r%committed.and.continued%committed.and.same_result(r,continued),'restart exact result')
    call require(states_equal(s(1),restored(1)).and.abs(r%mass%residual)<=mass_gate,'restart exact state/mass')
    print '(A,I0)','DRAMET3_REJECT_REPLAY_RESTART=PASS BOTTOM=',test_bottom_mode
  end subroutine
  subroutine verify_two_columns()
    type(fmr_logical_column_t)::c(2)
    type(fmr_template_t)::t(1)
    type(fmr_b110_physical_parameters_t)::p(1)
    type(fmr_b110_physical_forcing_t)::f(2)
    type(kernel_committed_state_t)::s(2),clean(2)
    type(canonical_numerical_config_t)::cfg
    type(fmr_serialized_column_result_t),allocatable::r(:)
    type(fmr_serialized_column_result_t)::fresh
    type(fmr_serialized_physical_observation_t)::o
    type(fmr_column_diagnostics_t),allocatable::d(:)
    type(fmr_aggregate_diagnostics_t)::a
    type(fixed_flux_top_boundary_provider_t),target::top
    integer::dispatch,k
    call initialize_two(c,t,p,f,s,cfg);call enable_native(p(1),f(1));f(2)=f(1)
    f(2)%bottom_flux=f(2)%bottom_flux+1.e-5_real64;clean=s
    call reset_legacy()
    call fmr_run_serialized_physical_multiswap(c,t,p,f,s,cfg,top,qa_t0,qa_t1,1,r,d,a,dispatch)
    call require(dispatch==FMR_SERIAL_DISPATCH_OK.and.all(r%committed),'two columns accepted')
    do k=1,2
      call execute(c(k),t(1),p(1),f(k),clean(k),cfg,qa_t0,qa_t1,fresh,o)
      call require(same_result(r(k),fresh).and.states_equal(s(k),clean(k)),'column isolation exact')
    end do
    print '(A,I0)','DRAMET3_TWO_COLUMN_ISOLATION=PASS BOTTOM=',test_bottom_mode
  end subroutine
  subroutine verify_invalid()
    type(fmr_logical_column_t)::c(1)
    type(fmr_template_t)::t(1)
    type(fmr_b110_physical_parameters_t)::p(1),bad(1)
    type(fmr_b110_physical_forcing_t)::f(1),bf(1)
    type(kernel_committed_state_t)::s(1),clean(1)
    type(canonical_numerical_config_t)::cfg
    type(fmr_serialized_column_result_t)::r
    type(fmr_serialized_physical_observation_t)::o
    integer::k
    test_bottom_mode=2
    call initialize_one(c,t,p,f,s,cfg);call enable_native(p(1),f(1));clean=s
    do k=1,4
      bad=p;bf=f
      select case(k)
      case(1);bad(1)%drainage_response_levels(1)%dramet3%allocation_mode=0
      case(2);bf(1)%drainage_response_controls(1)%drain_head_supplied=.true.
      case(3);allocate(bf(1)%drainage_flux_by_level(1,numnod));bf(1)%drainage_flux_by_level=0._real64
      case(4);bad(1)%drainage_response_levels(1)%dramet3%infiltration_resistance_day=-1._real64
      end select
      call execute(c(1),t(1),bad(1),bf(1),s(1),cfg,qa_t0,qa_t1,r,o)
      call require(.not.r%committed.and..not.r%solver_executed.and.states_equal(s(1),clean(1)),'invalid pre-solver nonmutation')
    end do
    print '(A)','DRAMET3_INVALID_RUNTIME_PREMUTATION=4 PASS'
  end subroutine
  logical function states_equal(a,b) result(ok)
    type(kernel_committed_state_t),intent(in)::a,b
    class(transaction_state_t),allocatable::sa,sb
    logical::got,ha,hb
    real(real64),allocatable::da(:),db(:)
    call a%snapshot(sa,got);call require(got,'snapshot A')
    call b%snapshot(sb,got);call require(got,'snapshot B')
    ok=.false.
    select type(x=>sa)
    class is(fmr_b110_physical_state_t)
      select type(y=>sb)
      class is(fmr_b110_physical_state_t)
        ok=x%active_nodes==y%active_nodes.and.all(x%pressure_head==y%pressure_head).and. &
             all(x%water_content==y%water_content).and.x%ponding_depth==y%ponding_depth.and. &
             x%groundwater_level==y%groundwater_level
      end select
    end select
    select type(x=>sa)
    type is(fmr_b110_temporal_indicator_state_t)
      select type(y=>sb)
      type is(fmr_b110_temporal_indicator_state_t)
        call x%temporal_history_snapshot(da,ha);call y%temporal_history_snapshot(db,hb)
        ok=ok.and.(ha.eqv.hb)
        if(ha.and.hb)ok=ok.and.all(da==db)
      class default
        ok=.false.
      end select
    class default
      ok=.false.
    end select
  end function

  subroutine initialize_one(c,t,p,f,s,cfg)
    type(fmr_logical_column_t), intent(out) :: c(1)
    type(fmr_template_t), intent(out) :: t(1)
    type(fmr_b110_physical_parameters_t), intent(out) :: p(1)
    type(fmr_b110_physical_forcing_t), intent(out) :: f(1)
    type(kernel_committed_state_t), intent(out) :: s(1)
    type(canonical_numerical_config_t), intent(out) :: cfg
    type(fmr_b110_physical_state_t) :: state
    real(real64) :: k0
    logical :: ok
    call configure_parameters(p(1),state,k0)
    call configure_template(t(1)); call configure_column(c(1),id1,1_int64,t(1))
    call configure_forcing(f(1),k0); call configure_config(cfg)
    call fmr_new_b110_temporal_indicator_committed_state(s(1),id1,state,qa_t0,ok,[0._real64,0._real64,0._real64,0._real64]); call require(ok,'one state init')
  end subroutine initialize_one

  subroutine initialize_two(c,t,p,f,s,cfg)
    type(fmr_logical_column_t), intent(out) :: c(2)
    type(fmr_template_t), intent(out) :: t(1)
    type(fmr_b110_physical_parameters_t), intent(out) :: p(1)
    type(fmr_b110_physical_forcing_t), intent(out) :: f(2)
    type(kernel_committed_state_t), intent(out) :: s(2)
    type(canonical_numerical_config_t), intent(out) :: cfg
    type(fmr_b110_physical_state_t) :: state
    real(real64) :: k0
    logical :: ok
    call configure_parameters(p(1),state,k0); call configure_template(t(1)); call configure_config(cfg)
    call configure_column(c(1),id1,1_int64,t(1)); call configure_column(c(2),id2,2_int64,t(1))
    call configure_forcing(f(1),k0); call configure_forcing(f(2),k0)
    call fmr_new_b110_temporal_indicator_committed_state(s(1),id1,state,qa_t0,ok,[0._real64,0._real64,0._real64,0._real64]); call require(ok,'two state 1')
    call fmr_new_b110_temporal_indicator_committed_state(s(2),id2,state,qa_t0,ok,[0._real64,0._real64,0._real64,0._real64]); call require(ok,'two state 2')
  end subroutine initialize_two

  subroutine configure_template(t)
    type(fmr_template_t), intent(out) :: t
    t%template_id=510_int64; t%physics_topology_id=51011_int64; t%vertical_layout_id=51012_int64
    t%state_layout_id=51013_int64; t%solver_interface_id=51014_int64; t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_template

  subroutine configure_column(c,id,state_handle,t)
    type(fmr_logical_column_t), intent(out) :: c
    integer(int64), intent(in) :: id,state_handle
    type(fmr_template_t), intent(in) :: t
    c%column_id=id; c%template_id=t%template_id; c%parameter_ref=1_int64
    c%state_handle=state_handle; c%forcing_handle=state_handle; c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_column

  subroutine configure_parameters(p,state,k0)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: k0
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    integer :: k
    p%parameter_set_id=51001_int64; p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod); p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=0.032_real64; p%cofgen(2,k)=0.423_real64; p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64; p%cofgen(5,k)=0.365_real64; p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k); p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64; p%cofgen(10,k)=p%cofgen(3,k); p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k); p%cofgen(22,k)=-1.0e6_real64; p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=test_bottom_mode;p%max_iterations=40;p%min_step_duration=1.e-10_real64; p%swkimpl=0; p%swkmean=1; p%swsophy=0; p%root_extraction_active=.true.
    p%macropore_active=.false.; p%snow_active=.false.; p%hysteresis_active=.false.
    p%tabulated_hydraulics_active=.false.; p%elasticity_active=.false.; p%frost_active=.false.
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,qa_t1-qa_t0)
    heads=qa_head; call provider%evaluate(heads,water,conductivity,capacity,dkdh); k0=conductivity(1)
    state%active_nodes=numnod; allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water; state%ponding_depth=0.0_real64; state%groundwater_level=-2.25_real64
  end subroutine configure_parameters

  subroutine configure_forcing(f,k0)
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    real(real64), intent(in) :: k0
    f%top_flux=-k0; f%top_head=qa_head; f%bottom_flux=-k0; f%bottom_head=-321.0_real64
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64; f%subsurface_irrigation_source=0.0_real64; f%root_extraction_sink=0.0_real64
  end subroutine configure_forcing

  subroutine configure_config(cfg)
    type(canonical_numerical_config_t), intent(out) :: cfg
    cfg%model_temporal_indicator_budget_available=.true.;cfg%model_temporal_indicator_budget=1.e-6_real64
    cfg%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    cfg%transaction%temporal_tolerance=0.0_real64; cfg%transaction%mass_tolerance=mass_gate
    cfg%transaction%retry_scale=0.5_real64; cfg%transaction%max_retries=24
    cfg%max_committed_substeps=2048; cfg%progress_tolerance=0.0_real64
  end subroutine configure_config

  subroutine reset_legacy()
    legacy_qdra=88888.0_real64; legacy_qssdi=-77777.0_real64; legacy_qrot=66666.0_real64
    swmacro=0; legacy_melt=0.0_real64
  end subroutine reset_legacy

  logical function all_zero_revisions(s) result(ok)
    type(kernel_committed_state_t), intent(in) :: s(:)
    integer :: k
    ok=.true.
    do k=1,size(s)
      if (s(k)%current_revision()/=0_int64) then
        ok=.false.; return
      end if
    end do
  end function all_zero_revisions

  logical function same_result(a,b) result(equal)
    type(fmr_serialized_column_result_t), intent(in) :: a,b
    equal=a%column_id==b%column_id .and. a%kernel_status==b%kernel_status .and. a%commit_status==b%commit_status .and. &
      (a%completed.eqv.b%completed) .and. (a%committed.eqv.b%committed) .and. (a%solver_executed.eqv.b%solver_executed) .and. &
      a%solver_iterations==b%solver_iterations .and. a%initial_revision==b%initial_revision .and. &
      a%final_revision==b%final_revision .and. same_bits(a%final_committed_time,b%final_committed_time) .and. &
      (a%actual_transpiration_available.eqv.b%actual_transpiration_available) .and. &
      same_bits(a%actual_transpiration_amount,b%actual_transpiration_amount) .and. &
      (a%mass%complete.eqv.b%mass%complete) .and. a%mass%missing_contribution_mask==b%mass%missing_contribution_mask .and. &
      a%mass%origin_lineage_id==b%mass%origin_lineage_id .and. a%mass%origin_revision==b%mass%origin_revision .and. &
      a%mass%accepted_transaction_count==b%mass%accepted_transaction_count .and. &
      same_bits(a%mass%interval_t0,b%mass%interval_t0) .and. same_bits(a%mass%interval_t1,b%mass%interval_t1) .and. &
      same_bits(a%mass%storage_start,b%mass%storage_start) .and. same_bits(a%mass%storage_end,b%mass%storage_end) .and. &
      same_bits(a%mass%storage_change,b%mass%storage_change) .and. same_bits(a%mass%total_in,b%mass%total_in) .and. &
      same_bits(a%mass%total_out,b%mass%total_out) .and. same_bits(a%mass%residual,b%mass%residual)
  end function same_result

  logical function same_bits(a,b) result(equal)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia); ib=transfer(b,ib); equal=ia==ib
  end function same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not.condition) then
      write(*,'(A,1X,A)') 'SW431_SIGNED_TEST_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program
