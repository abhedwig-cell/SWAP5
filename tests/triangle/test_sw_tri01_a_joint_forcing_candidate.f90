program test_sw_tri01_a_joint_forcing_candidate
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t, canonical_forcing_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_result_t, kernel_diagnostics_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_BASE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, fmr_new_b110_committed_state, &
       fmr_serialized_physical_observation_t
  use mod_fmr_drainage_response_binding, only: FMR_DRAIN_VARIANT_EXTENDED_SIGNED, FMR_DRAIN_BIND_OK
  use mod_drainage_extended_exchange, only: EXT_DRAIN_TUBE, EXT_DRAIN_TOP_NONE
  use mod_fmr_surface_water_head_forcing_adapter, only: fmr_surface_water_head_forcing_materializer_t, &
       FMR_SW_HEAD_FORCING_OK
  use mod_fmr_groundwater_head_forcing_adapter, only: fmr_groundwater_head_forcing_materializer_t
  use mod_groundwater_swap_forcing_adapter, only: GW_SWAP_FORCING_OK
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t
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
  integer(int64), parameter :: column_id=51001_int64

  call run_case('R1_POSITIVE_SURFACE_EXCHANGE',-12.25_real64,signed_rate,-2.23_real64,1)
  call run_case('R2_NEGATIVE_SURFACE_EXCHANGE',  7.75_real64,-signed_rate,-2.23_real64,-1)
  write(*,'(A)') 'SW_TRI01_A_JOINT_FORCING_CANDIDATE=PASS'

