program test_fpe_approx01_tangent_sequence
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

  integer, parameter :: ntrials=24
  integer, parameter :: ncad=3
  integer, parameter :: cadences(ncad)=[2,4,8]
  real(real64), parameter :: duration=1.0e-4_real64
  real(real64), parameter :: tol=1.0e-12_real64
  real(real64), parameter :: predictor_qbot=1.0e-6_real64
  real(real64), parameter :: head_budget=1.0e-5_real64
  real(real64), parameter :: delta_h_eval_m=1.0e-2_real64
  integer(int64), parameter :: column_id=629001_int64

  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_forcing_t) :: base_forcing
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(canonical_numerical_config_t) :: config
  type(kernel_committed_state_t) :: committed
  type(fmr_serialized_reference_backend_t) :: backend
  type(fmr_groundwater_head_forcing_materializer_t) :: materializer
  type(fmr_groundwater_swap_participant_t) :: participant
  type(groundwater_swap_trial_t) :: trial
  type(groundwater_head_datum_t) :: datum
  type(groundwater_coupling_window_t) :: window
  type(fixed_flux_top_boundary_provider_t), target :: top
  logical :: ok
  integer :: status,trial_index,ic,last_refresh
  real(real64) :: h0_cm,origin_head_m,prescribed_head_m
  real(real64) :: tangent(ntrials),qswap(ntrials),head_m(ntrials),offset_m
  real(real64) :: lag_value,abs_err,rel_err,qerr,scale
  real(real64) :: max_abs(ncad),max_rel(ncad),mean_abs(ncad),mean_rel(ncad),max_qerr(ncad)
  real(real64) :: max_step_change
  character(len=32) :: arg,regime

  if(command_argument_count()/=2) error stop 'usage: test REGIME H0_CM'
  call get_command_argument(1,regime)
  call get_command_argument(2,arg); read(arg,*) h0_cm

  call initialize_parameters(parameters)
  call initialize_forcing(base_forcing,predictor_qbot,h0_cm)
  call initialize_column_template(column,template)
  call initialize_config(config)
  call initialize_committed(committed,parameters,h0_cm,ok)
  call require(ok,'committed state initialized')

  call backend%initialize(top)
  call materializer%initialize(base_forcing)
  datum%available=.true.
  datum%datum_id=629001_int64
  datum%bottom_boundary_elevation_m=0.0_real64
  window%t0=0.0_real64
  window%t1=duration
  call compute_origin_head(parameters,datum,h0_cm,origin_head_m,status)
  call require(status==MODFLOW6_BOTTOM_FACE_OK,'origin head materialized')

  call participant%capture_origin(committed,status)
  call require(status==GW_SWAP_PARTICIPANT_OK,'capture common origin')

  do trial_index=1,ntrials
    offset_m=head_offset(trial_index)
    prescribed_head_m=origin_head_m+offset_m
    head_m(trial_index)=prescribed_head_m

    call participant%trial_from_origin(backend,column,template,parameters,committed,materializer,config,datum,window, &
         prescribed_head_m,trial,status)
    if(status/=GW_SWAP_PARTICIPANT_OK .or. .not.trial%valid) then
      write(*,'(*(g0))') 'APPROX01_TRIAL_FAIL|REGIME=',trim(regime),'|TRIAL=',trial_index, &
           '|STATUS=',status,'|HEAD_OFFSET_M=',offset_m
      error stop 1
    end if
    call require(trial%response_tangent_available,'fresh tangent available')
    call require(ieee_is_finite(trial%dq_swap_dh_per_s),'fresh tangent finite')
    call require(ieee_is_finite(trial%q_swap_m_per_s),'fresh exchange finite')
    tangent(trial_index)=trial%dq_swap_dh_per_s
    qswap(trial_index)=trial%q_swap_m_per_s

    write(*,'(*(g0))') 'APPROX01_FRESH|REGIME=',trim(regime),'|TRIAL=',trial_index, &
         '|HEAD_OFFSET_M=',offset_m,'|PRESCRIBED_HEAD_M=',prescribed_head_m, &
         '|TANGENT=',tangent(trial_index),'|Q_SWAP=',qswap(trial_index)

    call participant%discard_candidate(backend)
  end do

  max_step_change=0.0_real64
  do trial_index=2,ntrials
    max_step_change=max(max_step_change,abs(tangent(trial_index)-tangent(trial_index-1)))
  end do
  write(*,'(*(g0))') 'APPROX01_TANGENT_EVOLUTION|REGIME=',trim(regime),'|MAX_ADJACENT_ABS_CHANGE=',max_step_change, &
       '|MIN_TANGENT=',minval(tangent),'|MAX_TANGENT=',maxval(tangent)

  max_abs=0.0_real64; max_rel=0.0_real64; mean_abs=0.0_real64; mean_rel=0.0_real64; max_qerr=0.0_real64
  do ic=1,ncad
    do trial_index=1,ntrials
      last_refresh=1+((trial_index-1)/cadences(ic))*cadences(ic)
      lag_value=tangent(last_refresh)
      abs_err=abs(lag_value-tangent(trial_index))
      scale=max(abs(tangent(trial_index)),1.0e-20_real64)
      rel_err=abs_err/scale
      qerr=abs_err*delta_h_eval_m
      max_abs(ic)=max(max_abs(ic),abs_err)
      max_rel(ic)=max(max_rel(ic),rel_err)
      max_qerr(ic)=max(max_qerr(ic),qerr)
      mean_abs(ic)=mean_abs(ic)+abs_err
      mean_rel(ic)=mean_rel(ic)+rel_err
    end do
    mean_abs(ic)=mean_abs(ic)/real(ntrials,real64)
    mean_rel(ic)=mean_rel(ic)/real(ntrials,real64)
    write(*,'(*(g0))') 'APPROX01_LAG|REGIME=',trim(regime),'|CADENCE=',cadences(ic), &
         '|FRESH_FRACTION=',1.0_real64/real(cadences(ic),real64), &
         '|AVOIDED_TANGENT_FRACTION=',1.0_real64-1.0_real64/real(cadences(ic),real64), &
         '|MAX_ABS_TANGENT_ERROR=',max_abs(ic),'|MEAN_ABS_TANGENT_ERROR=',mean_abs(ic), &
         '|MAX_REL_TANGENT_ERROR=',max_rel(ic),'|MEAN_REL_TANGENT_ERROR=',mean_rel(ic), &
         '|MAX_Q_PRED_ERROR_AT_DH_0P01M=',max_qerr(ic)
  end do

  print '(A)','FPE_APPROX01_TANGENT_SEQUENCE=PASS'

