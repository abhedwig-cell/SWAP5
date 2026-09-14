program test_fgc25_permutation_determinism
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_head_datum_t
  use mod_groundwater_coupling_policy, only: groundwater_head_convergence_policy_t
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, &
       groundwater_interface_mass_snapshot_t, GW_MASS_LEDGER_OK
  use mod_groundwater_predictor_corrector_window, only: groundwater_coupling_origin_t
  use mod_groundwater_multiswap_types, only: groundwater_direct_tile_binding_t, groundwater_multiswap_result_t, &
       GW_MULTI_OK
  use mod_groundwater_multiswap_topology, only: build_canonical_tile_order, stable_ordered_sum
  use mod_groundwater_multiswap_coupler, only: run_restricted_groundwater_multiswap_cell_window
  use mod_fgc21_restricted_predictor_corrector_owner_test, only: dummy_model_t, dummy_parameters_t, &
       dummy_materializer_t, dummy_groundwater_service_t, check
  use mod_fgc25_multiswap_fixture, only: setup_fgc25_two_tiles
  implicit none

  integer :: failures

  failures = 0
  call test_stable_sum_canonical_permutation(failures)
  call test_full_cell_input_permutation(failures)
  if (failures /= 0) then
    write(*,'(A,I0)') 'F-GC25 PERMUTATION DETERMINISM FAILURES=', failures
    error stop 1
  end if
  write(*,'(A)') 'F-GC25 PERMUTATION DETERMINISM PASS'

