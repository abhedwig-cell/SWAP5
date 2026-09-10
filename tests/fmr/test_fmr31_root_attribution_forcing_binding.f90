program test_fmr31_root_attribution_forcing_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot
  use mod_transaction_reference, only: transaction_state_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK, &
       FMR_SERIAL_DISPATCH_RECEIPT_REQUEST_REJECTED
  use mod_fmr_root_uptake_attribution_receipt, only: fmr_root_uptake_attribution_record_t, &
       fmr_run_serialized_root_uptake_attribution, FMR_ROOT_ATTRIBUTION_OK, &
       FMR_ROOT_ATTRIBUTION_NOT_COMMITTED, FMR_ROOT_ATTRIBUTION_RUNTIME_REJECTED
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0 = 4100.125_real64
  real(real64), parameter :: t1 = 4100.4375_real64
  real(real64), parameter :: head0 = -75.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  integer(int64), parameter :: ids(2) = [310001_int64, 310002_int64]
  integer(int64), parameter :: duplicate_ids(2) = [310001_int64, 310001_int64]
  integer(int64), parameter :: unknown_ids(1) = [319999_int64]

  type(fmr_logical_column_t), allocatable :: columns(:)
  type(fmr_template_t), allocatable :: templates(:)
  type(fmr_b110_physical_parameters_t), allocatable :: parameters(:)
  type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
  type(kernel_committed_state_t), allocatable :: states(:), baseline_states(:)
  type(fmr_serialized_column_result_t), allocatable :: results(:), baseline_results(:)
  type(fmr_column_diagnostics_t), allocatable :: diagnostics(:), baseline_diagnostics(:)
  type(fmr_aggregate_diagnostics_t) :: aggregate, baseline_aggregate
  type(fmr_root_uptake_attribution_record_t), allocatable :: attributions(:)
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(canonical_numerical_config_t) :: config
  integer :: dispatch_status, i
  real(real64) :: expected_a, expected_b, actual_t0, actual_t1
  logical :: available

  ! Reference run: exactly the same physical forcing without attribution output.
  call initialize_case(columns, templates, parameters, forcings, baseline_states, config)
  call reset_legacy_globals()
  call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, baseline_states, config, &
       top_provider, t0, t1, 2, baseline_results, baseline_diagnostics, baseline_aggregate, dispatch_status)
  call require(dispatch_status == FMR_SERIAL_DISPATCH_OK, 'baseline dispatch')
  call require(all(baseline_results%committed), 'baseline committed')

  ! Remediated route: one call owns both exact forcing and physical transaction.
  call initialize_case(columns, templates, parameters, forcings, states, config)
  expected_a = sum(forcings(1)%root_extraction_sink) * (t1 - t0)
  expected_b = sum(forcings(2)%root_extraction_sink) * (t1 - t0)
  call require(.not. same_bits(expected_a, expected_b), 'A and B attribution differ')
  call reset_legacy_globals()
  call fmr_run_serialized_root_uptake_attribution(columns, templates, parameters, forcings, states, config, &
       top_provider, t0, t1, 2, ids, results, diagnostics, aggregate, dispatch_status, attributions)
  call require(dispatch_status == FMR_SERIAL_DISPATCH_OK, 'attribution dispatch')
  call require(size(attributions) == 2, 'attribution shape')

  do i = 1, 2
    call require(results(i)%committed .and. results(i)%completed, 'attributed physical commit')
    call require(results(i)%mass%complete, 'attributed mass complete')
    call require(results(i)%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'mass missing mask zero')
    call require(abs(results(i)%mass%residual) <= hard_mass_gate, 'hard mass gate')
    call require(same_result(results(i), baseline_results(i)), 'physical result unchanged by attribution')
    call require(committed_fingerprint(states(i)) == committed_fingerprint(baseline_states(i)), &
         'committed state unchanged by attribution')
    call require(attributions(i)%column_id == ids(i), 'attribution column id')
    call require(attributions(i)%status == FMR_ROOT_ATTRIBUTION_OK, 'attribution status')
    call require(attributions(i)%receipt%ready(), 'attribution ready')
    call require(attributions(i)%receipt%current_lineage_id() == ids(i), 'attribution lineage')
    call require(attributions(i)%receipt%origin_revision() == 0_int64, 'attribution origin revision')
    call require(attributions(i)%receipt%committed_revision() == 1_int64, 'attribution committed revision')
    call attributions(i)%receipt%origin_interval(actual_t0, actual_t1, available)
    call require(available .and. same_bits(actual_t0,t0) .and. same_bits(actual_t1,t1), &
         'attribution generic interval')
  end do

  call require(same_bits(attributions(1)%receipt%actual_transpiration_amount(), expected_a), 'exact forcing A amount')
  call require(same_bits(attributions(2)%receipt%actual_transpiration_amount(), expected_b), 'exact forcing B amount')
  call require(attributions(1)%receipt%actual_transpiration_amount() <= results(1)%mass%total_out + hard_mass_gate, &
       'A attribution subset mass_out')
  call require(attributions(2)%receipt%actual_transpiration_amount() <= results(2)%mass%total_out + hard_mass_gate, &
       'B attribution subset mass_out')
  call require(same_bits(aggregate%aggregate_unrounded_mass_residual, baseline_aggregate%aggregate_unrounded_mass_residual), &
       'aggregate mass unchanged')
  write(*,'(A)') 'FMR31_EXACT_RUNTIME_FORCING_ATTRIBUTION=PASS'
  write(*,'(A)') 'FMR31_A_B_NO_CROSS_CONTAMINATION=PASS'
  write(*,'(A)') 'FMR31_PHYSICS_STATE_AND_MASS_IDENTITY=PASS'
  write(*,'(A)') 'FMR31_ARBITRARY_INTERVAL_PROVENANCE=PASS'

  ! Requested routing failure: no postcommit attribution may be published for
  ! the failed column, while the accepted neighbor remains valid.
  call initialize_case(columns, templates, parameters, forcings, states, config)
  columns(2)%parameter_ref = 99_int64
  call reset_legacy_globals()
  call fmr_run_serialized_root_uptake_attribution(columns, templates, parameters, forcings, states, config, &
       top_provider, t0, t1, 1, ids, results, diagnostics, aggregate, dispatch_status, attributions)
  call require(dispatch_status == FMR_SERIAL_DISPATCH_OK, 'isolated rejection dispatch')
  call require(attributions(1)%status == FMR_ROOT_ATTRIBUTION_OK .and. attributions(1)%receipt%ready(), &
       'accepted neighbor attribution')
  call require(attributions(2)%status == FMR_ROOT_ATTRIBUTION_NOT_COMMITTED, 'rejected attribution status')
  call require(.not. attributions(2)%receipt%ready(), 'rejected attribution not published')
  call require(states(1)%current_revision() == 1_int64 .and. states(2)%current_revision() == 0_int64, &
       'rejected column isolated')
  write(*,'(A)') 'FMR31_REJECTED_COLUMN_NO_ATTRIBUTION=PASS'

  ! Duplicate and unknown sparse requests are rejected by the existing trusted
  ! commit-receipt request gate before any physical mutation.
  call initialize_case(columns, templates, parameters, forcings, states, config)
  call reset_legacy_globals()
  call fmr_run_serialized_root_uptake_attribution(columns, templates, parameters, forcings, states, config, &
       top_provider, t0, t1, 2, duplicate_ids, results, diagnostics, aggregate, dispatch_status, attributions)
  call require(dispatch_status == FMR_SERIAL_DISPATCH_RECEIPT_REQUEST_REJECTED, 'duplicate request rejected')
  call require(all_revisions_zero(states), 'duplicate request no mutation')
  call require(all(.not. attribution_ready_array(attributions)), 'duplicate request no publication')
  call require(all(attributions%status == FMR_ROOT_ATTRIBUTION_RUNTIME_REJECTED), 'duplicate status')

  call initialize_case(columns, templates, parameters, forcings, states, config)
  call reset_legacy_globals()
  call fmr_run_serialized_root_uptake_attribution(columns, templates, parameters, forcings, states, config, &
       top_provider, t0, t1, 2, unknown_ids, results, diagnostics, aggregate, dispatch_status, attributions)
  call require(dispatch_status == FMR_SERIAL_DISPATCH_RECEIPT_REQUEST_REJECTED, 'unknown request rejected')
  call require(all_revisions_zero(states), 'unknown request no mutation')
  call require(.not. attributions(1)%receipt%ready(), 'unknown request no publication')
  write(*,'(A)') 'FMR31_INVALID_SPARSE_REQUEST_FAILS_PREMUTATION=PASS'

  write(*,'(A,ES26.17E3)') 'FMR31_QROT_A_AMOUNT=', expected_a
  write(*,'(A,ES26.17E3)') 'FMR31_QROT_B_AMOUNT=', expected_b
  write(*,'(A)') 'FMR31_ROOT_ATTRIBUTION_FORCING_BINDING_TEST PASS'

