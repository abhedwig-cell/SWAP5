program test_fgc44_real_fmr_participant
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
  use mod_fmr_groundwater_swap_participant, only: fmr_groundwater_swap_participant_t
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
  integer(int64), parameter :: column_id=540044_int64

  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_forcing_t) :: base_forcing
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(canonical_numerical_config_t) :: config
  type(kernel_committed_state_t) :: committed
  type(fmr_serialized_reference_backend_t) :: backend
  type(fmr_groundwater_head_forcing_materializer_t) :: materializer
  type(fmr_groundwater_swap_participant_t) :: participant
  type(groundwater_swap_trial_t) :: trial1, trial2
  type(groundwater_head_datum_t) :: datum
  type(groundwater_coupling_window_t) :: window
  type(fixed_flux_top_boundary_provider_t), target :: top
  class(transaction_state_t), allocatable :: snapshot
  logical :: ok, did_commit, available
  integer :: status
  real(real64) :: qeq, committed_time, origin_head_m

  call initialize_parameters(parameters)
  qeq=predictor_qbot
  call initialize_forcing(base_forcing,qeq)
  call initialize_column_template(column,template)
  call initialize_config(config)
  call initialize_committed(committed,parameters,ok)
  call require(ok,'real FMR committed state initialized')

  call backend%initialize(top)
  call materializer%initialize(base_forcing)
  datum%available=.true.
  datum%datum_id=540044_int64
  datum%bottom_boundary_elevation_m=0.0_real64
  window%t0=0.0_real64
  window%t1=duration
  call compute_origin_head(parameters,datum,origin_head_m,status)
  call require(status==MODFLOW6_BOTTOM_FACE_OK,'materialize accepted bottom-face head')

  call participant%capture_origin(committed,status)
  call require(status==GW_SWAP_PARTICIPANT_OK,'capture FMR accepted origin')
  call require(participant%captured_lineage_id()==column_id,'FMR lineage retained')
  call require(participant%captured_revision()==0_int64,'FMR revision retained')

  call participant%trial_from_origin(backend,column,template,parameters,committed,materializer,config,datum,window, &
       origin_head_m,trial1,status)
  call require(status==GW_SWAP_PARTICIPANT_OK .and. trial1%valid,'first real FMR prescribed-head trial')
  call require(ieee_is_finite(trial1%q_swap_m_per_s),'first real FMR exchange finite')
  call require(committed%current_revision()==0_int64,'trial does not mutate real FMR committed state')
  call participant%discard_candidate(backend)

  call participant%trial_from_origin(backend,column,template,parameters,committed,materializer,config,datum,window, &
       origin_head_m,trial2,status)
  call require(status==GW_SWAP_PARTICIPANT_OK .and. trial2%valid,'second real FMR prescribed-head trial')
  call require(ieee_is_finite(trial2%q_swap_m_per_s),'second real FMR exchange finite')
  call require(participant%publication_ready(committed,window),'real FMR candidate publication ready')
  call require(committed%current_revision()==0_int64,'real FMR preflight nonmutating')

  call participant%commit_candidate(backend,committed,window,did_commit,status)
  call require(did_commit .and. status==GW_SWAP_PARTICIPANT_OK,'real FMR candidate committed')
  call require(committed%current_revision()==1_int64,'real FMR kernel owns revision advancement')
  call committed%current_time(committed_time,available)
  call require(available .and. abs(committed_time-duration)<=64.0_real64*epsilon(1.0_real64),'real FMR time advanced')
  call committed%snapshot(snapshot,available)
  call require(available .and. allocated(snapshot),'real FMR committed snapshot available')
  select type(s=>snapshot)
  class is(fmr_b110_physical_state_t)
    call require(all(ieee_is_finite(s%pressure_head)) .and. all(ieee_is_finite(s%water_content)), &
         'real FMR committed physical state finite')
  class default
    call require(.false.,'real FMR committed state type')
  end select

  write(*,'(A)') 'FGC44_REAL_FMR_MODE5_MATERIALIZER=PASS'
  write(*,'(A)') 'FGC44_REAL_FMR_SAME_ORIGIN_CORRECTORS=PASS'
  write(*,'(A)') 'FGC44_REAL_FMR_PREFLIGHT_NONMUTATING=PASS'
  write(*,'(A)') 'FGC44_REAL_FMR_KERNEL_COMMIT=PASS'
  write(*,'(A,ES26.17E3)') 'FGC44_REAL_FMR_Q1_M_PER_S=',trial1%q_swap_m_per_s
  write(*,'(A,ES26.17E3)') 'FGC44_REAL_FMR_Q2_M_PER_S=',trial2%q_swap_m_per_s
  write(*,'(A)') 'F-GC44 REAL FMR PARTICIPANT GATE PASS'

contains

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer::k
    p%parameter_set_id=540044_int64; p%active_nodes=numnod
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

  subroutine initialize_column_template(c,t)
    type(fmr_logical_column_t),intent(out)::c
    type(fmr_template_t),intent(out)::t
    t%template_id=540001_int64; t%physics_topology_id=540002_int64; t%vertical_layout_id=540003_int64
    t%state_layout_id=540004_int64; t%solver_interface_id=540005_int64; t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=column_id; c%template_id=t%template_id; c%parameter_ref=1_int64; c%state_handle=1_int64
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

  subroutine initialize_committed(committed,p,initialized)
    type(kernel_committed_state_t),intent(out)::committed
    type(fmr_b110_physical_parameters_t),intent(in)::p
    logical,intent(out)::initialized
    type(fmr_b110_physical_state_t)::state
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    real(real64)::accepted_predecessor_right_derivative(numnod)
    integer :: i
    heads(1)=h0_cm
    do i=2,numnod
      heads(i)=heads(i-1)+p%node_distance(i)
    end do
    call initialize_b110_default_mvg_parameters(hp,p%cofgen); call bind_b110_default_mvg_provider(provider,hp,duration)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    state%active_nodes=numnod; allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water; state%ponding_depth=0.0_real64; state%groundwater_level=-2.0_real64
    accepted_predecessor_right_derivative=0.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(committed,column_id,state,0.0_real64,initialized, &
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

  subroutine require(x,msg)
    logical,intent(in)::x
    character(len=*),intent(in)::msg
    if(.not.x)then; write(*,'(A,1X,A)')'FGC44_FAIL',trim(msg); error stop 1; end if
  end subroutine require
end program test_fgc44_real_fmr_participant
