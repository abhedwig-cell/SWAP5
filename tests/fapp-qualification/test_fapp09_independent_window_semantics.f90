program test_fapp09_independent_window_semantics
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_BASE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state
  use mod_fmr_drainage_response_binding, only: FMR_DRAIN_VARIANT_EXTENDED_SIGNED
  use mod_drainage_extended_exchange, only: EXT_DRAIN_TUBE, EXT_DRAIN_TOP_NONE
  use mod_fmr_surface_water_head_forcing_adapter, only: fmr_surface_water_head_forcing_materializer_t, &
       FMR_SW_HEAD_FORCING_OK
  use mod_fmr_surface_water_swap_participant, only: fmr_surface_water_swap_participant_t, fmr_surface_water_trial_t, &
       FMR_SW_PARTICIPANT_OK, FMR_SW_PARTICIPANT_EXCHANGE_MISMATCH
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0=9123.125_real64, t1=9123.375_real64
  real(real64), parameter :: duration=t1-t0
  real(real64), parameter :: initial_head=-123.0_real64, initial_gwl=-2.25_real64
  real(real64), parameter :: signed_rate=1.0e-2_real64, tol=1.0e-12_real64
  integer(int64), parameter :: column_id=49091_int64

  call verify_direction(+1.0_real64)
  call verify_direction(-1.0_real64)
  write(*,'(A)') 'FAPP09_VQ_INDEPENDENT_WINDOW_TRANSACTION=PASS'

