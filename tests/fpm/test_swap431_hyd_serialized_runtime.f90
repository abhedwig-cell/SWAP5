program test_swap431_hyd_serialized_runtime
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_result_t, kernel_diagnostics_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_OPTIONAL_STATE_LAYOUT_BASE, FMR_NUMERICAL_CONTINUATION_NONE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b111_analytical_hydraulic_provider, only: b111_analytical_hydraulic_parameters_t, &
       b111_analytical_hydraulic_provider_t, initialize_b111_analytical_hydraulic_parameters, &
       bind_b111_analytical_hydraulic_provider, B111_HYD_EXPONENTIAL, B111_HYD_BIMODAL_MVG, &
       B111_HYD_BIMODAL_MVG_WCK
  use mod_fmr_serialized_reference_backend, only: fmr_serialized_reference_backend_t, &
       fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, fmr_b110_physical_state_t, &
       fmr_new_b110_committed_state, fmr_new_b110_temporal_indicator_committed_state, &
       fmr_b110_temporal_indicator_state_t, fmr_serialized_physical_observation_t
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t, fmr_export_committed_restart, &
       fmr_restore_committed_restart, FMR_RESTART_OK
  implicit none
  character(len=64)::mode

  call get_command_argument(1,mode)
  if(trim(mode)=='--legacy-identity')then
    ! Retain the original positive assertions as a dated negative diagnostic.
    ! Exact full/half identity is not the accepted model-certificate route.
    call exercise_model(B111_HYD_EXPONENTIAL,'MODEL2')
    call exercise_model(B111_HYD_BIMODAL_MVG,'MODEL3')
    call exercise_model(B111_HYD_BIMODAL_MVG_WCK,'MODEL6')
    call exercise_power()
    stop
  end if
  call certificate_envelope(B111_HYD_EXPONENTIAL,'MODEL2')
  call certificate_envelope(B111_HYD_BIMODAL_MVG,'MODEL3')
  call certificate_envelope(B111_HYD_BIMODAL_MVG_WCK,'MODEL6')
  call certificate_envelope(1,'POWER')
  call exercise_fail_closed_composition()
  print '(a)','SWAP431_HYD_CERTIFICATE_ALL_FOUR_PROFILES=PASS'
  print '(a)','SWAP431_HYD_SERIALIZED_RUNTIME=PASS'

