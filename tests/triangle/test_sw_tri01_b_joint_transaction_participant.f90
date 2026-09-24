program test_sw_tri01_b_joint_transaction_participant
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_head_datum_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_BASE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, fmr_new_b110_committed_state
  use mod_fmr_drainage_response_binding, only: FMR_DRAIN_VARIANT_EXTENDED_SIGNED
  use mod_drainage_extended_exchange, only: EXT_DRAIN_TUBE, EXT_DRAIN_TOP_NONE
  use mod_fmr_surface_water_head_forcing_adapter, only: fmr_surface_water_head_forcing_materializer_t, FMR_SW_HEAD_FORCING_OK
  use mod_fmr_groundwater_surface_water_swap_participant, only: &
       fmr_groundwater_surface_water_swap_participant_t, fmr_groundwater_surface_water_trial_t, &
       fmr_groundwater_surface_water_profile_admitted, &
       FMR_GWSW_PARTICIPANT_OK, FMR_GWSW_PARTICIPANT_ORIGIN_DRIFT, &
       FMR_GWSW_PARTICIPANT_SURFACE_EXCHANGE_MISMATCH
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0=9123.125_real64
  real(real64), parameter :: t1=9123.375_real64
  real(real64), parameter :: duration=t1-t0
  real(real64), parameter :: initial_head=-123.0_real64
  real(real64), parameter :: initial_gwl=-2.25_real64
  real(real64), parameter :: signed_rate=1.0e-2_real64
  real(real64), parameter :: exchange_tol=1.0e-12_real64
  real(real64), parameter :: gw_head_m=-2.23_real64
  integer(int64), parameter :: column_id=52001_int64

  call matched_commit_case('B1_POSITIVE_MATCHED_COMMIT',-12.25_real64,signed_rate,1)
  call matched_commit_case('B2_NEGATIVE_MATCHED_COMMIT',7.75_real64,-signed_rate,-1)
  call mismatch_replay_case()
  call stale_origin_case()
  write(*,'(A)') 'SW_TRI01_B_JOINT_TRANSACTION_PARTICIPANT=PASS'

