program test_f_rom0ta3_reference_floor_fmr_boundary
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: TX_TEMPORAL_REFERENCE_FLOOR_FIXED_RESOLUTION
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t, KERNEL_STATUS_NOT_ADMITTED, KERNEL_COMMIT_STATUS_COMMITTED
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_BASE
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_committed_state
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: h0=-75.0_real64
  real(real64), parameter :: dt=0.0016_real64
  real(real64), parameter :: hard_mass_gate=1.0e-12_real64
  integer(int64), parameter :: column_id=3003003_int64

  type(fmr_serialized_reference_backend_t) :: backend
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint
  type(kernel_result_t) :: result
  type(kernel_candidate_state_t) :: candidate
  type(kernel_diagnostics_t) :: diagnostics
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_forcing_t) :: forcing
  type(canonical_numerical_config_t) :: config
  type(fixed_flux_top_boundary_provider_t), target :: top
  real(real64) :: k0,qeq,committed_time
  logical :: ok,did_commit,time_available
  integer :: commit_status

  call initialize_parameters(parameters)
  call initialize_state(committed,parameters,k0,ok)
  call require(ok,'committed state initialized')
  qeq=-k0
  call initialize_forcing(forcing,qeq,qeq)
  call initialize_identity(column,template)
  call initialize_config(config)

  call backend%initialize(top)
  call fmr_capture_checkpoint(committed,checkpoint,ok)
  call require(ok,'checkpoint captured')

  call backend%run_trial(column,template,parameters,committed,forcing,config,0.0_real64,dt,checkpoint, &
       result,candidate,diagnostics)
  call require(result%status==KERNEL_STATUS_NOT_ADMITTED,'ordinary run_trial rejects floor mode')
  call require(.not.candidate%ready(),'ordinary run_trial exposes no candidate')
  call require(diagnostics%admission_rejections==1,'ordinary rejection diagnosed')
  write(*,'(A)') 'F_ROM0TA3_ORDINARY_FMR_FAIL_CLOSED=PASS'

  call backend%run_reference_floor_trial(column,template,parameters,committed,forcing,config,0.0_real64,dt,checkpoint, &
       result,candidate,diagnostics)
  call require(result%status==CANONICAL_STATUS_COMPLETED .and. result%completed,'dedicated floor trial completed')
  call require(candidate%ready(),'dedicated floor candidate materialized')
  call require(result%mass%complete .and. abs(result%mass%residual)<=hard_mass_gate,'dedicated floor mass gate')
  call require(diagnostics%attempts==1 .and. diagnostics%retries==0,'dedicated floor exactly one attempt')
  call require(diagnostics%accepted_substeps==1,'dedicated floor one accepted fixed sample')
  call require(diagnostics%temporal_acceptance_source==TX_TEMPORAL_REFERENCE_FLOOR_FIXED_RESOLUTION, &
       'dedicated floor source provenance')
  call require(abs(diagnostics%min_accepted_substep_duration-dt)<=16.0_real64*epsilon(1.0_real64), &
       'dedicated floor min dt identity')
  call require(abs(diagnostics%max_accepted_substep_duration-dt)<=16.0_real64*epsilon(1.0_real64), &
       'dedicated floor max dt identity')
  call require(diagnostics%alternative_solver_calls==0,'dedicated floor Reference route only')

  call backend%commit_trial_candidate(committed,candidate,diagnostics,did_commit,commit_status)
  call require(did_commit .and. commit_status==KERNEL_COMMIT_STATUS_COMMITTED,'dedicated floor candidate committed once')
  call require(committed%current_revision()==1_int64,'dedicated floor revision incremented once')
  call committed%current_time(committed_time,time_available)
  call require(time_available .and. abs(committed_time-dt)<=16.0_real64*epsilon(1.0_real64),'committed time exact')
  write(*,'(A)') 'F_ROM0TA3_DEDICATED_REFERENCE_FLOOR_COMMIT=PASS'

  call fmr_capture_checkpoint(committed,checkpoint,ok)
  call require(ok,'post-commit checkpoint captured')
  call backend%run_trial(column,template,parameters,committed,forcing,config,dt,2.0_real64*dt,checkpoint, &
       result,candidate,diagnostics)
  call require(result%status==KERNEL_STATUS_NOT_ADMITTED,'qualification context reset after dedicated call')
  call require(.not.candidate%ready(),'post-dedicated ordinary call no candidate')
  write(*,'(A)') 'F_ROM0TA3_QUALIFICATION_CONTEXT_EPHEMERAL=PASS'
  write(*,'(A)') 'F_ROM0TA3_FMR_BOUNDARY_GATE=PASS'

