program test_fvq128_fapp09_independent
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_BASE, &
       FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, fmr_new_b110_committed_state
  use mod_fmr_drainage_response_binding, only: FMR_DRAIN_VARIANT_EXTENDED_SIGNED
  use mod_drainage_extended_exchange, only: EXT_DRAIN_TUBE, EXT_DRAIN_TOP_NONE
  use mod_fmr_surface_water_head_forcing_adapter, only: fmr_surface_water_head_forcing_materializer_t, &
       FMR_SW_HEAD_FORCING_OK, FMR_SW_HEAD_FORCING_PROFILE_NOT_ADMITTED
  use mod_fmr_surface_water_swap_participant, only: fmr_surface_water_swap_participant_t, fmr_surface_water_trial_t, &
       fmr_surface_water_external_profile_admitted, FMR_SW_PARTICIPANT_OK, FMR_SW_PARTICIPANT_EXCHANGE_MISMATCH
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0=9123.125_real64
  real(real64), parameter :: t1=9123.375_real64
  real(real64), parameter :: dt=t1-t0
  real(real64), parameter :: initial_head=-123.0_real64
  real(real64), parameter :: initial_gwl=-2.25_real64
  real(real64), parameter :: qmag=2.0e-2_real64
  real(real64), parameter :: tol=1.0e-12_real64
  integer(int64), parameter :: column_id=58128_int64

  call verify_scope_and_owner()
  call verify_positive_transaction()
  call verify_negative_transaction()
  write(*,'(A)') 'F_VQ128_FAPP09_INDEPENDENT=PASS'

