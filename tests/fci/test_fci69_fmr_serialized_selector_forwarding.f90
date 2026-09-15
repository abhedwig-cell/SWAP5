program test_fci69_fmr_serialized_selector_forwarding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_committed_state
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_rossfast_d3r_execution_policy, only: ROSSFAST_D3R_OUTER_HORIZON_DAY, &
       ROSSFAST_D3R_MAX_FULL_INDEX, apply_rossfast_d3r_retry_policy, rossfast_d3r_select_transaction_window
  implicit none

  real(real64), parameter :: h0 = -75.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  integer(int64), parameter :: column_id = 690069_int64

  type(fmr_serialized_reference_backend_t) :: backend_absent, backend_present
  type(fixed_flux_top_boundary_provider_t), target :: top_absent, top_present
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint
  type(kernel_result_t) :: result_absent, result_present
  type(kernel_candidate_state_t) :: candidate_absent, candidate_present
  type(kernel_diagnostics_t) :: diag_absent, diag_present
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_forcing_t) :: forcing
  type(canonical_numerical_config_t) :: config
  real(real64) :: k0, qeq
  real(real64) :: first_target
  integer :: first_cap, selector_calls
  logical :: ok, selector_all_valid

  call initialize_parameters(parameters)
  call determine_initial_conductivity(parameters, k0)
  qeq = -k0
  call initialize_committed(committed, parameters, ok)
  call require(ok, 'committed state initialized')
  call committed%capture_checkpoint(checkpoint, ok)
  call require(ok .and. checkpoint%ready(), 'checkpoint captured')
  call initialize_forcing(forcing, qeq)
  call initialize_identity(column, template)
  call initialize_config(config)

  call backend_absent%initialize(top_absent)
  call backend_absent%run_trial(column, template, parameters, committed, forcing, config, 0.0_real64, &
       ROSSFAST_D3R_OUTER_HORIZON_DAY, checkpoint, result_absent, candidate_absent, diag_absent)

  selector_calls = 0
  first_target = -1.0_real64
  first_cap = -1
  selector_all_valid = .true.
  call backend_present%initialize(top_present)
  call backend_present%run_trial(column, template, parameters, committed, forcing, config, 0.0_real64, &
       ROSSFAST_D3R_OUTER_HORIZON_DAY, checkpoint, result_present, candidate_present, diag_present, &
       counting_rossfast_selector)

  call require(selector_calls > 0, 'RossFast selector reached through serialized backend')
  call require(selector_all_valid, 'all delegated RossFast selections valid')
  call require(same_bits(first_target, ROSSFAST_D3R_OUTER_HORIZON_DAY), 'first target is exact D3R outer horizon')
  call require(first_cap == ROSSFAST_D3R_MAX_FULL_INDEX, 'first retry cap is D3R full-index cap')

  call require(result_absent%completed .and. result_present%completed, 'both backend trials completed')
  call require(candidate_absent%ready() .and. candidate_present%ready(), 'both candidates materialized')
  call require(result_absent%status == result_present%status, 'status identity')
  call require(same_bits(result_absent%completed_t, result_present%completed_t), 'completed time identity')
  call require(result_absent%mass%complete .and. result_present%mass%complete, 'mass accounting complete')
  call require(abs(result_absent%mass%residual) <= hard_mass_gate, 'absent-selector hard mass gate')
  call require(abs(result_present%mass%residual) <= hard_mass_gate, 'present-selector hard mass gate')
  call require(same_bits(result_absent%mass%residual, result_present%mass%residual), 'mass residual identity')
  call require(diag_absent%accepted_substeps == diag_present%accepted_substeps, 'accepted substep identity')
  call require(diag_absent%attempts == diag_present%attempts, 'attempt count identity')
  call require(diag_absent%retries == diag_present%retries, 'retry count identity')
  call require(diag_absent%committed_state_mutations == 0 .and. diag_present%committed_state_mutations == 0, &
       'trial does not publish committed state')
  call require(committed%current_revision() == 0_int64, 'external committed revision unchanged')

  write(*,'(A,I0)') 'FCI69_SELECTOR_CALLS=', selector_calls
  write(*,'(A,ES26.17E3)') 'FCI69_FIRST_TARGET_DAY=', first_target
  write(*,'(A,I0)') 'FCI69_FIRST_RETRY_CAP=', first_cap
  write(*,'(A,ES26.17E3)') 'FCI69_MASS_RESIDUAL=', result_present%mass%residual
  write(*,'(A)') 'FCI69_SERIALIZED_BACKEND_ROSSFAST_SELECTOR_FORWARDING=PASS'
  write(*,'(A)') 'FCI69_ABSENT_PRESENT_IDENTITY=PASS'
  write(*,'(A)') 'FCI69_FMR_SERIALIZED_SELECTOR_FORWARDING_TEST PASS'

