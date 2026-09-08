program test_fmr05_single_fmr04_identity
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot
  use mod_transaction_reference, only: transaction_state_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t, canonical_mass_accounting_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_result_t, kernel_diagnostics_t, kernel_executor_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint, fmr_commit_candidate
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_new_b110_committed_state, fmr_serialized_reference_backend_t, &
       fmr_serialized_physical_observation_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0 = 1000.125_real64
  real(real64), parameter :: t1 = 1000.625_real64
  real(real64), parameter :: head0 = -75.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64

  type(fmr_logical_column_t) :: columns(1)
  type(fmr_template_t) :: templates(1)
  type(fmr_b110_physical_parameters_t) :: parameters(1)
  type(fmr_b110_physical_forcing_t) :: forcings(1)
  type(fmr_b110_physical_state_t) :: initial_state
  type(kernel_committed_state_t) :: multi_states(1), direct_state
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(canonical_numerical_config_t) :: config
  type(fmr_serialized_column_result_t), allocatable :: multi_results(:)
  type(fmr_column_diagnostics_t), allocatable :: multi_diag(:)
  type(fmr_aggregate_diagnostics_t) :: multi_aggregate
  type(fmr_serialized_batch_diagnostics_t) :: multi_runtime_diag
  type(fmr_serialized_reference_backend_t) :: backend
  type(kernel_checkpoint_t) :: checkpoint
  type(kernel_candidate_state_t) :: candidate
  type(kernel_result_t) :: direct_result
  type(kernel_diagnostics_t) :: direct_diag
  type(kernel_executor_t) :: tx
  type(fmr_serialized_physical_observation_t) :: observation
  real(real64) :: conductivity0
  logical :: ok, did_commit
  integer :: dispatch_status, commit_status

  call configure_template(templates(1))
  call configure_parameters(parameters(1), initial_state, conductivity0)
  call configure_forcing(forcings(1), conductivity0)
  call configure_transaction(config)

  columns(1)%column_id = 505001_int64
  columns(1)%template_id = templates(1)%template_id
  columns(1)%parameter_ref = 1_int64
  columns(1)%state_handle = 1_int64
  columns(1)%forcing_handle = 1_int64
  columns(1)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

  call fmr_new_b110_committed_state(multi_states(1), columns(1)%column_id, initial_state, t0, ok)
  call require(ok, 'multi state init')
  call fmr_new_b110_committed_state(direct_state, columns(1)%column_id, initial_state, t0, ok)
  call require(ok, 'direct state init')

  call reset_legacy_globals()
  call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, multi_states, config, top_provider, &
       t0, t1, 1, multi_results, multi_diag, multi_aggregate, dispatch_status, multi_runtime_diag)
  call require(dispatch_status == FMR_SERIAL_DISPATCH_OK, 'multi dispatch')
  call require(size(multi_results) == 1 .and. multi_results(1)%completed .and. multi_results(1)%committed, &
       'multi accepted')
  call require(multi_results(1)%mass%complete .and. &
       multi_results(1)%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'multi mass complete')

  call reset_legacy_globals()
  call backend%initialize(top_provider)
  call fmr_capture_checkpoint(direct_state, checkpoint, ok)
  call require(ok .and. checkpoint%ready(), 'direct checkpoint')
  call backend%run_trial(columns(1), templates(1), parameters(1), direct_state, forcings(1), config, &
       t0, t1, checkpoint, direct_result, candidate, direct_diag)
  call require(direct_result%completed .and. candidate%ready(), 'direct F-MR04 trial')
  observation = backend%observation()
  call fmr_commit_candidate(tx, direct_state, candidate, direct_diag, did_commit, commit_status)
  call require(did_commit, 'direct F-MR04 commit')

  call require(multi_results(1)%kernel_status == direct_result%status, 'kernel status identity')
  call require(multi_results(1)%commit_status == commit_status, 'commit status identity')
  call require(multi_results(1)%solver_executed .eqv. observation%solver_executed, 'solver executed identity')
  call require(trim(multi_results(1)%solver_route) == trim(observation%solver_diagnostics%route), 'solver route identity')
  call require(multi_results(1)%solver_iterations == observation%solver_diagnostics%nonlinear_iterations, &
       'solver iteration identity')
  call require(mass_identical(multi_results(1)%mass, direct_result%mass), 'authoritative mass bitwise identity')
  call require(multi_states(1)%current_revision() == direct_state%current_revision(), 'revision identity')
  call require(committed_fingerprint(multi_states(1)) == committed_fingerprint(direct_state), &
       'committed physical state identity')
  call require(multi_runtime_diag%physical_solve_count == 1, 'one physical solve counted')
  call require(multi_runtime_diag%max_simultaneous_real_physical_solves == 1, 'serialized max one')

  write(*,'(A)') 'FMR05_SINGLE_COLUMN_FMR04_ROUTE_IDENTITY=PASS'
  write(*,'(A)') 'FMR05_SINGLE_COLUMN_FMR04_MASS_BITWISE_IDENTITY=PASS'
  write(*,'(A)') 'FMR05_SINGLE_COLUMN_FMR04_COMMITTED_STATE_IDENTITY=PASS'
  write(*,'(A)') 'FMR05_SINGLE_FMR04_IDENTITY_TEST PASS'