contains

  subroutine verify_scope_and_owner()
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template, fixed_template
    type(fmr_b110_physical_parameters_t) :: parameters, multi
    type(fmr_b110_physical_forcing_t) :: base
    type(canonical_numerical_config_t) :: config
    type(fmr_surface_water_head_forcing_materializer_t) :: materializer, rejected
    integer :: status

    call initialize_case(committed,column,template,parameters,base,config,qmag)
    call materializer%initialize(base,parameters,status)
    call require(status==FMR_SW_HEAD_FORCING_OK .and. materializer%ready(),101)
    call require(fmr_surface_water_external_profile_admitted(template,parameters,committed,materializer),102)

    multi=parameters
    deallocate(multi%drainage_response_levels)
    allocate(multi%drainage_response_levels(2))
    multi%drainage_response_levels=parameters%drainage_response_levels(1)
    call rejected%initialize(base,multi,status)
    call require(status==FMR_SW_HEAD_FORCING_PROFILE_NOT_ADMITTED,103)

    fixed_template=template
    fixed_template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER
    call require(.not.fmr_surface_water_external_profile_admitted(fixed_template,parameters,committed,materializer),104)

    write(*,'(A)') 'F_VQ128_SINGLE_LEVEL_SCOPE=PASS'
    write(*,'(A)') 'F_VQ128_OWNER_XOR=PASS'
  end subroutine verify_scope_and_owner

  subroutine verify_positive_transaction()
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: base
    type(canonical_numerical_config_t) :: config
    type(fmr_surface_water_head_forcing_materializer_t) :: materializer
    type(fmr_surface_water_swap_participant_t) :: participant
    type(fmr_surface_water_trial_t) :: first, replay
    type(fmr_serialized_reference_backend_t) :: backend
    type(fmr04_fixed_flux_top_provider_t), target :: top
    class(transaction_state_t), allocatable :: snapshot
    real(real64) :: heads(1), expected
    logical :: did_commit, available
    integer :: status

    call initialize_case(committed,column,template,parameters,base,config,qmag)
    call materializer%initialize(base,parameters,status)
    call require(status==FMR_SW_HEAD_FORCING_OK,201)
    call backend%initialize(top)
    call participant%capture_origin(committed,status)
    call require(status==FMR_SW_PARTICIPANT_OK,202)

    heads(1)=-22.25_real64
    call participant%trial_from_origin(backend,column,template,parameters,committed,materializer,config,t0,t1,heads,first,status)
    expected=qmag*dt
    call require(status==FMR_SW_PARTICIPANT_OK .and. first%valid,203)
    call require(first%accepted_substeps==1,204)
    call require(abs(first%signed_soil_to_surface_exchange_cm-expected)<=tol,205)
    call require(abs(first%signed_soil_to_surface_exchange_cm-0.5_real64*expected)>100.0_real64*tol,206)
    call require(committed%current_revision()==0_int64,207)

    call participant%commit_candidate(backend,committed,t0,t1,0.0_real64,tol,did_commit,status)
    call require(.not.did_commit .and. status==FMR_SW_PARTICIPANT_EXCHANGE_MISMATCH,208)
    call require(committed%current_revision()==0_int64 .and. participant%has_live_candidate(),209)
    call participant%discard_candidate(backend)
    call require(participant%has_origin() .and. .not.participant%has_live_candidate(),210)

    call participant%trial_from_origin(backend,column,template,parameters,committed,materializer,config,t0,t1,heads,replay,status)
    call require(status==FMR_SW_PARTICIPANT_OK .and. replay%valid,211)
    call require(abs(replay%signed_soil_to_surface_exchange_cm-first%signed_soil_to_surface_exchange_cm)<=tol,212)
    call require(participant%publication_ready(committed,t0,t1,replay%signed_soil_to_surface_exchange_cm,tol),213)
    call participant%commit_candidate(backend,committed,t0,t1,replay%signed_soil_to_surface_exchange_cm,tol,did_commit,status)
    call require(did_commit .and. status==FMR_SW_PARTICIPANT_OK,214)
    call require(committed%current_revision()==1_int64,215)

    call committed%snapshot(snapshot,available)
    call require(available .and. allocated(snapshot),216)
    select type(state=>snapshot)
    type is(fmr_b110_physical_state_t)
      call require(.not.allocated(state%snow) .and. .not.allocated(state%soil_temperature),217)
    class default
      call require(.false.,218)
    end select

    write(*,'(A)') 'F_VQ128_ACCEPTED_WINDOW_POSITIVE_EXCHANGE=PASS'
    write(*,'(A)') 'F_VQ128_MISMATCH_DISCARD_REPLAY=PASS'
    write(*,'(A)') 'F_VQ128_BASE_STATE_PRESERVED=PASS'
  end subroutine verify_positive_transaction

  subroutine verify_negative_transaction()
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: base
    type(canonical_numerical_config_t) :: config
    type(fmr_surface_water_head_forcing_materializer_t) :: materializer
    type(fmr_surface_water_swap_participant_t) :: participant
    type(fmr_surface_water_trial_t) :: trial
    type(fmr_serialized_reference_backend_t) :: backend
    type(fmr04_fixed_flux_top_provider_t), target :: top
    real(real64) :: heads(1), expected
    logical :: did_commit
    integer :: status

    call initialize_case(committed,column,template,parameters,base,config,-qmag)
    call materializer%initialize(base,parameters,status)
    call require(status==FMR_SW_HEAD_FORCING_OK,301)
    call backend%initialize(top)
    call participant%capture_origin(committed,status)
    call require(status==FMR_SW_PARTICIPANT_OK,302)

    heads(1)=17.75_real64
    call participant%trial_from_origin(backend,column,template,parameters,committed,materializer,config,t0,t1,heads,trial,status)
    expected=-qmag*dt
    call require(status==FMR_SW_PARTICIPANT_OK .and. trial%valid,303)
    call require(trial%accepted_substeps==1,304)
    call require(abs(trial%signed_soil_to_surface_exchange_cm-expected)<=tol,305)
    call require(abs(trial%signed_soil_to_surface_exchange_cm-0.5_real64*expected)>100.0_real64*tol,306)

    call participant%commit_candidate(backend,committed,t0,t1,trial%signed_soil_to_surface_exchange_cm,tol,did_commit,status)
    call require(did_commit .and. status==FMR_SW_PARTICIPANT_OK,307)
    call require(committed%current_revision()==1_int64,308)

    write(*,'(A)') 'F_VQ128_ACCEPTED_WINDOW_NEGATIVE_EXCHANGE=PASS'
    write(*,'(A)') 'F_VQ128_SIGNED_TRANSACTION_COMMIT=PASS'
  end subroutine verify_negative_transaction

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
    logical :: ok
    integer :: k

    parameters%parameter_set_id=58128_int64
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
    parameters%bottom_mode=7; parameters%swkimpl=0; parameters%swkmean=1; parameters%swsophy=0
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
    call bind_b110_default_mvg_provider(provider,hp,dt)
    heads=initial_head
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    k0=conductivity(1)

    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water
    state%ponding_depth=0.0_real64; state%groundwater_level=initial_gwl
    call fmr_new_b110_committed_state(committed,column_id,state,t0,ok)
    call require(ok,401)

    template%template_id=581281_int64; template%physics_topology_id=581282_int64
    template%vertical_layout_id=581283_int64; template%state_layout_id=581284_int64
    template%solver_interface_id=581285_int64; template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE

    column%column_id=column_id; column%template_id=template%template_id; column%parameter_ref=1_int64
    column%state_handle=1_int64; column%forcing_handle=1_int64; column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE

    base%top_flux=-k0; base%top_head=initial_head; base%bottom_flux=-k0; base%bottom_head=-321.0_real64
    allocate(base%subsurface_irrigation_source(numnod),base%root_extraction_sink(numnod))
    base%subsurface_irrigation_source=0.0_real64
    base%subsurface_irrigation_source(numnod)=balancing_qssdi
    base%root_extraction_sink=0.0_real64

    config%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    config%transaction%temporal_tolerance=1.0e3_real64
    config%transaction%mass_tolerance=1.0e-10_real64
    config%transaction%retry_scale=0.5_real64
    config%transaction%max_retries=2
    config%max_committed_substeps=8
    config%progress_tolerance=0.0_real64
  end subroutine initialize_case

  subroutine require(condition,code)
    logical,intent(in)::condition
    integer,intent(in)::code
    if(.not.condition)then
      write(*,'(A,I0)') 'F_VQ128_FAIL=',code
      error stop 1
    end if
  end subroutine require
end program test_fvq128_fapp09_independent
