program test_fgc25_single_tile_equivalence
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_head_datum_t
  use mod_groundwater_coupling_policy, only: groundwater_head_convergence_policy_t
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, &
       groundwater_interface_mass_snapshot_t
  use mod_groundwater_predictor_corrector_window, only: groundwater_coupling_origin_t, groundwater_pc_result_t, &
       run_restricted_groundwater_coupling_window, GW_PC_OK
  use mod_groundwater_multiswap_types, only: groundwater_direct_tile_binding_t, groundwater_multiswap_result_t, &
       GW_MULTI_OK
  use mod_groundwater_multiswap_coupler, only: run_restricted_groundwater_multiswap_cell_window
  use mod_fgc21_restricted_predictor_corrector_owner_test, only: dummy_model_t, dummy_parameters_t, &
       dummy_materializer_t, dummy_groundwater_service_t, setup_common, check, check_close
  use mod_fgc25_multiswap_fixture, only: setup_fgc25_one_tile
  implicit none

  integer :: failures, status
  logical :: initialized
  type(kernel_executor_t) :: scalar_executor, multi_executor
  type(kernel_committed_state_t) :: scalar_committed, multi_committed(1)
  type(dummy_model_t), target :: scalar_model, multi_model
  type(dummy_parameters_t) :: scalar_parameters, multi_parameters(1)
  type(dummy_materializer_t) :: materializer
  type(dummy_groundwater_service_t) :: scalar_groundwater, multi_groundwater
  type(groundwater_interface_mass_ledger_t) :: scalar_ledger, multi_ledgers(1)
  type(groundwater_interface_mass_snapshot_t) :: scalar_snapshot, multi_snapshot
  type(groundwater_head_datum_t) :: scalar_datum, multi_datum
  type(groundwater_head_convergence_policy_t) :: scalar_policy, multi_policy
  type(groundwater_coupling_window_t) :: scalar_window, multi_window
  type(groundwater_coupling_origin_t) :: scalar_origin, multi_origins(1)
  type(groundwater_pc_result_t) :: scalar_result
  type(groundwater_multiswap_result_t) :: multi_result
  type(groundwater_direct_tile_binding_t) :: bindings(1)
  type(canonical_numerical_config_t) :: scalar_numerical, multi_numerical
  class(transaction_state_t), allocatable :: initial_state

  failures = 0
  call setup_common(scalar_executor, scalar_model, scalar_parameters, scalar_groundwater, scalar_ledger, &
       scalar_datum, scalar_policy, scalar_window, scalar_origin, scalar_numerical, scalar_committed, &
       initial_state, initialized, status)
  call check(initialized, 'single-equivalence: GC21 setup initialized', failures)
  call run_restricted_groundwater_coupling_window(scalar_executor, scalar_parameters, scalar_committed, materializer, &
       scalar_numerical, scalar_groundwater, scalar_ledger, scalar_datum, scalar_policy, scalar_window, &
       scalar_origin, scalar_result)

  call setup_fgc25_one_tile(multi_executor, multi_model, multi_parameters, multi_groundwater, multi_ledgers, &
       multi_datum, multi_policy, multi_window, multi_origins, multi_numerical, multi_committed, bindings, status)
  call run_restricted_groundwater_multiswap_cell_window(multi_executor, multi_parameters, multi_committed, bindings, &
       materializer, multi_numerical, multi_groundwater, multi_ledgers, multi_datum, multi_policy, multi_window, &
       multi_origins, multi_result)

  call check(scalar_result%status == GW_PC_OK .and. multi_result%status == GW_MULTI_OK, &
       'single-equivalence: both routes accepted', failures)
  call check_close(multi_result%corrector_aggregate%q_swap_area_weighted_m_per_s, &
       scalar_result%corrector_q_swap_m_per_s, 1.0e-20_real64, 'single-equivalence: q swap', failures)
  call check_close(multi_result%corrector_h_groundwater_m, scalar_result%corrector_h_groundwater_m, &
       1.0e-15_real64, 'single-equivalence: groundwater head', failures)
  call check(multi_committed(1)%current_revision() == scalar_committed%current_revision(), &
       'single-equivalence: SWAP revision', failures)
  call check(multi_groundwater%revision == scalar_groundwater%revision, &
       'single-equivalence: groundwater revision', failures)
  call scalar_ledger%snapshot(scalar_snapshot)
  call multi_ledgers(1)%snapshot(multi_snapshot)
  call check_close(multi_snapshot%committed_swap_outward_exchange_m, scalar_snapshot%committed_swap_outward_exchange_m, &
       1.0e-16_real64, 'single-equivalence: committed ledger mass', failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'F-GC25 SINGLE TILE EQUIVALENCE FAILURES=', failures
    error stop 1
  end if
  write(*,'(A)') 'F-GC25 SINGLE TILE EQUIVALENCE PASS'
end program test_fgc25_single_tile_equivalence