contains

  subroutine initialize_identity(column,template)
    type(fmr_logical_column_t),intent(out) :: column
    type(fmr_template_t),intent(out) :: template
    template%template_id=3003001_int64
    template%physics_topology_id=3003002_int64
    template%vertical_layout_id=3003003_int64
    template%state_layout_id=3003004_int64
    template%solver_interface_id=3003005_int64
    template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    column%column_id=column_id
    column%template_id=template%template_id
    column%parameter_ref=1_int64
    column%state_handle=1_int64
    column%forcing_handle=1_int64
    column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_identity

  subroutine initialize_config(config)
    type(canonical_numerical_config_t),intent(out) :: config
    config=canonical_numerical_config_t()
    config%transaction%temporal_mode=TX_TEMPORAL_REFERENCE_FLOOR_FIXED_RESOLUTION
    config%transaction%temporal_tolerance=0.0_real64
    config%transaction%mass_tolerance=hard_mass_gate
    config%transaction%retry_scale=0.5_real64
    config%transaction%max_retries=7
    config%max_committed_substeps=4
    config%progress_tolerance=0.0_real64
    config%model_temporal_indicator_budget_available=.false.
    config%model_temporal_indicator_budget=0.0_real64
  end subroutine initialize_config

  subroutine initialize_parameters(parameters)
    type(fmr_b110_physical_parameters_t),intent(out) :: parameters
    integer :: k
    parameters%parameter_set_id=3003044_int64
    parameters%active_nodes=numnod
    allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod),parameters%cofgen(24,numnod))
    parameters%z=z
    parameters%dz=dz
    parameters%node_distance=disnod(1:numnod)
    parameters%cofgen=0.0_real64
    do k=1,numnod
      parameters%cofgen(1,k)=0.032_real64
      parameters%cofgen(2,k)=0.423_real64
      parameters%cofgen(3,k)=4.75_real64
      parameters%cofgen(4,k)=0.0135_real64
      parameters%cofgen(5,k)=0.365_real64
      parameters%cofgen(6,k)=1.455_real64
      parameters%cofgen(7,k)=1.0_real64-1.0_real64/parameters%cofgen(6,k)
      parameters%cofgen(8,k)=parameters%cofgen(4,k)
      parameters%cofgen(9,k)=0.0_real64
      parameters%cofgen(10,k)=parameters%cofgen(3,k)
      parameters%cofgen(11,k)=0.999_real64
      parameters%cofgen(12,k)=0.99_real64*parameters%cofgen(3,k)
      parameters%cofgen(22,k)=-1.0e6_real64
      parameters%cofgen(23,k)=1.0e-12_real64
    end do
    parameters%bottom_mode=2
    parameters%swkimpl=0
    parameters%swkmean=1
    parameters%swsophy=0
    parameters%max_iterations=16
    parameters%max_backtracking=8
    parameters%min_step_duration=1.0e-8_real64
    parameters%compartment_balance_tolerance=hard_mass_gate
    parameters%total_balance_tolerance=hard_mass_gate
    parameters%head_abs_tolerance=hard_mass_gate
    parameters%head_rel_tolerance=hard_mass_gate
    parameters%ponding_tolerance=hard_mass_gate
    parameters%root_extraction_active=.false.
    parameters%drainage_response_active=.false.
    parameters%macropore_active=.false.
    parameters%snow_active=.false.
    parameters%hysteresis_active=.false.
    parameters%tabulated_hydraulics_active=.false.
    parameters%elasticity_active=.false.
    parameters%frost_active=.false.
    parameters%soil_temperature_active=.false.
  end subroutine initialize_parameters

  subroutine initialize_state(committed,parameters,k0,ok)
    type(kernel_committed_state_t),intent(out) :: committed
    type(fmr_b110_physical_parameters_t),intent(in) :: parameters
    real(real64),intent(out) :: k0
    logical,intent(out) :: ok
    type(fmr_b110_physical_state_t) :: state
    type(b110_default_mvg_parameters_t),target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    heads=h0
    call initialize_b110_default_mvg_parameters(hp,parameters%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,dt)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    call require(all(ieee_is_finite(water)).and.all(ieee_is_finite(conductivity)),'initial hydraulic state finite')
    k0=conductivity(1)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads
    state%water_content=water
    state%ponding_depth=0.0_real64
    state%groundwater_level=-2.0_real64
    call fmr_new_b110_committed_state(committed,column_id,state,0.0_real64,ok)
  end subroutine initialize_state

  subroutine initialize_forcing(forcing,top_flux,bottom_flux)
    type(fmr_b110_physical_forcing_t),intent(out) :: forcing
    real(real64),intent(in) :: top_flux,bottom_flux
    forcing%top_flux=top_flux
    forcing%top_head=h0
    forcing%bottom_flux=bottom_flux
    forcing%bottom_head=-999999.0_real64
    allocate(forcing%drainage_flux_by_level(1,numnod),forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    forcing%drainage_flux_by_level=0.0_real64
    forcing%subsurface_irrigation_source=0.0_real64
    forcing%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine require(condition,label)
    logical,intent(in) :: condition
    character(len=*),intent(in) :: label
    if(.not.condition) then
      write(*,'(A,1X,A)') 'F_ROM0TA3_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_f_rom0ta3_reference_floor_fmr_boundary
