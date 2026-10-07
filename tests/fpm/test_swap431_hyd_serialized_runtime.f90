program test_swap431_hyd_serialized_runtime
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_result_t, kernel_diagnostics_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_OPTIONAL_STATE_LAYOUT_BASE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b111_analytical_hydraulic_provider, only: b111_analytical_hydraulic_parameters_t, &
       b111_analytical_hydraulic_provider_t, initialize_b111_analytical_hydraulic_parameters, &
       bind_b111_analytical_hydraulic_provider, B111_HYD_EXPONENTIAL, B111_HYD_BIMODAL_MVG, &
       B111_HYD_BIMODAL_MVG_WCK
  use mod_fmr_serialized_reference_backend, only: fmr_serialized_reference_backend_t, &
       fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, fmr_b110_physical_state_t, &
       fmr_new_b110_committed_state
  implicit none

  call exercise_model(B111_HYD_EXPONENTIAL,'MODEL2')
  call exercise_model(B111_HYD_BIMODAL_MVG,'MODEL3')
  call exercise_model(B111_HYD_BIMODAL_MVG_WCK,'MODEL6')
  call exercise_power()
  call exercise_fail_closed_composition()
  print '(a)','SWAP431_HYD_SERIALIZED_RUNTIME=PASS'

contains

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
    if(.not.ok)error stop trim(label)//' setup'
    call committed%snapshot(before,available)
    if(.not.available)error stop trim(label)//' before snapshot'

    call backend%run_trial(column,template,p,committed,forcing,numerical,0.0_real64,dt,checkpoint,result,candidate,diag)
    if(.not.result%completed.or..not.candidate%ready())error stop trim(label)//' production trial'
    if(.not.result%mass%complete.or.abs(result%mass%residual)>1.0e-8_real64)error stop trim(label)//' mass receipt'
    call committed%snapshot(after,available)
    if(.not.available.or..not.same_state(before,after))error stop trim(label)//' trial mutated committed state'
    call candidate%snapshot(candidate_state,available)
    if(.not.available)error stop trim(label)//' candidate snapshot'
    call backend%discard_trial_candidate(candidate,diag)
    if(candidate%ready())error stop trim(label)//' discard'

    call backend%run_trial(column,template,p,committed,forcing,numerical,0.0_real64,dt,checkpoint, &
         replay_result,replay_candidate,replay_diag)
    if(.not.replay_result%completed.or..not.replay_candidate%ready())error stop trim(label)//' replay trial'
    call replay_candidate%snapshot(replay_state,available)
    if(.not.available.or..not.same_state(candidate_state,replay_state))error stop trim(label)//' replay identity'
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
    if(.not.ok)error stop trim(label)//' setup'
    call backend%run_trial(column,template,p,committed,forcing,numerical,0.0_real64,1.0e-5_real64,checkpoint, &
         result,candidate,diag)
    if(result%completed.or.candidate%ready().or.diag%admission_rejections<1)error stop trim(label)//' not rejected'
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
