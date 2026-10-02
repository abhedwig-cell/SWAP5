module mod_strip01_research_swap
  use iso_c_binding, only: c_double,c_int
  use iso_fortran_env, only: int64,real64
  use MOD_grid, only: numnod,z,dz,disnod
  use mod_transaction_reference, only: transaction_state_t,TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t,canonical_forcing_t
  use mod_kernel_transactions, only: kernel_committed_state_t,kernel_checkpoint_t,kernel_result_t, &
       kernel_candidate_state_t,kernel_diagnostics_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t,fmr_template_t,FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t,fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t,fmr_serialized_reference_backend_t,fmr_new_b110_temporal_indicator_committed_state, &
       fmr_serialized_physical_observation_t,prepare_fmr_b110_default_mvg
  use mod_fmr_groundwater_head_forcing_adapter, only: fmr_groundwater_head_forcing_materializer_t
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t,b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters,bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none
  integer,parameter::NC=50
  type(fmr_b110_physical_parameters_t),save::p(NC)
  type(fmr_b110_physical_forcing_t),save::base(NC)
  type(fmr_logical_column_t),save::col(NC)
  type(fmr_template_t),save::tmpl(NC)
  type(kernel_committed_state_t),save::state(NC)
  type(kernel_checkpoint_t),save::origin(NC)
  type(kernel_candidate_state_t),save::candidate(NC)
  type(kernel_result_t),save::result(NC)
  type(kernel_diagnostics_t),save::diag(NC)
  type(fmr_serialized_reference_backend_t),save::backend(NC)
  type(fmr_groundwater_head_forcing_materializer_t),save::materializer(NC)
  type(fixed_flux_top_boundary_provider_t),target,save::top(NC)
  type(canonical_numerical_config_t),save::config
  type(groundwater_head_datum_t),save::datum
  real(real64),save::t0=0,t1=0