contains

  subroutine verify_direction(sign)
    real(real64), intent(in) :: sign
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: base
    type(canonical_numerical_config_t) :: config
    type(fmr_surface_water_head_forcing_materializer_t) :: materializer
    type(fmr_surface_water_swap_participant_t) :: participant
    type(fmr_surface_water_trial_t) :: first_trial,replay_trial
    type(fmr_serialized_reference_backend_t) :: backend
    type(fmr_serialized_physical_observation_t) :: observation
    type(fmr04_fixed_flux_top_provider_t), target :: top
    real(real64) :: heads(1),expected,last_half
    integer :: status
    logical :: did_commit

    call initialize_case(committed,column,template,parameters,base,config,sign*signed_rate)
    call materializer%initialize(base,parameters,status)
    call require(status==FMR_SW_HEAD_FORCING_OK,'materializer')
    call backend%initialize(top)
    call participant%capture_origin(committed,status)
    call require(status==FMR_SW_PARTICIPANT_OK,'capture origin')

    if(sign>0.0_real64)then
      heads(1)=-12.25_real64
    else
      heads(1)=7.75_real64
    end if
    expected=sign*signed_rate*duration
    last_half=0.5_real64*expected

    call participant%trial_from_origin(backend,column,template,parameters,committed,materializer,config,t0,t1,heads,first_trial,status)
    call require(status==FMR_SW_PARTICIPANT_OK .and. first_trial%valid,'whole-window trial')
    call require(first_trial%accepted_substeps==1,'one accepted outer substep')
    call require(abs(first_trial%signed_soil_to_surface_exchange_cm-expected)<=tol,'published whole-window exchange')
    call require(committed%current_revision()==0_int64,'trial precommit')

    observation=backend%observation()
    call require(observation%drainage_response_window_exchange_available,'window exchange available')
    call require(abs(observation%drainage_response_window_signed_exchange_native-expected)<=tol,'backend whole-window exchange')
    call require(abs(observation%drainage_response_signed_exchange_native-last_half)<=tol,'per-advance observation remains last half step')

    call participant%commit_candidate(backend,committed,t0,t1,last_half,tol,did_commit,status)
    call require(.not.did_commit .and. status==FMR_SW_PARTICIPANT_EXCHANGE_MISMATCH,'mismatch blocks commit')
    call require(committed%current_revision()==0_int64,'mismatch nonmutating')
    call require(participant%has_origin() .and. participant%has_live_candidate(),'mismatch keeps candidate for adjudication')

    call participant%discard_candidate(backend)
    call require(participant%has_origin() .and. .not.participant%has_live_candidate(),'discard keeps accepted origin')
    call participant%trial_from_origin(backend,column,template,parameters,committed,materializer,config,t0,t1,heads,replay_trial,status)
    call require(status==FMR_SW_PARTICIPANT_OK .and. replay_trial%valid,'same-origin replay')
    call require(abs(replay_trial%signed_soil_to_surface_exchange_cm-first_trial%signed_soil_to_surface_exchange_cm)<=tol, &
         'same-origin exact exchange replay')
    call require(participant%publication_ready(committed,t0,t1,expected,tol),'matched transfer publication ready')
    call participant%commit_candidate(backend,committed,t0,t1,expected,tol,did_commit,status)
    call require(did_commit .and. status==FMR_SW_PARTICIPANT_OK,'matched commit')
    call require(committed%current_revision()==1_int64,'sole revision increment')

    if(sign>0.0_real64)then
      write(*,'(A)') 'FAPP09_VQ_POSITIVE_WINDOW_LEDGER=PASS'
      write(*,'(A)') 'FAPP09_VQ_MISMATCH_DISCARD_REPLAY=PASS'
    else
      write(*,'(A)') 'FAPP09_VQ_NEGATIVE_WINDOW_LEDGER=PASS'
    end if
  end subroutine verify_direction

  subroutine initialize_case(committed,column,template,parameters,base,config,balancing_qssdi)
    type(kernel_committed_state_t), intent(out) :: committed
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    type(fmr_b110_physical_forcing_t), intent(out) :: base
    type(canonical_numerical_config_t), intent(out) :: config
    real(real64), intent(in) :: balancing_qssdi
    type(fmr_b110_physical_state_t) :: state
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod),k0
    integer :: k
    logical :: ok

    parameters%parameter_set_id=49091_int64; parameters%active_nodes=numnod
    allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod),parameters%cofgen(24,numnod))
    parameters%z=z; parameters%dz=dz; parameters%node_distance=disnod(1:numnod); parameters%cofgen=0.0_real64
    do k=1,numnod
      parameters%cofgen(1,k)=0.032_real64; parameters%cofgen(2,k)=0.423_real64; parameters%cofgen(3,k)=4.75_real64
      parameters%cofgen(4,k)=0.0135_real64; parameters%cofgen(5,k)=0.365_real64; parameters%cofgen(6,k)=1.455_real64
      parameters%cofgen(7,k)=1.0_real64-1.0_real64/parameters%cofgen(6,k); parameters%cofgen(8,k)=parameters%cofgen(4,k)
      parameters%cofgen(9,k)=0.0_real64; parameters%cofgen(10,k)=parameters%cofgen(3,k); parameters%cofgen(11,k)=0.999_real64
      parameters%cofgen(12,k)=0.99_real64*parameters%cofgen(3,k); parameters%cofgen(22,k)=-1.0e6_real64
      parameters%cofgen(23,k)=1.0e-12_real64
    end do
    parameters%bottom_mode=7; parameters%swkimpl=0; parameters%swkmean=1; parameters%swsophy=0
    parameters%root_extraction_active=.false.; parameters%macropore_active=.false.; parameters%snow_active=.false.
    parameters%hysteresis_active=.false.; parameters%tabulated_hydraulics_active=.false.; parameters%elasticity_active=.false.
    parameters%frost_active=.false.; parameters%soil_temperature_active=.false.; parameters%black_evaporation_active=.false.
    parameters%boesten_evaporation_active=.false.; parameters%drainage_response_active=.true.
    parameters%drainage_qbot_smooth_freatic_projection=.false.
    allocate(parameters%drainage_response_levels(1))
    parameters%drainage_response_levels(1)%variant=FMR_DRAIN_VARIANT_EXTENDED_SIGNED
    parameters%drainage_response_levels(1)%extended%zbotdr_cm=-100.0_real64
    parameters%drainage_response_levels(1)%extended%drain_type=EXT_DRAIN_TUBE
    parameters%drainage_response_levels(1)%extended%spacing_cm=1000.0_real64
    parameters%drainage_response_levels(1)%extended%rdrain_day=1000.0_real64
    parameters%drainage_response_levels(1)%extended%rinfi_day=1000.0_real64
    parameters%drainage_response_levels(1)%extended%rentry_day=0.0_real64
    parameters%drainage_response_levels(1)%extended%rexit_day=0.0_real64
    parameters%drainage_response_levels(1)%extended%gwlinf_cm=-200.0_real64
    parameters%drainage_response_levels(1)%extended%pondmx_cm=1000.0_real64
    parameters%drainage_response_levels(1)%extended%highest_level=.false.
    parameters%drainage_response_levels(1)%extended%highest_surface_mode=EXT_DRAIN_TOP_NONE

    call initialize_b110_default_mvg_parameters(hp,parameters%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,duration)
    heads=initial_head
    call provider%evaluate(heads,water,conductivity,capacity,dkdh); k0=conductivity(1)
    state%active_nodes=numnod; allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water; state%ponding_depth=0.0_real64; state%groundwater_level=initial_gwl
    call fmr_new_b110_committed_state(committed,column_id,state,t0,ok)
    call require(ok,'committed init')

    template%template_id=490911_int64; template%physics_topology_id=490912_int64
    template%vertical_layout_id=490913_int64; template%state_layout_id=490914_int64
    template%solver_interface_id=490915_int64; template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    column%column_id=column_id; column%template_id=template%template_id; column%parameter_ref=1_int64
    column%state_handle=1_int64; column%forcing_handle=1_int64; column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE

    base%top_flux=-k0; base%top_head=initial_head; base%bottom_flux=-k0; base%bottom_head=-321.0_real64
    allocate(base%subsurface_irrigation_source(numnod),base%root_extraction_sink(numnod))
    base%subsurface_irrigation_source=0.0_real64; base%subsurface_irrigation_source(numnod)=balancing_qssdi
    base%root_extraction_sink=0.0_real64

    config%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    config%transaction%temporal_tolerance=1.0e3_real64; config%transaction%mass_tolerance=1.0e-10_real64
    config%transaction%retry_scale=0.5_real64; config%transaction%max_retries=2
    config%max_committed_substeps=8; config%progress_tolerance=0.0_real64
  end subroutine initialize_case

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'FAPP09_VQ_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fapp09_independent_window_semantics
