program test_fgc49b_fmr_participant_registry
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
  use mod_fmr_groundwater_participant_registry, only: fmr_groundwater_participant_registry_t, &
       FMR_GW_REGISTRY_OK, FMR_GW_REGISTRY_DUPLICATE_TILE, FMR_GW_REGISTRY_INVALID_HANDLE, &
       FMR_GW_REGISTRY_RELEASE_BUSY, FMR_GW_REGISTRY_REINITIALIZE_BUSY
  use mod_groundwater_swap_transaction_participant, only: groundwater_swap_trial_t, GW_SWAP_PARTICIPANT_OK
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t, groundwater_coupling_window_t
  use mod_modflow6_swap_prescribed_qbot_bottom_face, only: modflow6_prescribed_qbot_bottom_face_t, &
       materialize_modflow6_prescribed_qbot_bottom_face, MODFLOW6_BOTTOM_FACE_OK
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: h0_cm=-75.0_real64
  real(real64), parameter :: duration=1.0e-4_real64
  real(real64), parameter :: tol=1.0e-12_real64
  real(real64), parameter :: predictor_qbot=1.0e-6_real64
  real(real64), parameter :: head_budget=1.0e-5_real64
  integer(int64), parameter :: tile1=590049_int64, tile2=590050_int64

  type(fmr_b110_physical_parameters_t), target :: parameters
  type(fmr_b110_physical_forcing_t) :: base_forcing
  type(fmr_logical_column_t) :: columns(2)
  type(fmr_template_t) :: templates(2)
  type(canonical_numerical_config_t) :: config
  type(kernel_committed_state_t), target :: committed(2)
  type(fmr_serialized_reference_backend_t), target :: backend
  type(fmr_groundwater_head_forcing_materializer_t), target :: materializer
  type(fmr_groundwater_participant_registry_t) :: registry
  type(groundwater_swap_trial_t) :: trial1,trial2
  type(groundwater_head_datum_t) :: datum
  type(groundwater_coupling_window_t) :: window
  type(fixed_flux_top_boundary_provider_t), target :: top
  integer(int64) :: h1,h2,h3,tile_id,lineage,revision
  integer :: status,pstatus
  logical :: ok,ready,did_commit,has_origin,has_candidate
  real(real64) :: origin_head_m

  call initialize_parameters(parameters)
  call initialize_forcing(base_forcing,predictor_qbot)
  call initialize_column_template(columns(1),templates(1),tile1,1)
  call initialize_column_template(columns(2),templates(2),tile2,2)
  call initialize_config(config)
  call initialize_committed(committed(1),parameters,tile1,ok)
  call require(ok,'committed 1 initialized')
  call initialize_committed(committed(2),parameters,tile2,ok)
  call require(ok,'committed 2 initialized')
  call backend%initialize(top)
  call materializer%initialize(base_forcing)
  datum%available=.true.; datum%datum_id=590049_int64; datum%bottom_boundary_elevation_m=0.0_real64
  window%t0=0.0_real64; window%t1=duration
  call compute_origin_head(parameters,datum,origin_head_m,status)
  call require(status==MODFLOW6_BOTTOM_FACE_OK,'accepted origin head')

  call registry%initialize(3,status)
  call require(status==FMR_GW_REGISTRY_OK .and. registry%capacity()==3,'registry initialized')

  call registry%bind(tile1,backend,columns(1),templates(1),parameters,committed(1),materializer,config,datum,h1,status)
  call require(status==FMR_GW_REGISTRY_OK .and. h1>0_int64,'bind first handle')
  call registry%bind(tile2,backend,columns(2),templates(2),parameters,committed(2),materializer,config,datum,h2,status)
  call require(status==FMR_GW_REGISTRY_OK .and. h2>h1,'bind second unique handle')
  call require(registry%active_count()==2,'two active registrations')

  call registry%bind(tile1,backend,columns(1),templates(1),parameters,committed(1),materializer,config,datum,h3,status)
  call require(status==FMR_GW_REGISTRY_DUPLICATE_TILE .and. h3==0_int64,'duplicate tile rejected')

  call registry%capture_origin(h1,pstatus,status)
  call require(status==FMR_GW_REGISTRY_OK .and. pstatus==GW_SWAP_PARTICIPANT_OK,'capture handle1 origin')
  call registry%capture_origin(h2,pstatus,status)
  call require(status==FMR_GW_REGISTRY_OK .and. pstatus==GW_SWAP_PARTICIPANT_OK,'capture handle2 origin')

  call registry%identity(h1,tile_id,lineage,revision,has_origin,has_candidate,status)
  call require(status==FMR_GW_REGISTRY_OK .and. tile_id==tile1 .and. lineage==tile1 .and. revision==0_int64, &
       'handle1 identity')
  call require(has_origin .and. .not.has_candidate,'handle1 origin state')
  call registry%identity(h2,tile_id,lineage,revision,has_origin,has_candidate,status)
  call require(status==FMR_GW_REGISTRY_OK .and. tile_id==tile2 .and. lineage==tile2 .and. revision==0_int64, &
       'handle2 identity')

  call registry%trial_from_origin(h1,window,origin_head_m,trial1,pstatus,status)
  call require(status==FMR_GW_REGISTRY_OK .and. pstatus==GW_SWAP_PARTICIPANT_OK .and. trial1%valid,'trial handle1')
  call registry%trial_from_origin(h2,window,origin_head_m,trial2,pstatus,status)
  call require(status==FMR_GW_REGISTRY_OK .and. pstatus==GW_SWAP_PARTICIPANT_OK .and. trial2%valid,'trial handle2')
  call require(ieee_is_finite(trial1%q_swap_m_per_s) .and. ieee_is_finite(trial2%q_swap_m_per_s),'finite exchanges')
  call require(committed(1)%current_revision()==0_int64 .and. committed(2)%current_revision()==0_int64, &
       'trials do not mutate committed state')
  call require(.not.registry%quiescent(),'live candidates make registry nonquiescent')

  call registry%release(h1,status)
  call require(status==FMR_GW_REGISTRY_RELEASE_BUSY,'release with live candidate rejected')
  call registry%discard_candidate(h1,status)
  call require(status==FMR_GW_REGISTRY_OK,'discard handle1')
  call registry%release(h1,status)
  call require(status==FMR_GW_REGISTRY_OK,'release handle1 after discard')
  call registry%identity(h1,tile_id,lineage,revision,has_origin,has_candidate,status)
  call require(status==FMR_GW_REGISTRY_INVALID_HANDLE,'released handle stale')

  call registry%publication_ready(h2,window,ready,status)
  call require(status==FMR_GW_REGISTRY_OK .and. ready,'handle2 publication ready')
  call registry%commit_candidate(h2,window,did_commit,pstatus,status)
  call require(status==FMR_GW_REGISTRY_OK .and. pstatus==GW_SWAP_PARTICIPANT_OK .and. did_commit,'commit handle2')
  call require(committed(2)%current_revision()==1_int64,'handle2 kernel revision advanced')
  call require(committed(1)%current_revision()==0_int64,'handle1 committed state isolated')
  call require(registry%quiescent(),'registry quiescent after surviving commit')
  call require(registry%active_count()==1,'one active registration after release')

  call registry%initialize(2,status)
  call require(status==FMR_GW_REGISTRY_REINITIALIZE_BUSY,'active registry cannot reinitialize')
  call registry%release(h2,status)
  call require(status==FMR_GW_REGISTRY_OK .and. registry%active_count()==0,'release handle2')

  call registry%initialize(2,status)
  call require(status==FMR_GW_REGISTRY_OK,'quiescent registry reinitialized')
  call registry%bind(tile1,backend,columns(1),templates(1),parameters,committed(1),materializer,config,datum,h3,status)
  call require(status==FMR_GW_REGISTRY_OK .and. h3>h2,'monotonic handle after reinitialize')
  call registry%identity(h1,tile_id,lineage,revision,has_origin,has_candidate,status)
  call require(status==FMR_GW_REGISTRY_INVALID_HANDLE,'old handle remains stale after reinitialize')
  call registry%identity(h3,tile_id,lineage,revision,has_origin,has_candidate,status)
  call require(status==FMR_GW_REGISTRY_OK .and. tile_id==tile1,'new handle resolves after reinitialize')
  call registry%release(h3,status)
  call require(status==FMR_GW_REGISTRY_OK,'final release')

  write(*,'(A)') 'FGC49B_TWO_REAL_FMR_HANDLES=PASS'
  write(*,'(A)') 'FGC49B_HANDLE_ISOLATION=PASS'
  write(*,'(A)') 'FGC49B_SAME_ORIGIN_TRIAL_DELEGATION=PASS'
  write(*,'(A)') 'FGC49B_RELEASE_BUSY_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FGC49B_STALE_HANDLE_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FGC49B_MONOTONIC_HANDLE_ACROSS_REINITIALIZE=PASS'
  write(*,'(A)') 'FGC49B_KERNEL_REMAINS_COMMIT_OWNER=PASS'
  write(*,'(A)') 'F-GC49B FMR PARTICIPANT REGISTRY GATE PASS'