contains

  subroutine run_case(label,surface_head_cm,balancing_qssdi,gw_interface_head_m,expected_surface_sign)
    character(len=*), intent(in) :: label
    real(real64), intent(in) :: surface_head_cm,balancing_qssdi,gw_interface_head_m
    integer, intent(in) :: expected_surface_sign
    type(kernel_committed_state_t) :: committed
    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_candidate_state_t) :: candidate
    type(kernel_result_t) :: result
    type(kernel_diagnostics_t) :: diagnostics
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: base,surface_forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_surface_water_head_forcing_materializer_t) :: sw_materializer
    type(fmr_groundwater_head_forcing_materializer_t) :: gw_materializer
    type(groundwater_head_datum_t) :: datum
    type(fmr_serialized_reference_backend_t) :: backend
    type(fmr04_fixed_flux_top_provider_t), target :: top
    type(fmr_serialized_physical_observation_t) :: observation
    class(canonical_forcing_t), allocatable :: combined
    real(real64) :: surface_heads(1),candidate_t0,candidate_t1,committed_time
    logical :: ok,available
    integer :: status

    call initialize_case(committed,column,template,parameters,base,config,balancing_qssdi)
    call require(parameters%bottom_mode==5,'joint profile uses prescribed-head bottom mode')

    call sw_materializer%initialize(base,parameters,status)
    call require(status==FMR_SW_HEAD_FORCING_OK .and. sw_materializer%ready(),'surface materializer initializes')
    surface_heads(1)=surface_head_cm
    call sw_materializer%materialize(surface_heads,surface_forcing,status)
    call require(status==FMR_SW_HEAD_FORCING_OK,'surface head materialized')
    call require(allocated(surface_forcing%drainage_response_controls),'surface controls retained')
    call require(surface_forcing%drainage_response_controls(1)%resolved_surface_water_head_supplied, &
         'surface head supplied flag')
    call require(abs(surface_forcing%drainage_response_controls(1)%resolved_surface_water_head_cm-surface_head_cm) < 1.0e-14_real64, &
         'surface head exact materialization')

    call gw_materializer%initialize(surface_forcing)
    call require(gw_materializer%profile_admitted(parameters),'groundwater profile admits bottom_mode five with active drainage response')
    datum%available=.true.
    datum%datum_id=51001_int64
    datum%bottom_boundary_elevation_m=-1.0_real64
    call gw_materializer%materialize(gw_interface_head_m,datum,combined,status)
    call require(status==GW_SWAP_FORCING_OK .and. allocated(combined),'groundwater head materialized over surface forcing')

    select type(forcing => combined)
    type is(fmr_b110_physical_forcing_t)
      call require(allocated(forcing%drainage_response_controls),'combined forcing retains surface controls')
      call require(forcing%drainage_response_controls(1)%resolved_surface_water_head_supplied, &
           'combined surface head supplied')
      call require(abs(forcing%drainage_response_controls(1)%resolved_surface_water_head_cm-surface_head_cm) < 1.0e-14_real64, &
           'combined forcing preserves surface head')
      call require(abs(forcing%bottom_head+123.0_real64) < 1.0e-10_real64, &
           'combined forcing maps MODFLOW head to bottom pressure head')

      call committed%capture_checkpoint(checkpoint,available)
      call require(available .and. checkpoint%ready(),'single accepted origin checkpoint')
      call backend%initialize(top)
      call backend%run_trial(column,template,parameters,committed,forcing,config,t0,t1,checkpoint,result,candidate,diagnostics)
    class default
      call require(.false.,'combined forcing remains typed FMR forcing')
    end select

    call require(result%completed .and. result%mass%complete,'single joint candidate completed with complete mass')
    call require(candidate%ready(),'single joint candidate ready')
    call require(result%bottom_interface_exchange_available,'groundwater interface exchange available')
    call require(result%bottom_outward_exchange_native==result%bottom_outward_exchange_native,'finite groundwater exchange')
    observation=backend%observation()
    call require(observation%drainage_response_active,'drainage response active in joint trial')
    call require(observation%drainage_response_mass_accounted_in_trial,'surface exchange mass accounted in joint trial')
    call require(observation%drainage_response%status==FMR_DRAIN_BIND_OK,'surface drainage binding OK')
    call require(observation%drainage_response_window_exchange_available,'surface exchange available from same candidate')
    call require(observation%drainage_response_window_signed_exchange_native==observation%drainage_response_window_signed_exchange_native, &
         'finite surface exchange')
    if(expected_surface_sign>0) then
      call require(observation%drainage_response_window_signed_exchange_native>0.0_real64,'positive surface exchange sign')
    else
      call require(observation%drainage_response_window_signed_exchange_native<0.0_real64,'negative surface exchange sign')
    end if

    call committed%current_time(committed_time,available)
    call require(available .and. abs(committed_time-t0)<1.0e-14_real64,'joint trial does not advance committed time')
    call require(committed%current_revision()==0_int64,'joint trial does not mutate committed revision')
    call candidate%origin_interval(candidate_t0,candidate_t1,available)
    call require(available .and. abs(candidate_t0-t0)<1.0e-14_real64 .and. abs(candidate_t1-t1)<1.0e-14_real64, &
         'joint candidate interval bound to one window')

    call backend%discard_trial_candidate(candidate,diagnostics)
    call require(.not.candidate%ready(),'joint candidate discard succeeds')
    call require(committed%current_revision()==0_int64,'discard returns to unchanged accepted origin')

    write(*,'(A,A)') 'SW_TRI01_A_CASE_PASS=',trim(label)
    write(*,'(A,ES24.16)') 'SW_TRI01_A_BOTTOM_EXCHANGE_CM=',result%bottom_outward_exchange_native
    write(*,'(A,ES24.16)') 'SW_TRI01_A_SURFACE_EXCHANGE_CM=',observation%drainage_response_window_signed_exchange_native
  end subroutine run_case

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

    parameters%parameter_set_id=51001_int64
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
    call fmr_new_b110_committed_state(committed,column_id,state,t0,ok)
    call require(ok,'base committed state initialized')

    template%template_id=510011_int64; template%physics_topology_id=510012_int64
    template%vertical_layout_id=510013_int64; template%state_layout_id=510014_int64
    template%solver_interface_id=510015_int64; template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
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
    config%transaction%retry_scale=0.5_real64; config%transaction%max_retries=2
    config%max_committed_substeps=8; config%progress_tolerance=0.0_real64
  end subroutine initialize_case

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'SW_TRI01_A_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_sw_tri01_a_joint_forcing_candidate