contains

  subroutine test_stable_sum_canonical_permutation(failures)
    integer, intent(inout) :: failures
    type(groundwater_direct_tile_binding_t) :: a(3), b(3)
    real(real64) :: va(3), vb(3), sa, sb
    integer :: oa(3), ob(3), status_a, status_b

    a(1)%groundwater_cell_id = 7001_int64
    a(1)%tile_id = 30_int64
    a(1)%area_fraction = 0.30_real64
    a(2)%groundwater_cell_id = 7001_int64
    a(2)%tile_id = 10_int64
    a(2)%area_fraction = 0.20_real64
    a(3)%groundwater_cell_id = 7001_int64
    a(3)%tile_id = 20_int64
    a(3)%area_fraction = 0.50_real64
    va = [1.0_real64, 1.0e16_real64, -1.0e16_real64]

    b(1) = a(3)
    b(2) = a(1)
    b(3) = a(2)
    vb = [va(3), va(1), va(2)]

    call build_canonical_tile_order(a, oa, status_a)
    call build_canonical_tile_order(b, ob, status_b)
    call check(status_a == GW_MULTI_OK .and. status_b == GW_MULTI_OK, &
         'permutation: canonical order accepted', failures)
    call check(a(oa(1))%tile_id == 10_int64 .and. a(oa(2))%tile_id == 20_int64 .and. &
         a(oa(3))%tile_id == 30_int64, 'permutation: first input canonicalized by tile id', failures)
    call check(b(ob(1))%tile_id == 10_int64 .and. b(ob(2))%tile_id == 20_int64 .and. &
         b(ob(3))%tile_id == 30_int64, 'permutation: permuted input canonicalized identically', failures)

    sa = stable_ordered_sum(va, oa)
    sb = stable_ordered_sum(vb, ob)
    call check(transfer(sa, 0_int64) == transfer(sb, 0_int64), &
         'permutation: canonical stable sum bit-identical', failures)
    call check(transfer(sa, 0_int64) == transfer(1.0_real64, 0_int64), &
         'permutation: adversarial three-term sum follows canonical order', failures)
  end subroutine test_stable_sum_canonical_permutation

  subroutine test_full_cell_input_permutation(failures)
    integer, intent(inout) :: failures
    type(kernel_executor_t) :: executor_a, executor_b
    type(kernel_committed_state_t) :: committed_a(2), committed_b(2), temp_committed
    type(dummy_model_t), target :: model_a, model_b
    type(dummy_parameters_t) :: parameters_a(2), parameters_b(2), temp_parameters
    type(dummy_materializer_t) :: materializer
    type(dummy_groundwater_service_t) :: groundwater_a, groundwater_b
    type(groundwater_interface_mass_ledger_t) :: ledgers_a(2), ledgers_b(2), temp_ledger
    type(groundwater_interface_mass_snapshot_t) :: snap_a1, snap_a2, snap_b1, snap_b2
    type(groundwater_head_datum_t) :: datum_a, datum_b
    type(groundwater_head_convergence_policy_t) :: policy_a, policy_b
    type(groundwater_coupling_window_t) :: window_a, window_b
    type(groundwater_coupling_origin_t) :: origins_a(2), origins_b(2), temp_origin
    type(groundwater_direct_tile_binding_t) :: bindings_a(2), bindings_b(2), temp_binding
    type(groundwater_multiswap_result_t) :: result_a, result_b
    type(canonical_numerical_config_t) :: numerical_a, numerical_b
    integer :: status_a, status_b

    call setup_fgc25_two_tiles(executor_a, model_a, parameters_a, groundwater_a, ledgers_a, datum_a, policy_a, &
         window_a, origins_a, numerical_a, committed_a, bindings_a, status_a)
    call setup_fgc25_two_tiles(executor_b, model_b, parameters_b, groundwater_b, ledgers_b, datum_b, policy_b, &
         window_b, origins_b, numerical_b, committed_b, bindings_b, status_b)
    call check(status_a == GW_MASS_LEDGER_OK .and. status_b == GW_MASS_LEDGER_OK, &
         'permutation-full: setup', failures)

    temp_parameters = parameters_b(1)
    parameters_b(1) = parameters_b(2)
    parameters_b(2) = temp_parameters
    temp_committed = committed_b(1)
    committed_b(1) = committed_b(2)
    committed_b(2) = temp_committed
    temp_ledger = ledgers_b(1)
    ledgers_b(1) = ledgers_b(2)
    ledgers_b(2) = temp_ledger
    temp_origin = origins_b(1)
    origins_b(1) = origins_b(2)
    origins_b(2) = temp_origin
    temp_binding = bindings_b(1)
    bindings_b(1) = bindings_b(2)
    bindings_b(2) = temp_binding

    call run_restricted_groundwater_multiswap_cell_window(executor_a, parameters_a, committed_a, bindings_a, &
         materializer, numerical_a, groundwater_a, ledgers_a, datum_a, policy_a, window_a, origins_a, result_a)
    call run_restricted_groundwater_multiswap_cell_window(executor_b, parameters_b, committed_b, bindings_b, &
         materializer, numerical_b, groundwater_b, ledgers_b, datum_b, policy_b, window_b, origins_b, result_b)

    call check(result_a%status == GW_MULTI_OK .and. result_b%status == GW_MULTI_OK, &
         'permutation-full: both executions accepted', failures)
    call check(transfer(result_a%accepted_cell_exchange_m, 0_int64) == &
         transfer(result_b%accepted_cell_exchange_m, 0_int64), &
         'permutation-full: accepted cell exchange bit-identical', failures)
    call check(transfer(result_a%corrector_aggregate%q_swap_area_weighted_m_per_s, 0_int64) == &
         transfer(result_b%corrector_aggregate%q_swap_area_weighted_m_per_s, 0_int64), &
         'permutation-full: aggregate flux bit-identical', failures)
    call check(transfer(groundwater_a%last_q_groundwater_m_per_s, 0_int64) == &
         transfer(groundwater_b%last_q_groundwater_m_per_s, 0_int64), &
         'permutation-full: groundwater forcing bit-identical', failures)
    call check(result_a%groundwater_cell_id == result_b%groundwater_cell_id, &
         'permutation-full: groundwater cell identity preserved', failures)

    call ledgers_a(1)%snapshot(snap_a1)
    call ledgers_a(2)%snapshot(snap_a2)
    call ledgers_b(1)%snapshot(snap_b1)
    call ledgers_b(2)%snapshot(snap_b2)
    call check(transfer(snap_a1%committed_swap_outward_exchange_m, 0_int64) == &
         transfer(snap_b2%committed_swap_outward_exchange_m, 0_int64), &
         'permutation-full: tile 201 ledger follows tile across input permutation', failures)
    call check(transfer(snap_a2%committed_swap_outward_exchange_m, 0_int64) == &
         transfer(snap_b1%committed_swap_outward_exchange_m, 0_int64), &
         'permutation-full: tile 202 ledger follows tile across input permutation', failures)
    call check(result_a%tile_weighted_exchange_m(1) == result_b%tile_weighted_exchange_m(2) .and. &
         result_a%tile_weighted_exchange_m(2) == result_b%tile_weighted_exchange_m(1), &
         'permutation-full: weighted exchanges remain index-local to their tiles', failures)
    call check(committed_a(1)%current_revision() == committed_b(2)%current_revision() .and. &
         committed_a(2)%current_revision() == committed_b(1)%current_revision(), &
         'permutation-full: committed revisions follow tile identity', failures)
  end subroutine test_full_cell_input_permutation

end program test_fgc25_permutation_determinism
