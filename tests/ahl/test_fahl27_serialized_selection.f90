program test_fahl27_serialized_selection
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use MOD_grid, only: numnod, z, dz, disnod
  implicit none

  real(real64), parameter :: h0=-75.0_real64, duration=0.25_real64, mass_tol=1.0e-12_real64
  type(fmr_b110_physical_parameters_t) :: p_head, p_qbot
  type(fmr_b110_physical_forcing_t) :: f_head, f_qbot
  type(fmr_serialized_reference_backend_t) :: b_head, b_qbot
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(canonical_numerical_config_t) :: config
  type(kernel_committed_state_t) :: committed_head, committed_qbot
  type(kernel_checkpoint_t) :: cp_head, cp_qbot
  type(kernel_result_t) :: result_head, result_qbot
  type(kernel_candidate_state_t) :: candidate_head, candidate_qbot
  type(kernel_diagnostics_t) :: diag_head, diag_qbot
  type(fmr_serialized_physical_observation_t) :: obs_head, obs_qbot
  real(real64) :: k0
  logical :: ok

  call initialize_parameters(p_head,5)
  call initialize_parameters(p_qbot,2)
  call initial_conductivity(p_head,k0)
  call initialize_forcing(f_head,-k0,5)
  call initialize_forcing(f_qbot,-k0,2)
  call initialize_column_template(column,template)
  call initialize_config(config)

  call initialize_committed(committed_head,p_head,ok); call require(ok,'head committed')
  call initialize_committed(committed_qbot,p_qbot,ok); call require(ok,'qbot committed')
  call fmr_capture_checkpoint(committed_head,cp_head,ok); call require(ok,'head checkpoint')
  call fmr_capture_checkpoint(committed_qbot,cp_qbot,ok); call require(ok,'qbot checkpoint')

  call b_head%initialize(top)
  call b_qbot%initialize(top)

  call b_head%run_trial(column,template,p_head,committed_head,f_head,config,0.0_real64,duration,cp_head, &
       result_head,candidate_head,diag_head)
  call require(result_head%status==CANONICAL_STATUS_COMPLETED .and. result_head%completed,'mode5 completed')
  obs_head=b_head%observation()
  call require(obs_head%adaptive_hydraulics_used,'mode5 adaptive selected')
  call require(index(trim(obs_head%adaptive_hydraulics_route),'adaptive-cache-')==1,'mode5 adaptive route')
  call require(result_head%mass%complete .and. abs(result_head%mass%residual)<=mass_tol,'mode5 mass')

  call b_qbot%run_trial(column,template,p_qbot,committed_qbot,f_qbot,config,0.0_real64,duration,cp_qbot, &
       result_qbot,candidate_qbot,diag_qbot)
  call require(result_qbot%status==CANONICAL_STATUS_COMPLETED .and. result_qbot%completed,'mode2 completed')
  obs_qbot=b_qbot%observation()
  call require(.not.obs_qbot%adaptive_hydraulics_used,'mode2 analytical fallback')
  call require(trim(obs_qbot%adaptive_hydraulics_route)=='analytical-ineligible','mode2 fallback route')
  call require(result_qbot%mass%complete .and. abs(result_qbot%mass%residual)<=mass_tol,'mode2 mass')

  write(*,'(A,1X,A)') 'FAHL27_MODE5_ROUTE',trim(obs_head%adaptive_hydraulics_route)
  write(*,'(A,1X,A)') 'FAHL27_MODE2_ROUTE',trim(obs_qbot%adaptive_hydraulics_route)
  write(*,'(A)') 'FAHL27_SERIALIZED_SELECTION=PASS'

contains

  subroutine initialize_parameters(p,mode)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer,intent(in)::mode
    integer::k
    p%parameter_set_id=270027_int64+int(mode,int64)
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod);p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=0.032_real64;p%cofgen(2,k)=0.423_real64;p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64;p%cofgen(5,k)=0.365_real64;p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k);p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64;p%cofgen(10,k)=p%cofgen(3,k);p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k);p%cofgen(22,k)=-1.0e6_real64;p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=mode;p%swkimpl=0;p%swkmean=1;p%swsophy=0
    p%max_iterations=16;p%max_backtracking=8;p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=mass_tol;p%total_balance_tolerance=mass_tol
    p%head_abs_tolerance=mass_tol;p%head_rel_tolerance=mass_tol;p%ponding_tolerance=mass_tol
    p%root_extraction_active=.false.;p%macropore_active=.false.;p%snow_active=.false.
    p%hysteresis_active=.false.;p%tabulated_hydraulics_active=.false.;p%ksatexm_extension_active=.false.
    p%elasticity_active=.false.;p%frost_active=.false.;p%soil_temperature_active=.false.
    p%drainage_response_active=.false.
  end subroutine initialize_parameters

  subroutine initialize_forcing(f,qeq,mode)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    real(real64),intent(in)::qeq
    integer,intent(in)::mode
    f%top_flux=qeq;f%top_head=h0
    if(mode==5) then
      f%bottom_head=h0
      f%bottom_flux=0.0_real64
    else
      f%bottom_head=-999999.0_real64
      f%bottom_flux=qeq
    end if
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64;f%subsurface_irrigation_source=0.0_real64;f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_column_template(col,tpl)
    type(fmr_logical_column_t),intent(out)::col
    type(fmr_template_t),intent(out)::tpl
    tpl%template_id=270001_int64;tpl%physics_topology_id=270002_int64;tpl%vertical_layout_id=270003_int64
    tpl%state_layout_id=270004_int64;tpl%solver_interface_id=270005_int64
    tpl%optional_state_layout_id=0_int64;tpl%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    tpl%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    col%column_id=270027_int64;col%template_id=tpl%template_id;col%parameter_ref=1_int64
    col%state_handle=1_int64;col%forcing_handle=1_int64;col%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_template

  subroutine initialize_config(c)
    type(canonical_numerical_config_t),intent(out)::c
    c%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF;c%transaction%temporal_tolerance=1.0e-6_real64
    c%transaction%mass_tolerance=mass_tol;c%transaction%retry_scale=0.5_real64;c%transaction%max_retries=8
    c%max_committed_substeps=32;c%progress_tolerance=0.0_real64
    c%model_temporal_indicator_budget_available=.false.;c%accepted_trajectory_direction%requested=.false.
  end subroutine initialize_config

  subroutine initial_conductivity(p,k0)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    real(real64),intent(out)::k0
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::h(numnod),w(numnod),kk(numnod),cc(numnod),dk(numnod)
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,duration)
    h=h0;call provider%evaluate(h,w,kk,cc,dk);k0=kk(1)
  end subroutine initial_conductivity

  subroutine initialize_committed(committed,p,initialized)
    type(kernel_committed_state_t),intent(out)::committed
    type(fmr_b110_physical_parameters_t),intent(in)::p
    logical,intent(out)::initialized
    type(fmr_b110_physical_state_t)::state
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::h(numnod),w(numnod),kk(numnod),cc(numnod),dk(numnod)
    h=h0;call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,duration);call provider%evaluate(h,w,kk,cc,dk)
    state%active_nodes=numnod;allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=h;state%water_content=w;state%ponding_depth=0.0_real64;state%groundwater_level=-2.0_real64
    call fmr_new_b110_committed_state(committed,270027_int64,state,0.0_real64,initialized)
  end subroutine initialize_committed

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'FAHL27_SELECTION_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fahl27_serialized_selection