contains

  subroutine counting_rossfast_selector(cursor, requested_t1, target_t1, max_retries_cap, valid)
    real(real64), intent(in) :: cursor, requested_t1
    real(real64), intent(out) :: target_t1
    integer, intent(out) :: max_retries_cap
    logical, intent(out) :: valid

    selector_calls = selector_calls + 1
    call rossfast_d3r_select_transaction_window(cursor, requested_t1, target_t1, max_retries_cap, valid)
    if (selector_calls == 1) then
      first_target = target_t1
      first_cap = max_retries_cap
    end if
    selector_all_valid = selector_all_valid .and. valid
  end subroutine counting_rossfast_selector

  subroutine initialize_identity(column, template)
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template

    template%template_id = 690001_int64
    template%physics_topology_id = 690002_int64
    template%vertical_layout_id = 690003_int64
    template%state_layout_id = 690004_int64
    template%solver_interface_id = 690005_int64
    template%optional_state_layout_id = 0_int64
    template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    column%column_id = column_id
    column%template_id = template%template_id
    column%parameter_ref = 1_int64
    column%state_handle = 1_int64
    column%forcing_handle = 1_int64
    column%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_identity

  subroutine initialize_config(config)
    type(canonical_numerical_config_t), intent(out) :: config

    config%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    config%transaction%temporal_tolerance = 1.0e-6_real64
    config%transaction%mass_tolerance = hard_mass_gate
    call apply_rossfast_d3r_retry_policy(config)
    config%max_committed_substeps = 32
    config%progress_tolerance = 0.0_real64
    config%model_temporal_indicator_budget_available = .false.
    config%model_temporal_indicator_budget = 0.0_real64
  end subroutine initialize_config

  subroutine initialize_parameters(parameters)
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    integer :: k

    parameters%parameter_set_id = column_id
    parameters%active_nodes = numnod
    allocate(parameters%z(numnod), parameters%dz(numnod), parameters%node_distance(numnod), parameters%cofgen(24,numnod))
    parameters%z = z
    parameters%dz = dz
    parameters%node_distance = disnod(1:numnod)
    parameters%cofgen = 0.0_real64
    do k = 1, numnod
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
    parameters%bottom_mode = 2
    parameters%swkimpl = 0
    parameters%swkmean = 1
    parameters%swsophy = 0
    parameters%max_iterations = 16
    parameters%max_backtracking = 8
    parameters%min_step_duration = 1.0e-8_real64
    parameters%compartment_balance_tolerance = 1.0e-12_real64
    parameters%total_balance_tolerance = 1.0e-12_real64
    parameters%head_abs_tolerance = 1.0e-12_real64
    parameters%head_rel_tolerance = 1.0e-12_real64
    parameters%ponding_tolerance = 1.0e-12_real64
    parameters%root_extraction_active = .false.
    parameters%macropore_active = .false.
    parameters%snow_active = .false.
    parameters%hysteresis_active = .false.
    parameters%tabulated_hydraulics_active = .false.
    parameters%elasticity_active = .false.
    parameters%frost_active = .false.
    parameters%soil_temperature_active = .false.
  end subroutine initialize_parameters

  subroutine determine_initial_conductivity(parameters, conductivity_top)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    real(real64), intent(out) :: conductivity_top
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)

    call initialize_b110_default_mvg_parameters(hp, parameters%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, ROSSFAST_D3R_OUTER_HORIZON_DAY)
    heads = h0
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    conductivity_top = conductivity(1)
  end subroutine determine_initial_conductivity

  subroutine initialize_committed(committed, parameters, initialized)
    type(kernel_committed_state_t), intent(out) :: committed
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    logical, intent(out) :: initialized
    type(fmr_b110_physical_state_t) :: state
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)

    call initialize_b110_default_mvg_parameters(hp, parameters%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, ROSSFAST_D3R_OUTER_HORIZON_DAY)
    heads = h0
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
    call fmr_new_b110_committed_state(committed, column_id, state, 0.0_real64, initialized)
  end subroutine initialize_committed

  subroutine initialize_forcing(forcing, equilibrium_flux)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: equilibrium_flux

    forcing%top_flux = equilibrium_flux
    forcing%top_head = h0
    forcing%bottom_flux = equilibrium_flux
    forcing%bottom_head = -999999.0_real64
    allocate(forcing%drainage_flux_by_level(1,numnod), forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    forcing%drainage_flux_by_level = 0.0_real64
    forcing%subsurface_irrigation_source = 0.0_real64
    forcing%root_extraction_sink = 0.0_real64
  end subroutine initialize_forcing

  pure logical function same_bits(a, b)
    real(real64), intent(in) :: a, b
    same_bits = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_bits

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FCI69_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fci69_fmr_serialized_selector_forwarding
