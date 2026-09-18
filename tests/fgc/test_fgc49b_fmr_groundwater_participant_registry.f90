program test_fgc49b_fmr_groundwater_participant_registry
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_temporal_indicator_committed_state
  use mod_fmr_groundwater_head_forcing_adapter, only: fmr_groundwater_head_forcing_materializer_t
  use mod_fmr_groundwater_participant_registry, only: fmr_groundwater_participant_registry_t, &
       FMR_GW_REGISTRY_OK, FMR_GW_REGISTRY_DUPLICATE_TILE, FMR_GW_REGISTRY_UNKNOWN_HANDLE
  use mod_groundwater_swap_transaction_participant, only: groundwater_swap_trial_t
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t, groundwater_coupling_window_t, &
       groundwater_interface_state_t, swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s, &
       pair_groundwater_flux_from_swap, GW_INTERFACE_OK
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, &
       groundwater_interface_mass_snapshot_t
  use mod_modflow6_swap_predictor_response, only: modflow6_swap_predictor_response_t
  use mod_modflow6_swap_prescribed_qbot_bottom_face, only: modflow6_prescribed_qbot_bottom_face_t, &
       materialize_modflow6_prescribed_qbot_bottom_face, MODFLOW6_BOTTOM_FACE_OK
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_soil_water_accepted_step_direction_contract, only: SW_STEP_CONTROL_BOTTOM_FLUX
  implicit none

  integer, parameter :: N=2
  real(real64), parameter :: H0_CM=-75.0_real64
  real(real64), parameter :: DURATION_DAY=1.0e-4_real64
  real(real64), parameter :: PREDICTOR_QBOT=1.0e-6_real64
  real(real64), parameter :: HEAD_BUDGET=1.0e-5_real64
  real(real64), parameter :: TOL=1.0e-12_real64
  real(real64), parameter :: FRACTION(N)=[0.4_real64,0.6_real64]
  integer(int64), parameter :: TILE_ID(N)=[490001_int64,490002_int64]
  integer(int64), parameter :: LINEAGE_ID(N)=[590001_int64,590002_int64]
  integer(int64), parameter :: LEDGER_ID(N)=[690001_int64,690002_int64]

  type(fmr_b110_physical_parameters_t), target :: predictor_parameters(N), corrector_parameters(N)
  type(fmr_b110_physical_forcing_t), target :: base_forcing(N)
  type(fmr_logical_column_t), target :: column(N)
  type(fmr_template_t), target :: template(N)
  type(kernel_committed_state_t), target :: committed(N)
  type(fmr_serialized_reference_backend_t), target :: predictor_backend(N), corrector_backend(N)
  type(fmr_groundwater_head_forcing_materializer_t), target :: materializer(N)
  type(groundwater_interface_mass_ledger_t), target :: ledger(N)
  type(fixed_flux_top_boundary_provider_t), target :: predictor_top(N), corrector_top(N)
  type(canonical_numerical_config_t), target :: predictor_config, corrector_config
  type(fmr_groundwater_participant_registry_t) :: registry
  type(groundwater_head_datum_t) :: datum
  type(groundwater_coupling_window_t) :: window
  type(groundwater_interface_state_t) :: accepted(N)
  type(modflow6_swap_predictor_response_t) :: response(N), response_retry
  type(groundwater_swap_trial_t) :: first_trial, final_trial(N), abort_trial
  type(groundwater_interface_mass_snapshot_t) :: snap
  integer(int64) :: handle(N), duplicate_handle
  integer(int64) :: tile_value, lineage_value, ledger_value
  integer :: i,status
  logical :: ok,available
  real(real64) :: first_q, expected_exchange

  call initialize_configs(predictor_config,corrector_config)
  datum%available=.true.
  datum%datum_id=490001_int64
  datum%bottom_boundary_elevation_m=0.0_real64
  window%t0=0.0_real64
  window%t1=DURATION_DAY

  do i=1,N
    call initialize_parameters(predictor_parameters(i),SW_STEP_CONTROL_BOTTOM_FLUX,710000_int64+i)
    call initialize_parameters(corrector_parameters(i),5,720000_int64+i)
    call initialize_forcing(base_forcing(i),PREDICTOR_QBOT)
    call initialize_column_template(column(i),template(i),LINEAGE_ID(i),730000_int64+i)
    call initialize_committed(committed(i),predictor_parameters(i),LINEAGE_ID(i),ok)
    call require(ok,'committed state')
    call predictor_backend(i)%initialize(predictor_top(i))
    call corrector_backend(i)%initialize(corrector_top(i))
    call materializer(i)%initialize(base_forcing(i))
    call build_accepted_interface(committed(i),predictor_parameters(i),datum,PREDICTOR_QBOT,accepted(i),ok)
    call require(ok,'accepted interface')
  end do

  call registry%initialize(3,status)
  call require(status==FMR_GW_REGISTRY_OK,'registry initialize')

  do i=1,N
    call registry%bind_context(TILE_ID(i),LINEAGE_ID(i),LEDGER_ID(i),predictor_backend(i),corrector_backend(i), &
         column(i),template(i),predictor_parameters(i),corrector_parameters(i),base_forcing(i),committed(i), &
         materializer(i),predictor_config,corrector_config,ledger(i),handle(i),status)
    call require(status==FMR_GW_REGISTRY_OK .and. handle(i)>0_int64,'bind context')
  end do
  call require(handle(1)/=handle(2),'unique handles')
  call require(registry%bound_count()==2,'bound count')

  call registry%bind_context(TILE_ID(1),LINEAGE_ID(1),699999_int64,predictor_backend(1),corrector_backend(1), &
       column(1),template(1),predictor_parameters(1),corrector_parameters(1),base_forcing(1),committed(1), &
       materializer(1),predictor_config,corrector_config,ledger(1),duplicate_handle,status)
  call require(status==FMR_GW_REGISTRY_DUPLICATE_TILE .and. duplicate_handle==0_int64,'duplicate tile rejected')

  do i=1,N
    call registry%tile_identity(handle(i),tile_value,lineage_value,ledger_value,available)
    call require(available,'tile identity available')
    call require(tile_value==TILE_ID(i) .and. lineage_value==LINEAGE_ID(i) .and. ledger_value==LEDGER_ID(i), &
         'tile identity values')
  end do

  do i=1,N
    call registry%begin_window(handle(i),window,datum,PREDICTOR_QBOT,accepted(i),800001_int64,900001_int64, &
         910001_int64,0_int64,response(i),status)
    call require(status==FMR_GW_REGISTRY_OK .and. response(i)%valid,'begin window predictor')
    call require(response(i)%lineage%swap_lineage_id==LINEAGE_ID(i),'predictor lineage')
    call require(committed(i)%current_revision()==0_int64,'predictor noncommitting')
  end do

  call registry%corrector_trial(handle(1),accepted(1)%h_groundwater_m,first_trial,status)
  call require(status==FMR_GW_REGISTRY_OK .and. first_trial%valid,'first same-origin corrector')
  first_q=first_trial%q_swap_m_per_s
  call registry%discard_candidate(handle(1),status)
  call require(status==FMR_GW_REGISTRY_OK,'discard first corrector')
  call require(committed(1)%current_revision()==0_int64,'discard leaves committed revision')
  call registry%corrector_trial(handle(1),accepted(1)%h_groundwater_m,final_trial(1),status)
  call require(status==FMR_GW_REGISTRY_OK .and. final_trial(1)%valid,'second same-origin corrector')
  call require(same(first_q,final_trial(1)%q_swap_m_per_s),'same-origin repeatability')

  call registry%corrector_trial(handle(2),accepted(2)%h_groundwater_m,abort_trial,status)
  call require(status==FMR_GW_REGISTRY_OK .and. abort_trial%valid,'abort-path corrector')
  call registry%prepare_ledger(handle(2),FRACTION(2),status)
  call require(status==FMR_GW_REGISTRY_OK .and. registry%ledger_publication_ready(handle(2)),'abort-path ledger prepared')
  call registry%abort_prepublication(handle(2),status)
  call require(status==FMR_GW_REGISTRY_OK,'prepublication abort')
  call require(committed(2)%current_revision()==0_int64,'abort leaves committed state')
  call ledger(2)%snapshot(snap)
  call require(snap%committed_exchange_count==0 .and. .not.snap%trial_active .and. .not.snap%prepared_active, &
       'abort leaves no ledger publication')

  call registry%begin_window(handle(2),window,datum,PREDICTOR_QBOT,accepted(2),800001_int64,900001_int64, &
       910001_int64,0_int64,response_retry,status)
  call require(status==FMR_GW_REGISTRY_OK .and. response_retry%valid,'begin window after abort')
  call require(same(response(2)%q_u_m_per_s,response_retry%q_u_m_per_s),'predictor repeatability after abort')
  call registry%corrector_trial(handle(2),accepted(2)%h_groundwater_m,final_trial(2),status)
  call require(status==FMR_GW_REGISTRY_OK .and. final_trial(2)%valid,'final corrector handle2')

  do i=1,N
    call require(registry%swap_publication_ready(handle(i)),'swap publication ready')
    call registry%prepare_ledger(handle(i),FRACTION(i),status)
    call require(status==FMR_GW_REGISTRY_OK,'prepare weighted ledger')
    call require(registry%ledger_publication_ready(handle(i)),'ledger publication ready')
    call require(committed(i)%current_revision()==0_int64,'all preflights before SWAP commit')
  end do

  do i=1,N
    call registry%commit_swap(handle(i),status)
    call require(status==FMR_GW_REGISTRY_OK,'kernel-owned SWAP commit')
    call require(committed(i)%current_revision()==1_int64,'external committed state advanced')
  end do
  do i=1,N
    call registry%commit_ledger(handle(i),status)
    call require(status==FMR_GW_REGISTRY_OK,'ledger commit')
    call ledger(i)%snapshot(snap)
    expected_exchange=FRACTION(i)*final_trial(i)%bottom_outward_exchange_cm*0.01_real64
    call require(snap%committed_exchange_count==1,'ledger commit count')
    call require(same(snap%committed_swap_outward_exchange_m,expected_exchange),'weighted ledger exchange')
  end do

  call registry%unbind_context(handle(1),status)
  call require(status==FMR_GW_REGISTRY_OK .and. registry%bound_count()==1,'unbind completed handle')
  call registry%tile_identity(handle(1),tile_value,lineage_value,ledger_value,available)
  call require(.not.available,'stale handle invalidated')
  call registry%corrector_trial(handle(1),accepted(1)%h_groundwater_m,first_trial,status)
  call require(status==FMR_GW_REGISTRY_UNKNOWN_HANDLE,'stale handle fail closed')

  write(*,'(A)') 'FGC49B_REAL_FMR_PREDICTOR_SERVICE=PASS'
  write(*,'(A)') 'FGC49B_HANDLE_REGISTRY_UNIQUE_OWNERSHIP=PASS'
  write(*,'(A)') 'FGC49B_SAME_ORIGIN_REPEATABLE_CORRECTORS=PASS'
  write(*,'(A)') 'FGC49B_PREPUBLICATION_ABORT_AND_REBEGIN=PASS'
  write(*,'(A)') 'FGC49B_ALL_PREFLIGHTS_BEFORE_SWAP_COMMIT=PASS'
  write(*,'(A)') 'FGC49B_EXTERNAL_COMMITTED_STATE_KERNEL_OWNED=PASS'
  write(*,'(A)') 'FGC49B_AREA_WEIGHTED_LEDGER_COMMIT=PASS'
  write(*,'(A)') 'FGC49B_STALE_HANDLE_FAIL_CLOSED=PASS'
  write(*,'(A)') 'F-GC49B PARTICIPANT REGISTRY GATE PASS'