contains
  integer(c_int) function strip_initialize(rain_cm_day,initial_head_m,elastic_per_cm) bind(C,name="strip_initialize")
    real(c_double),value::rain_cm_day,initial_head_m,elastic_per_cm
    type(fmr_b110_physical_state_t)::physical
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::heads(numnod),water(numnod),k(numnod),c(numnod),dk(numnod),history(numnod)
    integer::i
    logical::ok
    strip_initialize=1
    config%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    config%transaction%temporal_tolerance=0
    config%transaction%mass_tolerance=1e-12_real64
    config%transaction%max_retries=8;config%transaction%retry_scale=0.5_real64
    config%max_committed_substeps=32;config%progress_tolerance=0
    config%model_temporal_indicator_budget_available=.true.
    config%model_temporal_indicator_budget=1e-5_real64
    datum%available=.true.;datum%datum_id=81001_int64;datum%bottom_boundary_elevation_m=-6
    heads=100.0_real64*initial_head_m-z;history=0
    do i=1,NC
      p(i)%parameter_set_id=81000_int64+i;p(i)%active_nodes=numnod
      allocate(p(i)%z(numnod),p(i)%dz(numnod),p(i)%node_distance(numnod),p(i)%cofgen(24,numnod))
      p(i)%z=z;p(i)%dz=dz;p(i)%node_distance=disnod(1:numnod);p(i)%cofgen=0
      p(i)%cofgen(1,:)=.02_real64;p(i)%cofgen(2,:)=.427494_real64;p(i)%cofgen(3,:)=31.225016_real64
      p(i)%cofgen(4,:)=.021659_real64;p(i)%cofgen(5,:)=.98087_real64;p(i)%cofgen(6,:)=1.734737_real64
      p(i)%cofgen(7,:)=1-1/p(i)%cofgen(6,:);p(i)%cofgen(8,:)=p(i)%cofgen(4,:)
      p(i)%cofgen(10,:)=p(i)%cofgen(3,:);p(i)%cofgen(11,:)=.999_real64
      p(i)%cofgen(12,:)=.99_real64*p(i)%cofgen(3,:);p(i)%cofgen(22,:)=-1e6_real64;p(i)%cofgen(23,:)=1e-12_real64
      p(i)%elasticity_active=elastic_per_cm>0;p(i)%cofgen(24,:)=elastic_per_cm
      p(i)%bottom_mode=5;p(i)%swkimpl=0;p(i)%swkmean=1;p(i)%swsophy=0
      p(i)%max_iterations=16;p(i)%max_backtracking=8;p(i)%min_step_duration=1e-8_real64
      p(i)%compartment_balance_tolerance=1e-12_real64;p(i)%total_balance_tolerance=1e-12_real64
      p(i)%head_abs_tolerance=1e-12_real64;p(i)%head_rel_tolerance=1e-12_real64;p(i)%ponding_tolerance=1e-12_real64
      call prepare_fmr_b110_default_mvg(p(i),ok);if(.not.ok)return
      base(i)%top_flux=-rain_cm_day;base(i)%bottom_head=100.0_real64*(initial_head_m+6.0_real64)
      allocate(base(i)%drainage_flux_by_level(1,numnod),base(i)%subsurface_irrigation_source(numnod), &
               base(i)%root_extraction_sink(numnod))
      base(i)%drainage_flux_by_level=0;base(i)%subsurface_irrigation_source=0;base(i)%root_extraction_sink=0
      tmpl(i)%template_id=82000_int64+i;tmpl(i)%physics_topology_id=82001_int64
      tmpl(i)%vertical_layout_id=82002_int64;tmpl(i)%state_layout_id=82003_int64;tmpl(i)%solver_interface_id=82004_int64
      tmpl(i)%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
      tmpl(i)%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
      col(i)%column_id=83000_int64+i;col(i)%template_id=tmpl(i)%template_id
      col(i)%parameter_ref=i;col(i)%state_handle=i;col(i)%forcing_handle=i;col(i)%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
      hp=p(i)%prepared_default_mvg
      call bind_b110_default_mvg_provider(provider,hp,1e-4_real64)
      call provider%evaluate(heads,water,k,c,dk)
      physical=fmr_b110_physical_state_t();physical%active_nodes=numnod
      allocate(physical%pressure_head(numnod),physical%water_content(numnod))
      physical%pressure_head=heads;physical%water_content=water
      physical%groundwater_level=100.0_real64*initial_head_m;physical%ponding_depth=0
      call fmr_new_b110_temporal_indicator_committed_state(state(i),col(i)%column_id,physical,0.0_real64,ok,history)
      if(.not.ok)return
      call backend(i)%initialize(top(i))
      call materializer(i)%initialize(base(i))
    end do
    strip_initialize=0
  end function

  integer(c_int) function strip_begin(dt) bind(C,name="strip_begin")
    real(c_double),value::dt
    integer::i
    logical::ok
    strip_begin=1
    call state(1)%current_time(t0,ok);if(.not.ok)return
    t1=t0+dt
    do i=1,NC
      call state(i)%capture_checkpoint(origin(i),ok);if(.not.ok)return
    end do
    strip_begin=0
  end function

  integer(c_int) function strip_trial(head,q,delta,residual) bind(C,name="strip_trial")
    real(c_double),intent(in)::head(NC)
    real(c_double),intent(out)::q(NC),delta(NC),residual(NC)
    class(canonical_forcing_t),allocatable::forcing
    type(fmr_serialized_physical_observation_t)::observation
    integer::i,status
    strip_trial=1;q=0;delta=0;residual=huge(0.0_real64)
    do i=1,NC
      if(candidate(i)%ready())call backend(i)%discard_trial_candidate(candidate(i),diag(i))
      call materializer(i)%materialize(real(head(i),real64),datum,forcing,status)
      if(status/=0)then
        strip_trial=100+i;return
      end if
      select type(typed=>forcing)
      type is(fmr_b110_physical_forcing_t)
        call backend(i)%run_trial(col(i),tmpl(i),p(i),state(i),typed,config,t0,t1,origin(i),result(i),candidate(i),diag(i))
      class default
        strip_trial=150+i;return
      end select
      if(.not.result(i)%completed)then
        print *, 'STRIP_TRIAL_FAIL',i,result(i)%status,diag(i)%transaction_calls
        print *, 'STRIP_REJECTIONS',diag(i)%solver_rejections,diag(i)%temporal_rejections, &
                 diag(i)%temporal_certificate_unavailable_rejections,diag(i)%mass_rejections, &
                 diag(i)%attempts,diag(i)%admission_rejections,diag(i)%max_temporal_indicator
        observation=backend(i)%observation()
        print *, 'STRIP_OBSERVATION',observation%solver_status,observation%top_flux,observation%bottom_flux, &
                 observation%temporal_head_inf_bound,observation%temporal_head_budget, &
                 observation%temporal_certificate_unavailable_reason
        strip_trial=200+i;return
      end if
      if(.not.result(i)%bottom_interface_exchange_available)then
        strip_trial=300+i;return
      end if
      q(i)=.01_real64*result(i)%bottom_outward_exchange_native/(t1-t0)
      delta(i)=.01_real64*result(i)%mass%storage_change
      residual(i)=.01_real64*result(i)%mass%residual
    end do
    strip_trial=0
  end function

  integer(c_int) function strip_commit() bind(C,name="strip_commit")
    integer::i,status
    logical::committed
    strip_commit=1
    do i=1,NC
      if(.not.candidate(i)%ready())return
    end do
    do i=1,NC
      call backend(i)%commit_trial_candidate(state(i),candidate(i),diag(i),committed,status)
      if(.not.committed.or.status/=0)error stop 'STRIP late research commit failure'
    end do
    strip_commit=0
  end function

  integer(c_int) function strip_state(revision,time,storage,gwl) bind(C,name="strip_state")
    integer(c_int),intent(out)::revision(NC)
    real(c_double),intent(out)::time(NC),storage(NC),gwl(NC)
    class(transaction_state_t),allocatable::snapshot
    integer::i
    logical::ok
    strip_state=1
    do i=1,NC
      revision(i)=int(state(i)%current_revision(),c_int)
      call state(i)%current_time(time(i),ok);if(.not.ok)return
      call state(i)%snapshot(snapshot,ok);if(.not.ok)return
      select type(s=>snapshot)
      class is(fmr_b110_physical_state_t)
        storage(i)=.01_real64*(sum(s%water_content*dz)+s%ponding_depth)
        gwl(i)=.01_real64*s%groundwater_level
      class default
        return
      end select
    end do
    strip_state=0
  end function
end module
