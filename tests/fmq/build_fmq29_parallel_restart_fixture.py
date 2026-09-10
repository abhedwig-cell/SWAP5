#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: build_fmq29_parallel_restart_fixture.py INPUT OUTPUT")

src = Path(sys.argv[1])
out = Path(sys.argv[2])
s = src.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global s
    if s.count(old) != 1:
        raise SystemExit(f"FMQ29 generator anchor {label} count={s.count(old)}")
    s = s.replace(old, new, 1)


replace_once(
    "  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t\n",
    "  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t, fmr_committed_restart_record_t, &\n"
    "       fmr_export_committed_restart, fmr_restore_committed_restart, FMR_RESTART_OK\n"
    "  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t\n",
    "restart import",
)
replace_once(
    "  real(real64), parameter :: t1 = 4100.6875_real64\n",
    "  real(real64), parameter :: tm_fmq29 = 4100.4375_real64\n"
    "  real(real64), parameter :: t1 = 4100.6875_real64\n",
    "midpoint",
)
replace_once(
    "  integer :: k\n",
    "  integer, parameter :: fmq29_cases = 6\n"
    "  integer, parameter :: fmq29_n(fmq29_cases) = [3,5,9,16,23,33]\n"
    "  integer, parameter :: fmq29_batch(fmq29_cases) = [2,4,4,7,10,14]\n"
    "  integer, parameter :: fmq29_order(fmq29_cases) = [3,2,1,3,2,1]\n"
    "  integer, parameter :: fmq29_origin_workers(3) = [0,2,4]\n"
    "  integer :: k, oi, cw, ro\n",
    "main declarations",
)

main_anchor = "  call run_order_independence_case(17, 4)\n"
main_block = r'''  do k = 1, fmq29_cases
    do oi = 1, size(fmq29_origin_workers)
      do cw = 2, 4, 2
        do ro = 1, 2
          call run_fmq29_restart_case(fmq29_n(k), fmq29_batch(k), fmq29_order(k), &
               fmq29_origin_workers(oi), cw, ro)
        end do
      end do
    end do
    write(*,'(A,I0,A,I0,A,I0,A)') 'FMQ29_HELDOUT_N',fmq29_n(k),'_B',fmq29_batch(k), &
         '_O',fmq29_order(k),'=PASS'
  end do
  write(*,'(A)') 'FMQ29_SERIALIZED_ORIGIN_TO_PARALLEL=PASS'
  write(*,'(A)') 'FMQ29_PARALLEL_2_ORIGIN_TO_2_4=PASS'
  write(*,'(A)') 'FMQ29_PARALLEL_4_ORIGIN_TO_2_4=PASS'
  write(*,'(A)') 'FMQ29_CROSS_WORKER_2_TO_4=PASS'
  write(*,'(A)') 'FMQ29_CROSS_WORKER_4_TO_2=PASS'
  write(*,'(A)') 'FMQ29_REVERSE_AND_ODD_EVEN_RESTART_ORDER=PASS'
  write(*,'(A)') 'FMQ29_EXACT_MIDPOINT_COMMITTED_STATE=PASS'
  write(*,'(A)') 'FMQ29_FRESH_RECONSTRUCTED_TARGET=PASS'
  write(*,'(A)') 'FMQ29_ENDPOINT_RESTART_IDENTITY=PASS'
  write(*,'(A)') 'FMQ29_FCI34_PARALLEL_SCOPE_NOT_WIDENED=PASS'

'''
replace_once(main_anchor, main_block + main_anchor, "main composition insertion")