contains

  subroutine matched_commit_case(label,surface_head_cm,balancing_qssdi,expected_sign)
    character(len=*), intent(in) :: label
    real(real64), intent(in) :: surface_head_cm,balancing_qssdi
    integer, intent(in) :: expected_sign
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: base
    type(canonical_numerical_config_t) :: config
    type(fmr_surface_water_head_forcing_materializer_t) :: surface_materializer
    type(fmr_groundwater_surface_water_swap_participant_t) :: participant
    type(fmr_groundwater_surface_water_trial_t) :: trial
    type(fmr_serialized_reference_backend_t) :: backend
    type(fmr04_fixed_flux_top_provider_t), target :: top
    type(groundwater_coupling_window_t) :: window
    type(groundwater_head_datum_t) :: datum
    real(real64) :: surface_heads(1)
    logical :: did_commit
    integer :: status

    call initialize_case(committed,column,template,parameters,base,config,balancing_qssdi,column_id)
    call initialize_external_contract(base,parameters,surface_materializer,window,datum)
    call require(fmr_groundwater_surface_water_profile_admitted(template,parameters,committed,surface_materializer), &
         'joint profile admitted')
    call backend%initialize(top)
    call participant%capture_origin(committed,status)
    call require(status==FMR_GWSW_PARTICIPANT_OK,'capture joint origin')
    call require(participant%captured_revision()==0_int64,'captured revision zero')

    surface_heads(1)=surface_head_cm
    call participant%trial_from_origin(backend,column,template,parameters,committed,surface_materializer,config, &
         datum,window,gw_head_m,surface_heads,trial,status)
    call require(status==FMR_GWSW_PARTICIPANT_OK .and. trial%valid,'joint trial valid')
    call require(trial%accepted_substeps>0,'joint candidate has accepted substeps')
    call require(trial%groundwater_q_swap_m_per_s==trial%groundwater_q_swap_m_per_s,'finite groundwater q')
    if(expected_sign>0) then
      call require(trial%signed_soil_to_surface_exchange_cm>0.0_real64,'positive surface exchange')
    else
      call require(trial%signed_soil_to_surface_exchange_cm<0.0_real64,'negative surface exchange')
    end if
    call require(committed%current_revision()==0_int64,'joint trial nonmutating')
    call require(participant%publication_ready(committed,window,trial%signed_soil_to_surface_exchange_cm,exchange_tol), &
         'matched dual preflight')
    call participant%commit_candidate(backend,committed,window,trial%signed_soil_to_surface_exchange_cm,exchange_tol,did_commit,status)
    call require(did_commit .and. status==FMR_GWSW_PARTICIPANT_OK,'single matched kernel commit')
    call require(committed%current_revision()==1_int64,'exactly one revision increment')
    call require(.not.participant%has_origin() .and. .not.participant%has_live_candidate(),'participant resets after commit')
    write(*,'(A,A)') 'SW_TRI01_B_CASE_PASS=',trim(label)
  end subroutine matched_commit_case

  subroutine mismatch_replay_case()
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: base
    type(canonical_numerical_config_t) :: config
    type(fmr_surface_water_head_forcing_materializer_t) :: surface_materializer
    type(fmr_groundwater_surface_water_swap_participant_t) :: participant
    type(fmr_groundwater_surface_water_trial_t) :: trial1,trial2
    type(fmr_serialized_reference_backend_t) :: backend
    type(fmr04_fixed_flux_top_provider_t), target :: top
    type(groundwater_coupling_window_t) :: window
    type(groundwater_head_datum_t) :: datum
    real(real64) :: surface_heads(1), requested
    logical :: did_commit
    integer :: status

    call initialize_case(committed,column,template,parameters,base,config,signed_rate,column_id+1_int64)
    call initialize_external_contract(base,parameters,surface_materializer,window,datum)
    call backend%initialize(top)
    call participant%capture_origin(committed,status)
    call require(status==FMR_GWSW_PARTICIPANT_OK,'mismatch capture')
    surface_heads(1)=-12.25_real64
    call participant%trial_from_origin(backend,column,template,parameters,committed,surface_materializer,config, &
         datum,window,gw_head_m,surface_heads,trial1,status)
    call require(status==FMR_GWSW_PARTICIPANT_OK .and. trial1%valid,'mismatch setup trial')
    requested=trial1%signed_soil_to_surface_exchange_cm

    call participant%commit_candidate(backend,committed,window,0.0_real64,exchange_tol,did_commit,status)
    call require(.not.did_commit .and. status==FMR_GWSW_PARTICIPANT_SURFACE_EXCHANGE_MISMATCH,'surface mismatch blocks commit')
    call require(committed%current_revision()==0_int64,'mismatch leaves committed revision')
    call require(participant%has_origin() .and. participant%has_live_candidate(),'mismatch preserves candidate for explicit disposition')

    call participant%discard_candidate(backend)
    call require(participant%has_origin() .and. .not.participant%has_live_candidate(),'discard retains accepted origin')
    call participant%trial_from_origin(backend,column,template,parameters,committed,surface_materializer,config, &
         datum,window,gw_head_m,surface_heads,trial2,status)
    call require(status==FMR_GWSW_PARTICIPANT_OK .and. trial2%valid,'same-origin replay')
    call require(abs(trial2%signed_soil_to_surface_exchange_cm-requested)<=exchange_tol,'surface exchange replay identical')
    call require(abs(trial2%groundwater_q_swap_m_per_s-trial1%groundwater_q_swap_m_per_s)<=1.0e-18_real64, &
         'groundwater exchange replay identical')
    call participant%commit_candidate(backend,committed,window,trial2%signed_soil_to_surface_exchange_cm,exchange_tol,did_commit,status)
    call require(did_commit .and. status==FMR_GWSW_PARTICIPANT_OK,'replayed joint candidate commits once')
    call require(committed%current_revision()==1_int64,'recomposition produces one commit')
    write(*,'(A)') 'SW_TRI01_B_CASE_PASS=B3_MISMATCH_DISCARD_REPLAY'
  end subroutine mismatch_replay_case

  subroutine stale_origin_case()
    type(kernel_committed_state_t) :: committed, other_committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: base
    type(canonical_numerical_config_t) :: config
    type(fmr_surface_water_head_forcing_materializer_t) :: surface_materializer
    type(fmr_groundwater_surface_water_swap_participant_t) :: participant
    type(fmr_groundwater_surface_water_trial_t) :: trial
    type(fmr_serialized_reference_backend_t) :: backend
    type(fmr04_fixed_flux_top_provider_t), target :: top
    type(groundwater_coupling_window_t) :: window
    type(groundwater_head_datum_t) :: datum
    real(real64) :: surface_heads(1)
    integer :: status

    call initialize_case(committed,column,template,parameters,base,config,signed_rate,column_id+2_int64)
    call initialize_case(other_committed,column,template,parameters,base,config,signed_rate,column_id+3_int64)
    call initialize_external_contract(base,parameters,surface_materializer,window,datum)
    call backend%initialize(top)
    call participant%capture_origin(committed,status)
    call require(status==FMR_GWSW_PARTICIPANT_OK,'stale capture')
    surface_heads(1)=-12.25_real64
    call participant%trial_from_origin(backend,column,template,parameters,other_committed,surface_materializer,config, &
         datum,window,gw_head_m,surface_heads,trial,status)
    call require(status==FMR_GWSW_PARTICIPANT_ORIGIN_DRIFT .and. .not.trial%valid,'stale origin fails closed')
    call require(committed%current_revision()==0_int64 .and. other_committed%current_revision()==0_int64,'stale failure nonmutating')
    write(*,'(A)') 'SW_TRI01_B_CASE_PASS=B4_STALE_ORIGIN_FAIL_CLOSED'
  end subroutine stale_origin_case

  subroutine initialize_external_contract(base,parameters,surface_materializer,window,datum)
    type(fmr_b110_physical_forcing_t), intent(in) :: base
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(fmr_surface_water_head_forcing_materializer_t), intent(out) :: surface_materializer
    type(groundwater_coupling_window_t), intent(out) :: window
    type(groundwater_head_datum_t), intent(out) :: datum
    integer :: status
    call surface_materializer%initialize(base,parameters,status)
    call require(status==FMR_SW_HEAD_FORCING_OK .and. surface_materializer%ready(),'surface materializer initializes')
    window%t0=t0; window%t1=t1
    datum%available=.true.; datum%datum_id=52001_int64; datum%bottom_boundary_elevation_m=-1.0_real64
  end subroutine initialize_external_contract

  subroutine initialize_case(committed,column,template,parameters,base,config,balancing_qssdi,id)
    type(kernel_committed_state_t), intent(out) :: committed
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    type(fmr_b110_physical_forcing_t), intent(out) :: base
    type(canonical_numerical_config_t), intent(out) :: config
    real(real64), intent(in) :: balancing_qssdi
    integer(int64), intent(in) :: id
    type(fmr_b110_physical_state_t) :: state
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod),k0
    logical :: ok
    integer :: k

    parameters%parameter_set_id=id
    parameters%active_nodes=numnod
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
    parameters%bottom_mode=5
    parameters%swkimpl=0; parameters%swkmean=1; parameters%swsophy=0
    parameters%root_extraction_active=.false.; parameters%macropore_active=.false.; parameters%snow_active=.false.
    parameters%hysteresis_active=.false.; parameters%tabulated_hydraulics_active=.false.
    parameters%elasticity_active=.false.; parameters%frost_active=.false.; parameters%soil_temperature_active=.false.
    parameters%black_evaporation_active=.false.; parameters%boesten_evaporation_active=.false.
    parameters%drainage_response_active=.true.; parameters%drainage_qbot_smooth_freatic_projection=.false.
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
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    k0=conductivity(1)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water
    state%ponding_depth=0.0_real64; state%groundwater_level=initial_gwl
    call fmr_new_b110_committed_state(committed,id,state,t0,ok)
    call require(ok,'committed state initializes')

    template%template_id=id*10_int64+1_int64; template%physics_topology_id=id*10_int64+2_int64
    template%vertical_layout_id=id*10_int64+3_int64; template%state_layout_id=id*10_int64+4_int64
    template%solver_interface_id=id*10_int64+5_int64; template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    column%column_id=id; column%template_id=template%template_id; column%parameter_ref=1_int64
    column%state_handle=1_int64; column%forcing_handle=1_int64; column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE

    base%top_flux=-k0; base%top_head=initial_head; base%bottom_flux=-k0; base%bottom_head=-321.0_real64
    allocate(base%subsurface_irrigation_source(numnod),base%root_extraction_sink(numnod))
    base%subsurface_irrigation_source=0.0_real64
    base%subsurface_irrigation_source(numnod)=balancing_qssdi
    base%root_extraction_sink=0.0_real64

    config%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    config%transaction%temporal_tolerance=1.0e3_real64
    config%transaction%mass_tolerance=1.0e-10_real64
    config%transaction%retry_scale=0.5_real64; config%transaction%max_retries=2
    config%max_committed_substeps=8; config%progress_tolerance=0.0_real64
  end subroutine initialize_case

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'SW_TRI01_B_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_sw_tri01_b_joint_transaction_participant