contains

  subroutine certificate_envelope(kind,label)
    integer,intent(in)::kind
    character(len=*),intent(in)::label
    type(fmr_b110_physical_parameters_t),target::p
    type(fmr_b110_physical_state_t)::initial,predecessor
    type(b111_analytical_hydraulic_parameters_t),target::hp
    type(b111_analytical_hydraulic_provider_t)::provider
    type(b110_default_mvg_parameters_t),target::power_hp
    type(b110_default_mvg_provider_t)::power_provider
    type(fmr_serialized_reference_backend_t)::backend
    type(fixed_flux_top_boundary_provider_t),target::top
    type(fmr_b110_physical_forcing_t)::forcing
    type(fmr_logical_column_t)::column
    type(fmr_template_t)::template
    type(canonical_numerical_config_t)::numerical
    type(kernel_committed_state_t)::committed,history_state,registry(1),restored_registry(1)
    type(kernel_checkpoint_t)::checkpoint
    type(kernel_candidate_state_t)::candidate,replay_candidate
    type(kernel_result_t)::result,replay_result
    type(kernel_diagnostics_t)::diag
    type(fmr_serialized_physical_observation_t)::obs
    class(transaction_state_t),allocatable::snapshot,first,second
    type(fmr_committed_restart_bundle_t)::bundle
    real(real64),allocatable::theta(:),k(:),cap(:),dk(:),derivative(:),history(:)
    real(real64),parameter::dt=1.0e-5_real64
    logical::ok,available,did_commit
    integer::status

    call base_parameters(p)
    allocate(p%hydraulic_model_kind(numnod),theta(numnod),k(numnod),cap(numnod),dk(numnod))
    p%hydraulic_model_kind=kind
    if(kind==1)then
      deallocate(p%hydraulic_model_kind)
      p%conductivity_power_tail_active=.true.
      p%cofgen(22,:)=-100.0_real64
      ! Match the power-law transition K to the actual default MvG K.
      call initialize_b110_default_mvg_parameters(power_hp,p%cofgen)
      call bind_b110_default_mvg_provider(power_provider,power_hp,dt)
      call power_provider%evaluate(spread(-100.0_real64,1,numnod),theta,k,cap,dk)
      p%cofgen(23,:)=k
    else
      call initialize_b111_analytical_hydraulic_parameters(hp,p%hydraulic_model_kind,p%cofgen)
      call bind_b111_analytical_hydraulic_provider(provider,hp)
      call provider%evaluate(spread(-100.0_real64,1,numnod),theta,k,cap,dk)
    end if
    call base_state(initial,theta)
    call setup_execution(p,initial,forcing,column,template,numerical,committed,checkpoint,top,backend,ok)
    if(.not.ok)call stop_labeled(label//' predecessor setup')
    ! Uniform h and K: every gravity face has q=-K, including free drainage
    ! (headcalc mode7). Match the top face, then execute and commit the real
    ! predecessor. The subsequent rain-cessation trial remains dynamic.
    forcing%top_flux=-k(1)
    call backend%run_trial(column,template,p,committed,forcing,numerical,0.0_real64,dt,checkpoint,result,candidate,diag)
    if(.not.result%completed.or..not.candidate%ready())call stop_labeled(label//' actual predecessor')
    if(.not.result%mass%complete.or.abs(result%mass%residual)>1e-8_real64)call stop_labeled(label//' predecessor balance')
    call backend%commit_trial_candidate(committed,candidate,diag,did_commit,status)
    if(.not.did_commit)call stop_labeled(label//' predecessor commit')
    call committed%snapshot(snapshot,available)
    if(.not.available)call stop_labeled(label//' predecessor snapshot')
    select type(s=>snapshot)
    type is(fmr_b110_physical_state_t)
      predecessor=s
    class default
      call stop_labeled(label//' predecessor type')
    end select
    derivative=(predecessor%pressure_head-initial%pressure_head)/dt
    if(maxval(abs(predecessor%pressure_head-initial%pressure_head))>1e-10_real64) &
      call stop_labeled(label//' predecessor stationary balance')
    ! Seed only the measured derivative of the accepted real predecessor.
    call fmr_new_b110_temporal_indicator_committed_state(history_state,column%column_id,predecessor,dt,ok,derivative)
    if(.not.ok)call stop_labeled(label//' measured history')
    template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    numerical%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    numerical%transaction%temporal_tolerance=0.0_real64
    numerical%model_temporal_indicator_budget_available=.true.
    numerical%model_temporal_indicator_budget=1e-6_real64
    forcing%top_flux=0.0_real64
    call history_state%capture_checkpoint(checkpoint,ok)
    if(.not.ok)call stop_labeled(label//' history checkpoint')
    call backend%run_trial(column,template,p,history_state,forcing,numerical,dt,2*dt,checkpoint,result,candidate,diag)
    obs=backend%observation()
    write(*,'(*(g0))') 'SWAP431_HYD_CERTIFICATE_',label,'|COMPLETED=',result%completed, &
      '|SOLVER=',diag%solver_rejections,'|MASS=',diag%mass_rejections,'|TEMPORAL=',diag%temporal_rejections, &
      '|HISTORY=',obs%temporal_previous_derivative_available,'|BUDGET=',obs%temporal_head_budget_valid, &
      '|ROUTE=',trim(obs%temporal_indicator_route)
    block
      if(.not.result%completed.or..not.candidate%ready())call stop_labeled(label//' analytical dynamic trial')
      if(diag%temporal_rejections<1)call stop_labeled(label//' adaptive retry not exercised')
      if(.not.result%mass%complete.or.abs(result%mass%residual)>1e-8_real64) &
        call stop_labeled(label//' analytical dynamic mass')
      call candidate%snapshot(first,available)
      if(.not.available)call stop_labeled(label//' analytical candidate snapshot')
      select type(f=>first)
      type is(fmr_b110_temporal_indicator_state_t)
        if(maxval(abs(f%pressure_head-predecessor%pressure_head))<=1e-12_real64) &
          call stop_labeled(label//' dynamic profile did not change')
      class default
        call stop_labeled(label//' dynamic history carrier')
      end select
      ! A discarded physical trial must leave the measured predecessor unchanged.
      call history_state%snapshot(snapshot,available)
      select type(f=>snapshot)
      type is(fmr_b110_temporal_indicator_state_t)
        if(any(f%pressure_head/=predecessor%pressure_head))call stop_labeled(label//' discard changed committed head')
      class default
        call stop_labeled(label//' discard history carrier')
      end select
      call backend%run_trial(column,template,p,history_state,forcing,numerical,dt,2*dt,checkpoint, &
        replay_result,replay_candidate,diag)
      if(.not.replay_result%completed)call stop_labeled(label//' dynamic replay')
      call replay_candidate%snapshot(second,available)
      if(.not.available.or..not.same_history_state(first,second))call stop_labeled(label//' discard replay identity')
      call backend%commit_trial_candidate(history_state,candidate,diag,did_commit,status)
      if(.not.did_commit)call stop_labeled(label//' dynamic commit')
      registry(1)=history_state
      call fmr_export_committed_restart([column],[template],registry,p%parameter_set_id,bundle,ok,status)
      if(.not.ok.or.status/=FMR_RESTART_OK)call stop_labeled(label//' history restart export')
      call fmr_restore_committed_restart(bundle,p%parameter_set_id,[column],[template],restored_registry,ok,status)
      if(.not.ok.or.status/=FMR_RESTART_OK)call stop_labeled(label//' history restart restore')
      call restored_registry(1)%snapshot(second,available)
      call history_state%snapshot(first,available)
      if(.not.same_history_state(first,second))call stop_labeled(label//' restart physical/history identity')
      call history_state%capture_checkpoint(checkpoint,ok)
      call backend%run_trial(column,template,p,history_state,forcing,numerical,2*dt,3*dt,checkpoint, &
        result,candidate,diag)
      if(.not.result%completed.or..not.result%mass%complete.or.abs(result%mass%residual)>1e-8_real64) &
        call stop_labeled(label//' uninterrupted continuation mass')
      call candidate%snapshot(first,available)
      call restored_registry(1)%capture_checkpoint(checkpoint,ok)
      call backend%run_trial(column,template,p,restored_registry(1),forcing,numerical,2*dt,3*dt,checkpoint, &
        replay_result,replay_candidate,diag)
      if(.not.replay_result%completed)call stop_labeled(label//' restarted continuation')
      call replay_candidate%snapshot(second,available)
      if(.not.same_history_state(first,second))call stop_labeled(label//' restarted continuation identity')
      write(*,'(a,es24.16)')'SWAP431_HYD_ANALYTICAL_DYNAMIC_REPLAY_RESTART_'//label//'=PASS|MASS=',result%mass%residual
      write(*,'(a)')'SWAP431_HYD_RUNTIME_'//label//'=PASS'
    end block

  end subroutine certificate_envelope

  logical function same_history_state(a,b) result(same)
    class(transaction_state_t),intent(in)::a,b
    real(real64),allocatable::da(:),db(:)
    logical::aa_ok,bb_ok
    same=.false.
    select type(aa=>a)
    type is(fmr_b110_temporal_indicator_state_t)
      select type(bb=>b)
      type is(fmr_b110_temporal_indicator_state_t)
        same=all(aa%pressure_head==bb%pressure_head).and.all(aa%water_content==bb%water_content)
        same=same.and.aa%ponding_depth==bb%ponding_depth.and.aa%groundwater_level==bb%groundwater_level
        call aa%temporal_history_snapshot(da,aa_ok);call bb%temporal_history_snapshot(db,bb_ok)
        same=same.and.aa_ok.and.bb_ok
        if(same)same=all(da==db)
      end select
    end select
  end function same_history_state

  subroutine stop_labeled(message)
    character(len=*),intent(in)::message
    write(*,'(a)') trim(message)
    error stop 1
  end subroutine stop_labeled

  subroutine exercise_model(kind,label)
    integer,intent(in)::kind
    character(len=*),intent(in)::label
    type(fmr_b110_physical_parameters_t),target::p
    type(fmr_b110_physical_state_t)::initial
    type(b111_analytical_hydraulic_parameters_t),target::hp
    type(b111_analytical_hydraulic_provider_t)::provider
    real(real64),allocatable::theta(:),k(:),cap(:),dk(:)
    integer,allocatable::kinds(:)

    call base_parameters(p)
    allocate(p%hydraulic_model_kind(numnod),kinds(numnod),theta(numnod),k(numnod),cap(numnod),dk(numnod))
    p%hydraulic_model_kind=kind
    kinds=kind
    call initialize_b111_analytical_hydraulic_parameters(hp,kinds,p%cofgen)
    call bind_b111_analytical_hydraulic_provider(provider,hp)
    call provider%evaluate(spread(-100.0_real64,1,numnod),theta,k,cap,dk)
    call base_state(initial,theta)
    call execute_and_replay(p,initial,label)
  end subroutine exercise_model

  subroutine exercise_power()
    type(fmr_b110_physical_parameters_t),target::p
    type(fmr_b110_physical_state_t)::initial
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64),allocatable::theta(:),k(:),cap(:),dk(:)

    call base_parameters(p)
    p%conductivity_power_tail_active=.true.
    p%cofgen(22,:)=-100.0_real64
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,1.0e-5_real64)
    allocate(theta(numnod),k(numnod),cap(numnod),dk(numnod))
    call provider%evaluate(spread(-100.0_real64,1,numnod),theta,k,cap,dk)
    p%cofgen(23,:)=k
    call base_state(initial,theta)
    call execute_and_replay(p,initial,'POWER')
  end subroutine exercise_power

  subroutine exercise_fail_closed_composition()
    type(fmr_b110_physical_parameters_t),target::p
    type(fmr_b110_physical_state_t)::initial
    real(real64),allocatable::theta(:)
    type(b111_analytical_hydraulic_parameters_t),target::hp
    type(b111_analytical_hydraulic_provider_t)::provider
    real(real64),allocatable::k(:),cap(:),dk(:)
    integer,allocatable::kinds(:)

    call base_parameters(p)
    allocate(p%hydraulic_model_kind(numnod),kinds(numnod),theta(numnod),k(numnod),cap(numnod),dk(numnod))
    p%hydraulic_model_kind=B111_HYD_EXPONENTIAL
    p%conductivity_power_tail_active=.true.
    p%cofgen(22,:)=-100.0_real64
    p%cofgen(23,:)=1.0e-6_real64
    kinds=B111_HYD_EXPONENTIAL
    call initialize_b111_analytical_hydraulic_parameters(hp,kinds,p%cofgen)
    call bind_b111_analytical_hydraulic_provider(provider,hp)
    call provider%evaluate(spread(-100.0_real64,1,numnod),theta,k,cap,dk)
    call base_state(initial,theta)
    call expect_rejected(p,initial,'MODEL2+POWER')
  end subroutine exercise_fail_closed_composition

  subroutine base_parameters(p)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer::i
    p%parameter_set_id=643101_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod)
    p%cofgen=0.0_real64
    do i=1,numnod
      p%cofgen(1,i)=0.05_real64
      p%cofgen(2,i)=0.45_real64
      p%cofgen(3,i)=10.0_real64
      p%cofgen(4,i)=0.02_real64
      p%cofgen(5,i)=0.5_real64
      p%cofgen(6,i)=2.0_real64
      p%cofgen(7,i)=0.5_real64
      p%cofgen(8,i)=p%cofgen(4,i)
      p%cofgen(9,i)=0.0_real64
      p%cofgen(10,i)=p%cofgen(3,i)
      p%cofgen(11,i)=0.999_real64
      p%cofgen(12,i)=0.99_real64*p%cofgen(3,i)
      p%cofgen(13,i)=0.05_real64
      p%cofgen(14,i)=2.2_real64
      p%cofgen(15,i)=1.0_real64-1.0_real64/p%cofgen(14,i)
      p%cofgen(16,i)=0.65_real64
    end do
    p%bottom_mode=7
    p%swkimpl=0
    p%swkmean=1
    p%swsophy=0
    p%max_iterations=64
    p%max_backtracking=24
    p%min_step_duration=1.0e-12_real64
    p%compartment_balance_tolerance=1.0e-8_real64
    p%total_balance_tolerance=1.0e-8_real64
    p%head_abs_tolerance=1.0e-10_real64
    p%head_rel_tolerance=1.0e-10_real64
    p%ponding_tolerance=1.0e-10_real64
  end subroutine base_parameters

  subroutine base_state(initial,theta)
    type(fmr_b110_physical_state_t),intent(out)::initial
    real(real64),intent(in)::theta(:)
    initial%active_nodes=numnod
    allocate(initial%pressure_head(numnod),initial%water_content(numnod))
    initial%pressure_head=-100.0_real64
    initial%water_content=theta
    initial%ponding_depth=0.0_real64
    initial%groundwater_level=-200.0_real64
  end subroutine base_state

  subroutine execute_and_replay(p,initial,label)
    type(fmr_b110_physical_parameters_t),target,intent(in)::p
    type(fmr_b110_physical_state_t),intent(in)::initial
    character(len=*),intent(in)::label
    type(fmr_serialized_reference_backend_t)::backend
    type(fixed_flux_top_boundary_provider_t),target::top
    type(fmr_b110_physical_forcing_t)::forcing
    type(fmr_logical_column_t)::column
    type(fmr_template_t)::template
    type(canonical_numerical_config_t)::numerical
    type(kernel_committed_state_t)::committed
    type(kernel_checkpoint_t)::checkpoint
    type(kernel_candidate_state_t)::candidate,replay_candidate
    type(kernel_result_t)::result,replay_result
    type(kernel_diagnostics_t)::diag,replay_diag
    class(transaction_state_t),allocatable::before,after,candidate_state,replay_state
    logical::ok,available
    integer(int64),parameter::layout_id=643100_int64
    real(real64),parameter::dt=1.0e-5_real64

    call setup_execution(p,initial,forcing,column,template,numerical,committed,checkpoint,top,backend,ok)
    if(.not.ok)call stop_labeled(trim(label)//' setup')
    call committed%snapshot(before,available)
    if(.not.available)call stop_labeled(trim(label)//' before snapshot')

    call backend%run_trial(column,template,p,committed,forcing,numerical,0.0_real64,dt,checkpoint,result,candidate,diag)
    write(*,'(*(g0))') 'SWAP431_HYD_DIAGNOSTIC_',trim(label),'|ADMISSION=',diag%admission_rejections, &
      '|SOLVER=',diag%solver_rejections,'|TEMPORAL=',diag%temporal_rejections,'|MASS=',diag%mass_rejections, &
      '|ACCEPTED=',diag%accepted_substeps,'|ATTEMPTS=',diag%attempts,'|MAX_INDICATOR=',diag%max_temporal_indicator
    if(.not.result%completed.or..not.candidate%ready())call stop_labeled(trim(label)//' production trial')
    if(.not.result%mass%complete.or.abs(result%mass%residual)>1.0e-8_real64)call stop_labeled(trim(label)//' mass receipt')
    call committed%snapshot(after,available)
    if(.not.available.or..not.same_state(before,after))call stop_labeled(trim(label)//' trial mutated committed state')
    call candidate%snapshot(candidate_state,available)
    if(.not.available)call stop_labeled(trim(label)//' candidate snapshot')
    call backend%discard_trial_candidate(candidate,diag)
    if(candidate%ready())call stop_labeled(trim(label)//' discard')

    call backend%run_trial(column,template,p,committed,forcing,numerical,0.0_real64,dt,checkpoint, &
         replay_result,replay_candidate,replay_diag)
    if(.not.replay_result%completed.or..not.replay_candidate%ready())call stop_labeled(trim(label)//' replay trial')
    call replay_candidate%snapshot(replay_state,available)
    if(.not.available.or..not.same_state(candidate_state,replay_state))call stop_labeled(trim(label)//' replay identity')
    write(*,'(*(g0))') 'SWAP431_HYD_RUNTIME_',trim(label),'=PASS|MASS=',result%mass%residual
  end subroutine execute_and_replay

  subroutine expect_rejected(p,initial,label)
    type(fmr_b110_physical_parameters_t),target,intent(in)::p
    type(fmr_b110_physical_state_t),intent(in)::initial
    character(len=*),intent(in)::label
    type(fmr_serialized_reference_backend_t)::backend
    type(fixed_flux_top_boundary_provider_t),target::top
    type(fmr_b110_physical_forcing_t)::forcing
    type(fmr_logical_column_t)::column
    type(fmr_template_t)::template
    type(canonical_numerical_config_t)::numerical
    type(kernel_committed_state_t)::committed
    type(kernel_checkpoint_t)::checkpoint
    type(kernel_candidate_state_t)::candidate
    type(kernel_result_t)::result
    type(kernel_diagnostics_t)::diag
    logical::ok
    call setup_execution(p,initial,forcing,column,template,numerical,committed,checkpoint,top,backend,ok)
    if(.not.ok)call stop_labeled(trim(label)//' setup')
    call backend%run_trial(column,template,p,committed,forcing,numerical,0.0_real64,1.0e-5_real64,checkpoint, &
         result,candidate,diag)
    if(result%completed.or.candidate%ready().or.diag%admission_rejections<1)call stop_labeled(trim(label)//' not rejected')
    print '(a)','SWAP431_HYD_UNQUALIFIED_COMPOSITION=FAIL_CLOSED'
  end subroutine expect_rejected

  subroutine setup_execution(p,initial,forcing,column,template,numerical,committed,checkpoint,top,backend,ok)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(fmr_b110_physical_state_t),intent(in)::initial
    type(fmr_b110_physical_forcing_t),intent(out)::forcing
    type(fmr_logical_column_t),intent(out)::column
    type(fmr_template_t),intent(out)::template
    type(canonical_numerical_config_t),intent(out)::numerical
    type(kernel_committed_state_t),intent(out)::committed
    type(kernel_checkpoint_t),intent(out)::checkpoint
    type(fixed_flux_top_boundary_provider_t),target,intent(out)::top
    type(fmr_serialized_reference_backend_t),intent(out)::backend
    logical,intent(out)::ok
    logical::available
    integer(int64),parameter::lineage=643101_int64,layout_id=643100_int64

    call fmr_new_b110_committed_state(committed,lineage,initial,0.0_real64,ok)
    if(.not.ok)return
    allocate(forcing%drainage_flux_by_level(1,numnod),forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    forcing%top_flux=0.0_real64
    forcing%top_head=0.0_real64
    forcing%bottom_flux=0.0_real64
    forcing%bottom_head=-100.0_real64
    forcing%drainage_flux_by_level=0.0_real64
    forcing%subsurface_irrigation_source=0.0_real64
    forcing%root_extraction_sink=0.0_real64

    column%column_id=lineage
    column%template_id=lineage
    column%parameter_ref=p%parameter_set_id
    column%state_handle=1_int64
    column%forcing_handle=1_int64
    column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    template%template_id=column%template_id
    template%physics_topology_id=1_int64
    template%vertical_layout_id=1_int64
    template%state_layout_id=layout_id
    template%solver_interface_id=1_int64
    template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE

    numerical%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    numerical%transaction%temporal_tolerance=1.0e-6_real64
    numerical%transaction%mass_tolerance=1.0e-8_real64
    numerical%transaction%retry_scale=0.5_real64
    numerical%transaction%max_retries=12
    numerical%max_committed_substeps=64
    call backend%initialize(top)
    call committed%capture_checkpoint(checkpoint,available)
    ok=available
  end subroutine setup_execution

  logical function same_state(a,b) result(same)
    class(transaction_state_t),intent(in)::a,b
    same=.false.
    select type(aa=>a)
    type is(fmr_b110_physical_state_t)
      select type(bb=>b)
      type is(fmr_b110_physical_state_t)
        same=aa%active_nodes==bb%active_nodes
        if(same)same=all(aa%pressure_head==bb%pressure_head).and.all(aa%water_content==bb%water_content)
        if(same)same=aa%ponding_depth==bb%ponding_depth.and.aa%groundwater_level==bb%groundwater_level
      class default
        same=.false.
      end select
    class default
      same=.false.
    end select
  end function same_state
end program test_swap431_hyd_serialized_runtime