contains_anchor = "contains\n"
procedures = r'''contains

  subroutine run_fmq29_restart_case(n, batch_size, order_code, origin_workers, continuation_workers, record_order)
    integer, intent(in) :: n, batch_size, order_code, origin_workers, continuation_workers, record_order
    integer(int64), parameter :: restart_parameter_set_identity = 2902901_int64
    type(fmr_logical_column_t), allocatable :: base_columns(:), columns(:), rebuilt_base(:), rebuilt_columns(:)
    type(fmr_template_t) :: templates(1), rebuilt_templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(1), parameters_before(1), rebuilt_parameters(1)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:), rebuilt_forcings(:)
    type(fmr_b110_physical_state_t) :: seed, rebuilt_seed
    type(kernel_committed_state_t), allocatable :: reference_states(:), origin_states(:), restart_states(:)
    type(fmr_serialized_column_result_t), allocatable :: reference_first(:), reference_second(:), origin_first(:), restart_second(:)
    type(fmr_column_diagnostics_t), allocatable :: d_reference_first(:), d_reference_second(:), d_origin_first(:), d_restart_second(:)
    type(fmr_aggregate_diagnostics_t) :: a_reference_first, a_reference_second, a_origin_first, a_restart_second
    type(fmr_serialized_batch_diagnostics_t) :: rt_reference_first, rt_reference_second, rt_origin_first, rt_restart_second
    type(fixed_flux_top_boundary_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    type(fmr_committed_restart_bundle_t) :: bundle
    real(real64) :: conductivity0, rebuilt_conductivity0
    integer :: serial_status, dispatch_status, pool_status, restart_status, i
    logical :: exported, restored

    call build_fixture(n, base_columns, templates, parameters, forcings, seed, conductivity0)
    parameters_before = parameters
    call permute_columns(base_columns, order_code, columns)
    call configure_transaction(config)
    call initialize_states(reference_states, base_columns, seed)
    call initialize_states(origin_states, base_columns, seed)

    ! Independent uninterrupted reference reaches the same committed midpoint
    ! using the continuation worker count selected for this attack.
    call fmr_run_parallel_physical_multiswap(columns, templates, parameters, forcings, reference_states, config, top_provider, &
         t0, tm_fmq29, batch_size, continuation_workers, reference_first, d_reference_first, a_reference_first, &
         dispatch_status, pool_status, rt_reference_first)
    call require(pool_status == FMR_PARALLEL_POOL_OK .and. dispatch_status == FMR_SERIAL_DISPATCH_OK, &
         'FMQ29 reference midpoint status')
    call require(all_committed(reference_first), 'FMQ29 reference midpoint committed')
    call require(max_abs_residual(reference_first) <= hard_mass_gate, 'FMQ29 reference midpoint mass')

    if (origin_workers == 0) then
      call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, origin_states, config, top_provider, &
           t0, tm_fmq29, batch_size, origin_first, d_origin_first, a_origin_first, serial_status, rt_origin_first)
      call require(serial_status == FMR_SERIAL_DISPATCH_OK, 'FMQ29 serialized origin status')
    else
      call fmr_run_parallel_physical_multiswap(columns, templates, parameters, forcings, origin_states, config, top_provider, &
           t0, tm_fmq29, batch_size, origin_workers, origin_first, d_origin_first, a_origin_first, &
           dispatch_status, pool_status, rt_origin_first)
      call require(pool_status == FMR_PARALLEL_POOL_OK .and. dispatch_status == FMR_SERIAL_DISPATCH_OK, &
           'FMQ29 parallel origin status')
    end if
    call require(all_committed(origin_first), 'FMQ29 origin midpoint committed')
    call require(max_abs_residual(origin_first) <= hard_mass_gate, 'FMQ29 origin midpoint mass')

    ! This assertion is intentionally before export and before the uninterrupted
    ! reference advances further. It is the hard midpoint committed-state gate.
    call require(result_sets_by_id_identical(reference_first, origin_first), 'FMQ29 midpoint result identity')
    call require(diagnostics_by_id_semantically_identical(d_reference_first, d_origin_first), 'FMQ29 midpoint diagnostics identity')
    call require(states_identical(reference_states, origin_states), 'FMQ29 exact midpoint committed-state identity')
    call require(aggregate_semantically_identical(a_reference_first, a_origin_first), 'FMQ29 midpoint aggregate identity')
    call require(all_attribution_unavailable(reference_first) .and. all_attribution_unavailable(origin_first), &
         'FMQ29 no parallel root-attribution scope widening at midpoint')

    call fmr_export_committed_restart(columns, templates, origin_states, restart_parameter_set_identity, bundle, exported, restart_status)
    call require(exported .and. restart_status == FMR_RESTART_OK, 'FMQ29 committed restart export')
    call require(allocated(bundle%records) .and. size(bundle%records) == n, 'FMQ29 restart record count')
    call reorder_restart_records(bundle, record_order)

    ! Destroy the origin runtime-facing allocatables. Restore must target a
    ! freshly reconstructed registry, not a retained initialized state array.
    deallocate(base_columns, columns, forcings, origin_states)
    call build_fixture(n, rebuilt_base, rebuilt_templates, rebuilt_parameters, rebuilt_forcings, rebuilt_seed, rebuilt_conductivity0)
    call permute_columns(rebuilt_base, order_code, rebuilt_columns)
    allocate(restart_states(n))
    do i = 1, n
      call require(.not. restart_states(i)%ready(), 'FMQ29 fresh target before restore')
    end do
    call require(parameters_identical(parameters_before, rebuilt_parameters), 'FMQ29 reconstructed immutable parameters')

    call fmr_restore_committed_restart(bundle, restart_parameter_set_identity, rebuilt_columns, rebuilt_templates, &
         restart_states, restored, restart_status)
    call require(restored .and. restart_status == FMR_RESTART_OK, 'FMQ29 whole-registry restore')
    call require(states_identical(reference_states, restart_states), 'FMQ29 restored midpoint state exact')

    ! Advance both the uninterrupted reference and the reconstructed runtime
    ! over the same second interval and with the same continuation worker count.
    call fmr_run_parallel_physical_multiswap(rebuilt_columns, rebuilt_templates, rebuilt_parameters, rebuilt_forcings, &
         reference_states, config, top_provider, tm_fmq29, t1, batch_size, continuation_workers, reference_second, &
         d_reference_second, a_reference_second, dispatch_status, pool_status, rt_reference_second)
    call require(pool_status == FMR_PARALLEL_POOL_OK .and. dispatch_status == FMR_SERIAL_DISPATCH_OK, &
         'FMQ29 uninterrupted continuation status')

    call fmr_run_parallel_physical_multiswap(rebuilt_columns, rebuilt_templates, rebuilt_parameters, rebuilt_forcings, &
         restart_states, config, top_provider, tm_fmq29, t1, batch_size, continuation_workers, restart_second, &
         d_restart_second, a_restart_second, dispatch_status, pool_status, rt_restart_second)
    call require(pool_status == FMR_PARALLEL_POOL_OK .and. dispatch_status == FMR_SERIAL_DISPATCH_OK, &
         'FMQ29 restart continuation status')

    call require(all_committed(reference_second) .and. all_committed(restart_second), 'FMQ29 endpoint committed')
    call require(max_abs_residual(reference_second) <= hard_mass_gate, 'FMQ29 reference endpoint hard mass')
    call require(max_abs_residual(restart_second) <= hard_mass_gate, 'FMQ29 restart endpoint hard mass')
    call require(result_sets_by_id_identical(reference_second, restart_second), 'FMQ29 endpoint result identity')
    call require(diagnostics_by_id_semantically_identical(d_reference_second, d_restart_second), 'FMQ29 endpoint diagnostics identity')
    call require(states_identical(reference_states, restart_states), 'FMQ29 endpoint committed-state identity')
    call require(aggregate_semantically_identical(a_reference_second, a_restart_second), 'FMQ29 endpoint aggregate identity')
    call require(runtime_semantically_identical(rt_reference_second, rt_restart_second), 'FMQ29 endpoint runtime mass identity')
    call require(rt_reference_second%authoritative_aggregate_mass%complete, 'FMQ29 reference aggregate complete')
    call require(rt_restart_second%authoritative_aggregate_mass%complete, 'FMQ29 restart aggregate complete')
    call require(all_attribution_unavailable(reference_second) .and. all_attribution_unavailable(restart_second), &
         'FMQ29 no parallel root-attribution scope widening at endpoint')
    do i = 2, size(restart_second)
      call require(restart_second(i-1)%column_id < restart_second(i)%column_id, 'FMQ29 canonical publication order')
    end do
  end subroutine run_fmq29_restart_case

  subroutine reorder_restart_records(bundle, mode)
    type(fmr_committed_restart_bundle_t), intent(inout) :: bundle
    integer, intent(in) :: mode
    type(fmr_committed_restart_record_t), allocatable :: reordered(:)
    integer :: i, k, n

    call require(allocated(bundle%records), 'FMQ29 reorder allocated records')
    n = size(bundle%records)
    allocate(reordered(n))
    select case (mode)
    case (1)
      do i = 1, n
        reordered(i) = bundle%records(n-i+1)
      end do
    case (2)
      k = 0
      do i = 1, n, 2
        k = k + 1
        reordered(k) = bundle%records(i)
      end do
      do i = 2, n, 2
        k = k + 1
        reordered(k) = bundle%records(i)
      end do
      call require(k == n, 'FMQ29 odd-even reorder cardinality')
    case default
      call require(.false., 'FMQ29 unsupported record order')
    end select
    call move_alloc(reordered, bundle%records)
  end subroutine reorder_restart_records

  logical function all_attribution_unavailable(results) result(ok)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    integer :: i
    ok = .true.
    do i = 1, size(results)
      if (results(i)%actual_transpiration_available) then
        ok = .false.
        return
      end if
      if (.not. same_bits(results(i)%actual_transpiration_amount, 0.0_real64)) then
        ok = .false.
        return
      end if
    end do
  end function all_attribution_unavailable

'''
replace_once(contains_anchor, procedures, "contains insertion")

out.write_text(s)