contains

  subroutine initialize_case(c, t, p, f, s, cfg)
    type(fmr_logical_column_t), allocatable, intent(out) :: c(:)
    type(fmr_template_t), allocatable, intent(out) :: t(:)
    type(fmr_b110_physical_parameters_t), allocatable, intent(out) :: p(:)
    type(fmr_b110_physical_forcing_t), allocatable, intent(out) :: f(:)
    type(kernel_committed_state_t), allocatable, intent(out) :: s(:)
    type(canonical_numerical_config_t), intent(out) :: cfg
    type(fmr_b110_physical_state_t) :: initial_state
    real(real64) :: conductivity0
    logical :: ok
    integer :: k

    allocate(c(2), t(1), p(1), f(2), s(2))
    call configure_template(t(1))
    call configure_parameters(p(1), initial_state, conductivity0)
    call configure_transaction(cfg)
    do k = 1, 2
      c(k)%column_id = ids(k)
      c(k)%template_id = t(1)%template_id
      c(k)%parameter_ref = 1_int64
      c(k)%state_handle = int(k,int64)
      c(k)%forcing_handle = int(k,int64)
      c(k)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
      call configure_forcing(f(k), conductivity0, real(k,real64))
      call fmr_new_b110_committed_state(s(k), ids(k), initial_state, t0, ok)
      call require(ok, 'committed state init')
    end do
  end subroutine initialize_case

  subroutine configure_template(template)
    type(fmr_template_t), intent(out) :: template
    template%template_id = 310_int64
    template%physics_topology_id = 31001_int64
    template%vertical_layout_id = 31002_int64
    template%state_layout_id = 31003_int64
    template%solver_interface_id = 31004_int64
    template%optional_state_layout_id = 0_int64
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_template

  subroutine configure_parameters(parameter, state, conductivity0)
    type(fmr_b110_physical_parameters_t), intent(out) :: parameter
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: conductivity0
    type(b110_default_mvg_parameters_t), target :: hyd_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: k

    parameter%parameter_set_id = 31001_int64
    parameter%active_nodes = numnod
    allocate(parameter%z(numnod), parameter%dz(numnod), parameter%node_distance(numnod), parameter%cofgen(24,numnod))
    parameter%z = z
    parameter%dz = dz
    parameter%node_distance = disnod(1:numnod)
    parameter%cofgen = 0.0_real64
    do k = 1, numnod
      parameter%cofgen(1,k) = 0.032_real64
      parameter%cofgen(2,k) = 0.423_real64
      parameter%cofgen(3,k) = 4.75_real64
      parameter%cofgen(4,k) = 0.0135_real64
      parameter%cofgen(5,k) = 0.365_real64
      parameter%cofgen(6,k) = 1.455_real64
      parameter%cofgen(7,k) = 1.0_real64 - 1.0_real64/parameter%cofgen(6,k)
      parameter%cofgen(8,k) = parameter%cofgen(4,k)
      parameter%cofgen(9,k) = 0.0_real64
      parameter%cofgen(10,k) = parameter%cofgen(3,k)
      parameter%cofgen(11,k) = 0.999_real64
      parameter%cofgen(12,k) = 0.99_real64*parameter%cofgen(3,k)
      parameter%cofgen(22,k) = -1.0e6_real64
      parameter%cofgen(23,k) = 1.0e-12_real64
    end do
    parameter%bottom_mode = 7
    parameter%swkimpl = 0
    parameter%swkmean = 1
    parameter%swsophy = 0
    parameter%root_extraction_active = .true.
    parameter%macropore_active = .false.
    parameter%snow_active = .false.
    parameter%hysteresis_active = .false.
    parameter%tabulated_hydraulics_active = .false.
    parameter%elasticity_active = .false.
    parameter%frost_active = .false.

    call initialize_b110_default_mvg_parameters(hyd_parameters, parameter%cofgen)
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

  subroutine configure_forcing(forcing, conductivity0, scale)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: conductivity0, scale
    integer :: k

    forcing%top_flux = -conductivity0
    forcing%top_head = head0
    forcing%bottom_flux = -conductivity0
    forcing%bottom_head = -100.0_real64
    allocate(forcing%drainage_flux_by_level(2,numnod), forcing%subsurface_irrigation_source(numnod), &
             forcing%root_extraction_sink(numnod))
    do k = 1, numnod
      forcing%drainage_flux_by_level(1,k) = 1.0e-5_real64*real(k,real64)
      forcing%drainage_flux_by_level(2,k) = -2.0e-6_real64*real(k+1,real64)
      forcing%subsurface_irrigation_source(k) = forcing%drainage_flux_by_level(1,k) + &
                                                forcing%drainage_flux_by_level(2,k)
      forcing%root_extraction_sink(k) = scale * 1.0e-5_real64 * real(k,real64)
    end do
  end subroutine configure_forcing

  subroutine configure_transaction(cfg)
    type(canonical_numerical_config_t), intent(out) :: cfg
    cfg%transaction%temporal_tolerance = 0.0_real64
    cfg%transaction%mass_tolerance = hard_mass_gate
    cfg%transaction%retry_scale = 0.5_real64
    cfg%transaction%max_retries = 2
    cfg%max_committed_substeps = 8
    cfg%progress_tolerance = 0.0_real64
  end subroutine configure_transaction

  subroutine reset_legacy_globals()
    legacy_qdra = 12345.0_real64
    legacy_qssdi = -54321.0_real64
    legacy_qrot = 0.0_real64
    swmacro = 0
    melt = 0.0_real64
  end subroutine reset_legacy_globals

  logical function same_result(a,b) result(equal)
    type(fmr_serialized_column_result_t), intent(in) :: a,b
    equal = a%column_id == b%column_id .and. a%kernel_status == b%kernel_status .and. &
         a%commit_status == b%commit_status .and. a%completed .eqv. b%completed .and. &
         a%committed .eqv. b%committed .and. a%solver_executed .eqv. b%solver_executed .and. &
         a%solver_iterations == b%solver_iterations .and. a%initial_revision == b%initial_revision .and. &
         a%final_revision == b%final_revision .and. same_bits(a%final_committed_time,b%final_committed_time) .and. &
         a%mass%complete .eqv. b%mass%complete .and. &
         a%mass%missing_contribution_mask == b%mass%missing_contribution_mask .and. &
         a%mass%origin_lineage_id == b%mass%origin_lineage_id .and. &
         a%mass%origin_revision == b%mass%origin_revision .and. &
         a%mass%accepted_transaction_count == b%mass%accepted_transaction_count .and. &
         same_bits(a%mass%interval_t0,b%mass%interval_t0) .and. same_bits(a%mass%interval_t1,b%mass%interval_t1) .and. &
         same_bits(a%mass%storage_start,b%mass%storage_start) .and. same_bits(a%mass%storage_end,b%mass%storage_end) .and. &
         same_bits(a%mass%storage_change,b%mass%storage_change) .and. same_bits(a%mass%total_in,b%mass%total_in) .and. &
         same_bits(a%mass%total_out,b%mass%total_out) .and. same_bits(a%mass%residual,b%mass%residual)
  end function same_result

  integer(int64) function committed_fingerprint(state) result(fp)
    type(kernel_committed_state_t), intent(in) :: state
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    integer :: k
    call state%snapshot(snapshot, got)
    call require(got, 'committed snapshot')
    fp = 1469598103934665603_int64
    select type (physical => snapshot)
    type is (fmr_b110_physical_state_t)
      fp = ieor(fp, int(physical%active_nodes,int64))
      do k = 1, physical%active_nodes
        fp = ieor(fp, transfer(physical%pressure_head(k),fp))
        fp = ieor(fp, transfer(physical%water_content(k),fp))
      end do
      fp = ieor(fp, transfer(physical%ponding_depth,fp))
      fp = ieor(fp, transfer(physical%groundwater_level,fp))
    class default
      error stop 'F-MR31 unexpected state type'
    end select
  end function committed_fingerprint

  logical function all_revisions_zero(s) result(ok)
    type(kernel_committed_state_t), intent(in) :: s(:)
    integer :: k
    ok = .true.
    do k = 1, size(s)
      if (s(k)%current_revision() /= 0_int64) then
        ok = .false.
        return
      end if
    end do
  end function all_revisions_zero

  function attribution_ready_array(a) result(values)
    type(fmr_root_uptake_attribution_record_t), intent(in) :: a(:)
    logical :: values(size(a))
    integer :: k
    do k = 1, size(a)
      values(k) = a(k)%receipt%ready()
    end do
  end function attribution_ready_array

  logical function same_bits(a,b) result(equal)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia, ib
    ia = transfer(a,ia)
    ib = transfer(b,ib)
    equal = ia == ib
  end function same_bits

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FMR31_TEST_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fmr31_root_attribution_forcing_binding
