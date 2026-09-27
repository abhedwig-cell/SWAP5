program test_fpe_temporal08_registry_equivalence
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_temporal_indicator_committed_state
  use mod_fmr_groundwater_head_forcing_adapter, only: fmr_groundwater_head_forcing_materializer_t
  use mod_fmr_groundwater_swap_participant, only: fmr_groundwater_temporal_budget_policy_t
  use mod_fmr_groundwater_participant_registry, only: fmr_groundwater_participant_registry_t, FMR_GW_REGISTRY_OK
  use mod_groundwater_swap_transaction_participant, only: groundwater_swap_trial_t, GW_SWAP_PARTICIPANT_OK
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t, groundwater_coupling_window_t
  use mod_modflow6_swap_prescribed_qbot_bottom_face, only: modflow6_prescribed_qbot_bottom_face_t, &
       materialize_modflow6_prescribed_qbot_bottom_face, MODFLOW6_BOTTOM_FACE_OK
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: H0_CM=-75.0_real64, DT=1.0e-4_real64, TOL=1.0e-12_real64
  real(real64), parameter :: PREDICTOR_QBOT=1.0e-6_real64, BASE_BUDGET=1.0e-5_real64
  real(real64), parameter :: COEFF=0.65_real64, HISTORY_RATE=400.0_real64
  integer(int64), parameter :: TILE_POLICY=880101_int64, TILE_MANUAL=880102_int64

  type(fmr_b110_physical_parameters_t), target :: parameters
  type(fmr_b110_physical_forcing_t) :: forcing
  type(fmr_logical_column_t) :: columns(2)
  type(fmr_template_t) :: templates(2)
  type(canonical_numerical_config_t) :: config_policy, config_manual
  type(kernel_committed_state_t), target :: committed(2)
  type(fmr_serialized_reference_backend_t), target :: backend
  type(fmr_groundwater_head_forcing_materializer_t), target :: materializer
  type(fmr_groundwater_participant_registry_t) :: registry
  type(fmr_groundwater_temporal_budget_policy_t) :: policy
  type(groundwater_swap_trial_t) :: trial_policy, trial_manual
  type(groundwater_head_datum_t) :: datum
  type(groundwater_coupling_window_t) :: window
  type(fixed_flux_top_boundary_provider_t), target :: top
  integer(int64) :: h_policy,h_manual
  integer :: status,pstatus
  logical :: ok
  real(real64) :: href, expected_budget

  call initialize_parameters(parameters)
  call initialize_forcing(forcing)
  call initialize_column_template(columns(1),templates(1),TILE_POLICY,1)
  call initialize_column_template(columns(2),templates(2),TILE_MANUAL,2)
  call initialize_config(config_policy,BASE_BUDGET)
  expected_budget=max(BASE_BUDGET,COEFF*DT*HISTORY_RATE)
  call initialize_config(config_manual,expected_budget)
  call initialize_committed(committed(1),parameters,TILE_POLICY,HISTORY_RATE,ok)
  call require(ok,'policy committed initialized')
  call initialize_committed(committed(2),parameters,TILE_MANUAL,HISTORY_RATE,ok)
  call require(ok,'manual committed initialized')
  call backend%initialize(top)
  call materializer%initialize(forcing)

  datum%available=.true.
  datum%datum_id=880100_int64
  datum%bottom_boundary_elevation_m=0.0_real64
  window%t0=0.0_real64
  window%t1=DT
  call compute_origin_head(parameters,datum,href,status)
  call require(status==MODFLOW6_BOTTOM_FACE_OK,'origin head')

  policy%enabled=.true.
  policy%coefficient=COEFF
  policy%floor_cm=BASE_BUDGET

  call registry%initialize(2,status)
  call require(status==FMR_GW_REGISTRY_OK,'registry initialized')
  call registry%bind(TILE_POLICY,backend,columns(1),templates(1),parameters,committed(1),materializer, &
       config_policy,datum,h_policy,status,temporal_budget_policy=policy)
  call require(status==FMR_GW_REGISTRY_OK,'policy bind')
  call registry%bind(TILE_MANUAL,backend,columns(2),templates(2),parameters,committed(2),materializer, &
       config_manual,datum,h_manual,status)
  call require(status==FMR_GW_REGISTRY_OK,'manual bind')

  call registry%capture_origin(h_policy,pstatus,status)
  call require(status==FMR_GW_REGISTRY_OK .and. pstatus==GW_SWAP_PARTICIPANT_OK,'policy capture')
  call registry%capture_origin(h_manual,pstatus,status)
  call require(status==FMR_GW_REGISTRY_OK .and. pstatus==GW_SWAP_PARTICIPANT_OK,'manual capture')

  call registry%trial_from_origin(h_policy,window,href,trial_policy,pstatus,status)
  call require(status==FMR_GW_REGISTRY_OK .and. pstatus==GW_SWAP_PARTICIPANT_OK .and. trial_policy%valid, &
       'policy trial')
  call registry%trial_from_origin(h_manual,window,href,trial_manual,pstatus,status)
  call require(status==FMR_GW_REGISTRY_OK .and. pstatus==GW_SWAP_PARTICIPANT_OK .and. trial_manual%valid, &
       'manual trial')

  call require(trial_policy%q_swap_m_per_s == trial_manual%q_swap_m_per_s,'q exact equivalence')
  call require(trial_policy%bottom_outward_exchange_cm == trial_manual%bottom_outward_exchange_cm, &
       'exchange exact equivalence')
  call require(trial_policy%response_tangent_available .and. trial_manual%response_tangent_available, &
       'tangent available')
  call require(trial_policy%dq_swap_dh_per_s == trial_manual%dq_swap_dh_per_s,'tangent exact equivalence')
  call require(ieee_is_finite(trial_policy%q_swap_m_per_s),'finite q')
  call require(config_policy%model_temporal_indicator_budget_available,'base config still available')
  call require(config_policy%model_temporal_indicator_budget == BASE_BUDGET,'base config immutable')
  call require(config_manual%model_temporal_indicator_budget == expected_budget,'manual config preserved')
  call require(committed(1)%current_revision()==0_int64 .and. committed(2)%current_revision()==0_int64, &
       'trials do not mutate committed state')

  call registry%discard_candidate(h_policy,status)
  call require(status==FMR_GW_REGISTRY_OK,'discard policy')
  call registry%discard_candidate(h_manual,status)
  call require(status==FMR_GW_REGISTRY_OK,'discard manual')

  write(*,'(A,ES24.16E3)') 'TEMPORAL08_EXPECTED_BUDGET=',expected_budget
  write(*,'(A,ES24.16E3)') 'TEMPORAL08_Q=',trial_policy%q_swap_m_per_s
  write(*,'(A,ES24.16E3)') 'TEMPORAL08_TANGENT=',trial_policy%dq_swap_dh_per_s
  write(*,'(A)') 'TEMPORAL08_REGISTRY_POLICY_MANUAL_EQUIVALENCE=PASS'
  write(*,'(A)') 'TEMPORAL08_REGISTERED_BASE_CONFIG_IMMUTABLE=PASS'
  write(*,'(A)') 'FPE_TEMPORAL08_P1_REGISTRY=PASS'