contains

  pure real(real64) function head_offset(i) result(v)
    integer,intent(in)::i
    real(real64),parameter::pattern(8)=[0.0_real64,0.0001_real64,0.0002_real64,0.0001_real64, &
         0.0_real64,-0.0001_real64,-0.0002_real64,-0.0001_real64]
    v=pattern(1+mod(i-1,8))
  end function head_offset

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer::k
    p%parameter_set_id=629001_int64; p%active_nodes=numnod
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

  subroutine initialize_forcing(f,q,h0)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    real(real64),intent(in)::q,h0
    f%top_flux=q; f%top_head=h0; f%bottom_flux=q; f%bottom_head=h0
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64; f%subsurface_irrigation_source=0.0_real64; f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_column_template(c,t)
    type(fmr_logical_column_t),intent(out)::c
    type(fmr_template_t),intent(out)::t
    t%template_id=629001_int64; t%physics_topology_id=629002_int64; t%vertical_layout_id=629003_int64
    t%state_layout_id=629004_int64; t%solver_interface_id=629005_int64; t%optional_state_layout_id=0_int64
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

  subroutine initialize_committed(committed,p,h0,initialized)
    type(kernel_committed_state_t),intent(out)::committed
    type(fmr_b110_physical_parameters_t),intent(in)::p
    real(real64),intent(in)::h0
    logical,intent(out)::initialized
    type(fmr_b110_physical_state_t)::state
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    real(real64)::accepted_predecessor_right_derivative(numnod)
    integer :: i
    heads(1)=h0
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

  subroutine compute_origin_head(p,datum_value,h0,head_m,status)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(groundwater_head_datum_t),intent(in)::datum_value
    real(real64),intent(in)::h0
    real(real64),intent(out)::head_m
    integer,intent(out)::status
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    type(modflow6_prescribed_qbot_bottom_face_t)::face
    real(real64)::heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    integer::i
    heads(1)=h0
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
    if(.not.x)then
      write(*,'(A,1X,A)')'APPROX01_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine require
end program test_fpe_approx01_tangent_sequence