contains

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer::k
    p%parameter_set_id=590049_int64; p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod); p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=0.032_real64; p%cofgen(2,k)=0.423_real64; p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64; p%cofgen(5,k)=0.365_real64; p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k); p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64; p%cofgen(10,k)=p%cofgen(3,k); p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k); p%cofgen(22,k)=-1.0e6_real64; p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=5; p%swkimpl=0; p%swkmean=1; p%swsophy=0; p%max_iterations=16; p%max_backtracking=8
    p%min_step_duration=1.0e-8_real64; p%compartment_balance_tolerance=tol; p%total_balance_tolerance=tol
    p%head_abs_tolerance=tol; p%head_rel_tolerance=tol; p%ponding_tolerance=tol
    p%root_extraction_active=.false.; p%macropore_active=.false.; p%snow_active=.false.
    p%hysteresis_active=.false.; p%tabulated_hydraulics_active=.false.; p%elasticity_active=.false.
    p%frost_active=.false.; p%soil_temperature_active=.false.; p%drainage_response_active=.false.
  end subroutine initialize_parameters

  subroutine initialize_forcing(f,q)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    real(real64),intent(in)::q
    f%top_flux=q; f%top_head=h0_cm; f%bottom_flux=q; f%bottom_head=h0_cm
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64; f%subsurface_irrigation_source=0.0_real64; f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_column_template(c,t,id,slot)
    type(fmr_logical_column_t),intent(out)::c
    type(fmr_template_t),intent(out)::t
    integer(int64),intent(in)::id
    integer,intent(in)::slot
    t%template_id=590000_int64+slot; t%physics_topology_id=590010_int64
    t%vertical_layout_id=590020_int64; t%state_layout_id=590030_int64; t%solver_interface_id=590040_int64
    t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=id; c%template_id=t%template_id; c%parameter_ref=1_int64; c%state_handle=int(slot,int64)
    c%forcing_handle=1_int64; c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_template

  subroutine initialize_config(c)
    type(canonical_numerical_config_t),intent(out)::c
    c%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE; c%transaction%temporal_tolerance=0.0_real64
    c%transaction%mass_tolerance=tol; c%transaction%retry_scale=0.5_real64; c%transaction%max_retries=8
    c%max_committed_substeps=32; c%progress_tolerance=0.0_real64
    c%model_temporal_indicator_budget_available=.true.; c%model_temporal_indicator_budget=head_budget
    c%accepted_trajectory_direction%requested=.false.
  end subroutine initialize_config

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
    integer::i
    heads(1)=h0_cm
    do i=2,numnod
      heads(i)=heads(i-1)+p%node_distance(i)
    end do
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,duration)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    physical%active_nodes=numnod
    allocate(physical%pressure_head(numnod),physical%water_content(numnod))
    physical%pressure_head=heads; physical%water_content=water
    physical%ponding_depth=0.0_real64; physical%groundwater_level=-2.0_real64
    accepted_predecessor_right_derivative=0.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(state,lineage_id,physical,0.0_real64,initialized, &
         accepted_predecessor_right_derivative)
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
    heads(1)=h0_cm
    do i=2,numnod
      heads(i)=heads(i-1)+p%node_distance(i)
    end do
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,duration)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    call materialize_modflow6_prescribed_qbot_bottom_face(heads(numnod),conductivity(numnod),predictor_qbot, &
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
      write(*,'(A,1X,A)')'FGC49B_FAIL',trim(message)
      error stop 1
    end if
  end subroutine require
end program test_fgc49b_fmr_participant_registry