contains

  subroutine configure_template(template)
    type(fmr_template_t), intent(out) :: template
    template%template_id = 505_int64
    template%physics_topology_id = 50501_int64
    template%vertical_layout_id = 50502_int64
    template%state_layout_id = 50503_int64
    template%solver_interface_id = 50504_int64
    template%optional_state_layout_id = 0_int64
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_template

  subroutine configure_parameters(p, state, conductivity0)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: conductivity0
    type(b110_default_mvg_parameters_t), target :: hyd_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: i

    p%parameter_set_id = 50501_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod), p%cofgen(24,numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)
    p%cofgen = 0.0_real64
    do i = 1, numnod
      p%cofgen(1,i) = 0.032_real64
      p%cofgen(2,i) = 0.423_real64
      p%cofgen(3,i) = 4.75_real64
      p%cofgen(4,i) = 0.0135_real64
      p%cofgen(5,i) = 0.365_real64
      p%cofgen(6,i) = 1.455_real64
      p%cofgen(7,i) = 1.0_real64 - 1.0_real64/p%cofgen(6,i)
      p%cofgen(8,i) = p%cofgen(4,i)
      p%cofgen(9,i) = 0.0_real64
      p%cofgen(10,i) = p%cofgen(3,i)
      p%cofgen(11,i) = 0.999_real64
      p%cofgen(12,i) = 0.99_real64*p%cofgen(3,i)
      p%cofgen(22,i) = -1.0e6_real64
      p%cofgen(23,i) = 1.0e-12_real64
    end do
    p%bottom_mode = 7
    p%swkimpl = 0
    p%swkmean = 1
    p%swsophy = 0
    p%root_extraction_active = .false.
    p%macropore_active = .false.
    p%snow_active = .false.
    p%hysteresis_active = .false.
    p%tabulated_hydraulics_active = .false.
    p%elasticity_active = .false.
    p%frost_active = .false.

    call initialize_b110_default_mvg_parameters(hyd_parameters, p%cofgen)
    call bind_b110_default_mvg_provider(constitutive, hyd_parameters, t1-t0)
    heads = head0
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    call require(all(conductivity == conductivity(1)), 'uniform conductivity fixture')
    conductivity0 = conductivity(1)

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
  end subroutine configure_parameters

  subroutine configure_forcing(forcing, conductivity0)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: conductivity0
    integer :: i
    real(real64), parameter :: scale = 1.01_real64

    forcing%top_flux = -conductivity0
    forcing%top_head = head0
    forcing%bottom_flux = -conductivity0
    forcing%bottom_head = -100.0_real64
    allocate(forcing%drainage_flux_by_level(2,numnod), forcing%subsurface_irrigation_source(numnod), &
             forcing%root_extraction_sink(numnod))
    do i = 1, numnod
      forcing%drainage_flux_by_level(1,i) = scale*1.0e-5_real64*real(i,real64)
      forcing%drainage_flux_by_level(2,i) = -scale*2.0e-6_real64*real(i+1,real64)
      forcing%subsurface_irrigation_source(i) = forcing%drainage_flux_by_level(1,i) + &
                                                forcing%drainage_flux_by_level(2,i)
      forcing%root_extraction_sink(i) = 0.0_real64
    end do
  end subroutine configure_forcing

  subroutine configure_transaction(config_out)
    type(canonical_numerical_config_t), intent(out) :: config_out
    config_out%transaction%temporal_tolerance = 0.0_real64
    config_out%transaction%mass_tolerance = hard_mass_gate
    config_out%transaction%retry_scale = 0.5_real64
    config_out%transaction%max_retries = 2
    config_out%max_committed_substeps = 8
    config_out%progress_tolerance = 0.0_real64
  end subroutine configure_transaction

  subroutine reset_legacy_globals()
    legacy_qdra = 12345.0_real64
    legacy_qssdi = -54321.0_real64
    legacy_qrot = 0.0_real64
    swmacro = 0
    melt = 0.0_real64
  end subroutine reset_legacy_globals

  logical function mass_identical(a,b)
    type(canonical_mass_accounting_t), intent(in) :: a,b
    mass_identical = a%complete .eqv. b%complete
    if (.not. mass_identical) return
    mass_identical = a%missing_contribution_mask == b%missing_contribution_mask .and. &
         a%origin_lineage_id == b%origin_lineage_id .and. a%origin_revision == b%origin_revision .and. &
         a%accepted_transaction_count == b%accepted_transaction_count .and. &
         same_bits(a%interval_t0,b%interval_t0) .and. same_bits(a%interval_t1,b%interval_t1) .and. &
         same_bits(a%storage_start,b%storage_start) .and. same_bits(a%storage_end,b%storage_end) .and. &
         same_bits(a%storage_change,b%storage_change) .and. same_bits(a%total_in,b%total_in) .and. &
         same_bits(a%total_out,b%total_out) .and. same_bits(a%residual,b%residual)
  end function mass_identical

  integer(int64) function committed_fingerprint(state) result(fp)
    type(kernel_committed_state_t), intent(in) :: state
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    integer :: i

    call state%snapshot(snapshot, got)
    call require(got, 'committed snapshot')
    fp = 1469598103934665603_int64
    select type (physical => snapshot)
    type is (fmr_b110_physical_state_t)
      fp = ieor(fp, int(physical%active_nodes,int64))
      do i = 1, physical%active_nodes
        fp = ieor(fp, transfer(physical%pressure_head(i),fp))
        fp = ieor(fp, transfer(physical%water_content(i),fp))
      end do
      fp = ieor(fp, transfer(physical%ponding_depth,fp))
      fp = ieor(fp, transfer(physical%groundwater_level,fp))
    class default
      error stop 'F-MR05 unexpected physical state type'
    end select
  end function committed_fingerprint

  logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia, ib
    ia = transfer(a,ia)
    ib = transfer(b,ib)
    same_bits = ia == ib
  end function same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FMR05_SINGLE_IDENTITY_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fmr05_single_fmr04_identity