contains

  subroutine initialize_parameters(p,bottom_mode,parameter_id)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer,intent(in)::bottom_mode
    integer(int64),intent(in)::parameter_id
    integer::k
    p%parameter_set_id=parameter_id
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z
    p%dz=dz
    p%node_distance=disnod(1:numnod)
    p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=0.032_real64
      p%cofgen(2,k)=0.423_real64
      p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64
      p%cofgen(5,k)=0.365_real64
      p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k)
      p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64
      p%cofgen(10,k)=p%cofgen(3,k)
      p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k)
      p%cofgen(22,k)=-1.0e6_real64
      p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=bottom_mode
    p%swkimpl=0
    p%swkmean=1
    p%swsophy=0
    p%max_iterations=16
    p%max_backtracking=8
    p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=TOL
    p%total_balance_tolerance=TOL
    p%head_abs_tolerance=TOL
    p%head_rel_tolerance=TOL
    p%ponding_tolerance=TOL
    p%root_extraction_active=.false.
    p%macropore_active=.false.
    p%snow_active=.false.
    p%hysteresis_active=.false.
    p%tabulated_hydraulics_active=.false.
    p%elasticity_active=.false.
    p%frost_active=.false.
    p%soil_temperature_active=.false.
    p%drainage_response_active=.false.
  end subroutine initialize_parameters

  subroutine initialize_forcing(f,q)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    real(real64),intent(in)::q
    f%top_flux=q
    f%top_head=H0_CM
    f%bottom_flux=q
    f%bottom_head=H0_CM
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64
    f%subsurface_irrigation_source=0.0_real64
    f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_column_template(c,t,lineage_id,template_id)
    type(fmr_logical_column_t),intent(out)::c
    type(fmr_template_t),intent(out)::t
    integer(int64),intent(in)::lineage_id,template_id
    t%template_id=template_id
    t%physics_topology_id=740001_int64
    t%vertical_layout_id=740002_int64
    t%state_layout_id=740003_int64
    t%solver_interface_id=740004_int64
    t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=lineage_id
    c%template_id=template_id
    c%parameter_ref=lineage_id
    c%state_handle=lineage_id
    c%forcing_handle=lineage_id
    c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_template

  subroutine initialize_configs(pred,corr)
    type(canonical_numerical_config_t),intent(out)::pred,corr
    pred%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    pred%transaction%temporal_tolerance=0.0_real64
    pred%transaction%mass_tolerance=TOL
    pred%transaction%retry_scale=0.5_real64
    pred%transaction%max_retries=8
    pred%max_committed_substeps=32
    pred%progress_tolerance=0.0_real64
    pred%model_temporal_indicator_budget_available=.true.
    pred%model_temporal_indicator_budget=HEAD_BUDGET
    pred%accepted_trajectory_direction%requested=.true.
    pred%accepted_trajectory_direction%control_coordinate=SW_STEP_CONTROL_BOTTOM_FLUX
    corr=pred
    corr%accepted_trajectory_direction%requested=.false.
  end subroutine initialize_configs

  subroutine initialize_committed(state,p,lineage_id,initialized)
    type(kernel_committed_state_t),intent(out)::state
    type(fmr_b110_physical_parameters_t),intent(in)::p
    integer(int64),intent(in)::lineage_id
    logical,intent(out)::initialized
    type(fmr_b110_physical_state_t)::physical
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    real(real64)::accepted_predecessor_right_derivative(numnod)
    integer::k

    heads(1)=H0_CM
    do k=2,numnod
      heads(k)=heads(k-1)+p%node_distance(k)
    end do
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,DURATION_DAY)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    physical%active_nodes=numnod
    allocate(physical%pressure_head(numnod),physical%water_content(numnod))
    physical%pressure_head=heads
    physical%water_content=water
    physical%ponding_depth=0.0_real64
    physical%groundwater_level=-2.0_real64
    accepted_predecessor_right_derivative=0.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(state,lineage_id,physical,0.0_real64,initialized, &
         accepted_predecessor_right_derivative)
  end subroutine initialize_committed

  subroutine build_accepted_interface(state,p,datum_value,qbot,interface_value,initialized)
    type(kernel_committed_state_t),intent(in)::state
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(groundwater_head_datum_t),intent(in)::datum_value
    real(real64),intent(in)::qbot
    type(groundwater_interface_state_t),intent(out)::interface_value
    logical,intent(out)::initialized

    class(transaction_state_t),allocatable::snapshot
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    type(modflow6_prescribed_qbot_bottom_face_t)::face
    real(real64),allocatable::theta(:),conductivity(:),capacity(:),dkdh(:)
    real(real64)::qswap,qgw
    integer::face_status,flux_status
    logical::available

    initialized=.false.
    call state%snapshot(snapshot,available)
    if(.not.available .or. .not.allocated(snapshot))return
    select type(physical=>snapshot)
    class is(fmr_b110_physical_state_t)
      allocate(theta(physical%active_nodes),conductivity(physical%active_nodes),capacity(physical%active_nodes), &
           dkdh(physical%active_nodes))
      call initialize_b110_default_mvg_parameters(hp,p%cofgen)
      call bind_b110_default_mvg_provider(provider,hp,DURATION_DAY)
      call provider%evaluate(physical%pressure_head,theta,conductivity,capacity,dkdh)
      call materialize_modflow6_prescribed_qbot_bottom_face(physical%pressure_head(physical%active_nodes), &
           conductivity(physical%active_nodes),qbot,0.5_real64*p%dz(physical%active_nodes),datum_value,face,face_status)
      if(face_status/=MODFLOW6_BOTTOM_FACE_OK .or. .not.face%valid)return
      call swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s(qbot,qswap,flux_status)
      if(flux_status/=GW_INTERFACE_OK)return
      call pair_groundwater_flux_from_swap(qswap,qgw,flux_status)
      if(flux_status/=GW_INTERFACE_OK)return
      interface_value%h_swap_m=face%hydraulic_head_m
      interface_value%h_groundwater_m=face%hydraulic_head_m
      interface_value%q_swap_m_per_s=qswap
      interface_value%q_groundwater_m_per_s=qgw
      initialized=interface_value%finite()
    class default
      return
    end select
  end subroutine build_accepted_interface

  pure logical function same(a,b) result(matches)
    real(real64),intent(in)::a,b
    real(real64)::scale
    scale=max(1.0_real64,abs(a),abs(b))
    matches=abs(a-b)<=256.0_real64*epsilon(1.0_real64)*scale
  end function same

  subroutine require(condition,message)
    logical,intent(in)::condition
    character(len=*),intent(in)::message
    if(.not.condition)then
      write(*,'(A,1X,A)')'FGC49B_FAIL',trim(message)
      error stop 1
    end if
  end subroutine require
end program test_fgc49b_fmr_groundwater_participant_registry