contains

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer::k
    p%parameter_set_id=880100_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod); p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=0.032_real64; p%cofgen(2,k)=0.423_real64; p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64; p%cofgen(5,k)=0.365_real64; p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k); p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64; p%cofgen(10,k)=p%cofgen(3,k); p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k); p%cofgen(22,k)=-1.0e6_real64; p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=5; p%swkimpl=0; p%swkmean=1; p%swsophy=0
    p%max_iterations=48; p%max_backtracking=16; p%min_step_duration=1.0e-10_real64
    p%compartment_balance_tolerance=TOL; p%total_balance_tolerance=TOL
    p%head_abs_tolerance=TOL; p%head_rel_tolerance=TOL; p%ponding_tolerance=TOL
    p%root_extraction_active=.false.; p%macropore_active=.false.; p%snow_active=.false.
    p%hysteresis_active=.false.; p%tabulated_hydraulics_active=.false.; p%elasticity_active=.false.
    p%frost_active=.false.; p%soil_temperature_active=.false.; p%drainage_response_active=.false.
  end subroutine initialize_parameters

  subroutine initialize_forcing(f)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    f%top_flux=PREDICTOR_QBOT; f%top_head=H0_CM
    f%bottom_flux=PREDICTOR_QBOT; f%bottom_head=H0_CM
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64
    f%subsurface_irrigation_source=0.0_real64
    f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_column_template(c,t,id,slot)
    type(fmr_logical_column_t),intent(out)::c
    type(fmr_template_t),intent(out)::t
    integer(int64),intent(in)::id
    integer,intent(in)::slot
    t%template_id=880100_int64+int(slot,int64)
    t%physics_topology_id=880110_int64; t%vertical_layout_id=880120_int64
    t%state_layout_id=880130_int64; t%solver_interface_id=880140_int64
    t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=id; c%template_id=t%template_id; c%parameter_ref=1_int64
    c%state_handle=int(slot,int64); c%forcing_handle=1_int64; c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_template

  subroutine initialize_config(c,budget)
    type(canonical_numerical_config_t),intent(out)::c
    real(real64),intent(in)::budget
    c%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    c%transaction%temporal_tolerance=0.0_real64
    c%transaction%mass_tolerance=TOL
    c%transaction%retry_scale=0.5_real64
    c%transaction%max_retries=8
    c%max_committed_substeps=32
    c%progress_tolerance=0.0_real64
    c%model_temporal_indicator_budget_available=.true.
    c%model_temporal_indicator_budget=budget
    c%accepted_trajectory_direction%requested=.false.
  end subroutine initialize_config

  subroutine initialize_committed(state,p,lineage,rate,initialized)
    type(kernel_committed_state_t),intent(out)::state
    type(fmr_b110_physical_parameters_t),intent(in)::p
    integer(int64),intent(in)::lineage
    real(real64),intent(in)::rate
    logical,intent(out)::initialized
    type(fmr_b110_physical_state_t)::physical
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    real(real64)::previous_derivative(numnod)
    integer::i
    heads(1)=H0_CM
    do i=2,numnod
      heads(i)=heads(i-1)+p%node_distance(i)
    end do
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,DT)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    physical%active_nodes=numnod
    allocate(physical%pressure_head(numnod),physical%water_content(numnod))
    physical%pressure_head=heads; physical%water_content=water
    physical%ponding_depth=0.0_real64; physical%groundwater_level=-2.0_real64
    previous_derivative=rate
    call fmr_new_b110_temporal_indicator_committed_state(state,lineage,physical,0.0_real64,initialized,previous_derivative)
  end subroutine initialize_committed

  subroutine compute_origin_head(p,datum_value,head_m,status)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(groundwater_head_datum_t),intent(in)::datum_value
    real(real64),intent(out)::head_m
    integer,intent(out)::status
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    type(modflow6_prescribed_qbot_bottom_face_t)::face
    real(real64)::heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    integer::i
    heads(1)=H0_CM
    do i=2,numnod
      heads(i)=heads(i-1)+p%node_distance(i)
    end do
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,DT)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    call materialize_modflow6_prescribed_qbot_bottom_face(heads(numnod),conductivity(numnod),PREDICTOR_QBOT, &
         0.5_real64*p%dz(numnod),datum_value,face,status)
    if(status==MODFLOW6_BOTTOM_FACE_OK)then
      head_m=face%hydraulic_head_m
    else
      head_m=0.0_real64
    end if
  end subroutine compute_origin_head

  subroutine require(condition,message)
    logical,intent(in)::condition
    character(len=*),intent(in)::message
    if(.not.condition)then
      write(*,'(A,1X,A)') 'TEMPORAL08_P1_FAIL',trim(message)
      error stop 1
    end if
  end subroutine require
end program test_fpe_temporal08_registry_equivalence
