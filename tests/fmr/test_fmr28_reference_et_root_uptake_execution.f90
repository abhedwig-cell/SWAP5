program test_fmr28_reference_et_root_uptake_execution
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t
  use mod_reference_et_demand_process, only: reference_et_demand_result_t
  use mod_fmr_reference_et_demand_binding, only: fmr_reference_et_binding_diagnostics_t, FMR_REFERENCE_ET_BINDING_OK
  use mod_fmr_reference_et_ptra_root_input_binding, only: fmr_ptra_root_input_binding_diagnostics_t, &
       fmr_bind_reference_et_ptra_to_root_input, FMR_PTRA_ROOT_INPUT_BINDING_OK
  use mod_root_water_uptake_process, only: root_water_uptake_parameters_t, root_water_uptake_flux_result_t, &
       root_water_uptake_diagnostics_t
  use mod_fmr_root_uptake_process_binding, only: fmr_root_uptake_binding_diagnostics_t
  use mod_fmr_crop_root_uptake_input_adapter, only: fmr_crop_root_uptake_adapter_diagnostics_t, &
       fmr_evaluate_shared_crop_root_uptake, FMR_CROP_ROOT_ADAPTER_OK
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_new_b110_committed_state
  use mod_fmr_reference_et_root_uptake_composition, only: fmr_reference_et_root_uptake_diagnostics_t, &
       fmr_evaluate_reference_et_root_uptake, FMR_REFERENCE_ET_ROOT_UPTAKE_OK, &
       FMR_REFERENCE_ET_ROOT_UPTAKE_PTRA_REJECTED
  implicit none

  type(root_water_uptake_parameters_t) :: parameters
  type(fmr_b110_physical_state_t) :: physical
  type(kernel_committed_state_t) :: committed, unavailable
  type(crop_root_uptake_input_t) :: base_a, base_stale, base_bad, base_inactive, manual_bound
  type(reference_et_demand_result_t) :: et_a, et_b, et_zero
  type(fmr_reference_et_binding_diagnostics_t) :: et_ok, et_rejected
  type(root_water_uptake_flux_result_t) :: got_a1, got_stale, got_b, got_a2, got_reject, got_bad, got_inactive, manual_flux
  type(root_water_uptake_diagnostics_t) :: proc_a1, proc_stale, proc_b, proc_a2, proc_reject, proc_bad, proc_inactive, manual_proc
  type(fmr_ptra_root_input_binding_diagnostics_t) :: ptra_a1, ptra_stale, ptra_b, ptra_a2, ptra_reject, ptra_bad, &
       ptra_inactive, manual_ptra
  type(fmr_crop_root_uptake_adapter_diagnostics_t) :: adapter_a1, adapter_stale, adapter_b, adapter_a2, adapter_reject, &
       adapter_bad, adapter_inactive, manual_adapter
  type(fmr_root_uptake_binding_diagnostics_t) :: bind_a1, bind_stale, bind_b, bind_a2, bind_reject, bind_bad, &
       bind_inactive, manual_bind
  type(fmr_reference_et_root_uptake_diagnostics_t) :: diag_a1, diag_stale, diag_b, diag_a2, diag_reject, diag_bad, diag_inactive
  class(transaction_state_t), allocatable :: snapshot_before, snapshot_after
  integer(int64) :: revision_before
  logical :: ok

  call configure_parameters(parameters)
  call configure_physical_state(physical)
  call fmr_new_b110_committed_state(committed, 2801_int64, physical, 5000.25_real64, ok)
  call require(ok, 'committed init')
  revision_before = committed%current_revision()
  call committed%snapshot(snapshot_before, ok)
  call require(ok, 'snapshot before')

  call configure_active_base(base_a, 0.01_real64, [0.0_real64, 0.15_real64, 0.50_real64, 1.0_real64])
  base_stale = base_a
  base_stale%potential_transpiration = 9.5_real64
  et_a%potential_transpiration_cm_per_day = 0.30_real64
  et_a%potential_soil_evaporation_cm_per_day = 0.12_real64
  et_a%potential_pond_evaporation_cm_per_day = 0.15_real64
  et_b = et_a
  et_b%potential_transpiration_cm_per_day = 0.42_real64
  et_ok%status = FMR_REFERENCE_ET_BINDING_OK
  et_ok%result_produced = .true.

  call fmr_bind_reference_et_ptra_to_root_input(base_a, parameters%active_nodes, et_a, et_ok, manual_bound, manual_ptra)
  call require(manual_ptra%status == FMR_PTRA_ROOT_INPUT_BINDING_OK .and. manual_ptra%result_produced, 'manual ptra bind')
  call fmr_evaluate_shared_crop_root_uptake(committed, parameters, manual_bound, manual_flux, manual_proc, manual_bind, manual_adapter)
  call require(manual_adapter%status == FMR_CROP_ROOT_ADAPTER_OK, 'manual root chain')

  call fmr_evaluate_reference_et_root_uptake(committed, parameters, base_a, et_a, et_ok, got_a1, proc_a1, ptra_a1, &
       adapter_a1, bind_a1, diag_a1)
  call require(diag_a1%status == FMR_REFERENCE_ET_ROOT_UPTAKE_OK .and. diag_a1%result_produced, 'A1 status')
  call require(diag_a1%ptra_binding_called .and. diag_a1%root_execution_called, 'A1 stages called')
  call require(all_bits_identical(got_a1%root_extraction_sink, manual_flux%root_extraction_sink), 'explicit-chain node sinks')
  call require(same_bits(got_a1%actual_uptake_total, manual_flux%actual_uptake_total), 'explicit-chain total')
  call require(all_bits_identical(proc_a1%potential_root_sink, manual_proc%potential_root_sink), 'explicit-chain diagnostics')
  write(*,'(A)') 'FMR28_EXPLICIT_FCI29_FMR12_FMR10_CHAIN_BITWISE_IDENTITY=PASS'

  call fmr_evaluate_reference_et_root_uptake(committed, parameters, base_stale, et_a, et_ok, got_stale, proc_stale, &
       ptra_stale, adapter_stale, bind_stale, diag_stale)
  call require(diag_stale%status == FMR_REFERENCE_ET_ROOT_UPTAKE_OK, 'stale ptra status')
  call require(ptra_stale%incoming_ptra_ignored, 'stale ptra ignored marker')
  call require(all_bits_identical(got_a1%root_extraction_sink, got_stale%root_extraction_sink), 'stale ptra node independence')
  call require(same_bits(got_a1%actual_uptake_total, got_stale%actual_uptake_total), 'stale ptra total independence')
  write(*,'(A)') 'FMR28_STALE_INCOMING_PTRA_CANNOT_AFFECT_ROOT_UPTAKE=PASS'

  et_rejected = et_ok
  et_rejected%status = 1
  et_rejected%result_produced = .false.
  call fmr_evaluate_reference_et_root_uptake(committed, parameters, base_a, et_a, et_rejected, got_reject, proc_reject, &
       ptra_reject, adapter_reject, bind_reject, diag_reject)
  call require(diag_reject%status == FMR_REFERENCE_ET_ROOT_UPTAKE_PTRA_REJECTED, 'ET rejection status')
  call require(.not. diag_reject%root_execution_called, 'ET rejection blocks execution')
  call require(.not. allocated(got_reject%root_extraction_sink), 'ET rejection zero/default flux')
  write(*,'(A)') 'FMR28_UPSTREAM_ET_REJECTION_BLOCKS_ROOT_EXECUTION=PASS'

  base_bad = base_a
  base_bad%cumulative_root_fraction(4) = 0.95_real64
  call fmr_evaluate_reference_et_root_uptake(committed, parameters, base_bad, et_a, et_ok, got_bad, proc_bad, ptra_bad, &
       adapter_bad, bind_bad, diag_bad)
  call require(diag_bad%status == FMR_REFERENCE_ET_ROOT_UPTAKE_PTRA_REJECTED, 'bad geometry status')
  call require(.not. diag_bad%root_execution_called, 'bad geometry blocks execution')
  call require(.not. allocated(got_bad%root_extraction_sink), 'bad geometry zero/default flux')
  write(*,'(A)') 'FMR28_INVALID_ROOT_GEOMETRY_BLOCKS_ROOT_EXECUTION=PASS'

  base_inactive = crop_root_uptake_input_t()
  et_zero = reference_et_demand_result_t()
  call fmr_evaluate_reference_et_root_uptake(unavailable, parameters, base_inactive, et_zero, et_ok, got_inactive, proc_inactive, &
       ptra_inactive, adapter_inactive, bind_inactive, diag_inactive)
  call require(diag_inactive%status == FMR_REFERENCE_ET_ROOT_UPTAKE_OK .and. diag_inactive%result_produced, 'inactive status')
  call require(bind_inactive%inactive_crop_zero_route .and. .not. bind_inactive%hydraulic_view_built, 'inactive dependency-free route')
  call require(allocated(got_inactive%root_extraction_sink), 'inactive sink allocated')
  call require(all_zero_bits(got_inactive%root_extraction_sink), 'inactive sink zero')
  write(*,'(A)') 'FMR28_INACTIVE_CROP_DEPENDENCY_FREE_ZERO_ROUTE=PASS'

  call committed%snapshot(snapshot_after, ok)
  call require(ok, 'snapshot after')
  call require(committed%current_revision() == revision_before, 'revision unchanged')
  call require(physical_snapshot_identical(snapshot_before, snapshot_after), 'physical state unchanged')
  write(*,'(A)') 'FMR28_COMMITTED_STATE_READ_ONLY=PASS'

  call fmr_evaluate_reference_et_root_uptake(committed, parameters, base_a, et_b, et_ok, got_b, proc_b, ptra_b, adapter_b, &
       bind_b, diag_b)
  call require(diag_b%status == FMR_REFERENCE_ET_ROOT_UPTAKE_OK, 'B status')
  call require(.not. all_bits_identical(got_a1%root_extraction_sink, got_b%root_extraction_sink), 'B differs from A')
  call fmr_evaluate_reference_et_root_uptake(committed, parameters, base_a, et_a, et_ok, got_a2, proc_a2, ptra_a2, adapter_a2, &
       bind_a2, diag_a2)
  call require(diag_a2%status == FMR_REFERENCE_ET_ROOT_UPTAKE_OK, 'A2 status')
  call require(all_bits_identical(got_a1%root_extraction_sink, got_a2%root_extraction_sink), 'A/B/A sinks')
  call require(same_bits(got_a1%actual_uptake_total, got_a2%actual_uptake_total), 'A/B/A total')
  call require(all_bits_identical(proc_a1%drought_reduction, proc_a2%drought_reduction), 'A/B/A diagnostics')
  call require(committed%current_revision() == revision_before, 'A/B/A revision')
  write(*,'(A)') 'FMR28_STATELESS_A_B_A_IDENTITY=PASS'
  write(*,'(A)') 'FMR28_REFERENCE_ET_ROOT_UPTAKE_EXECUTION_COMPOSITION_TEST PASS'

contains

  subroutine configure_parameters(p)
    type(root_water_uptake_parameters_t), intent(out) :: p
    p%active_nodes = 4
    p%hlim3l = -800.0_real64
    p%hlim3h = -400.0_real64
    p%hlim4 = -16000.0_real64
    p%adcrl = 0.10_real64
    p%adcrh = 0.50_real64
  end subroutine configure_parameters

  subroutine configure_physical_state(s)
    type(fmr_b110_physical_state_t), intent(out) :: s
    s%active_nodes = 4
    allocate(s%pressure_head(4), s%water_content(4))
    s%pressure_head = [-17000.0_real64, -8000.0_real64, -600.0_real64, -100.0_real64]
    s%water_content = [0.10_real64, 0.15_real64, 0.22_real64, 0.30_real64]
    s%ponding_depth = 0.0_real64
    s%groundwater_level = -2.0_real64
  end subroutine configure_physical_state

  subroutine configure_active_base(x, stale_ptra, distribution)
    type(crop_root_uptake_input_t), intent(out) :: x
    real(real64), intent(in) :: stale_ptra
    real(real64), intent(in) :: distribution(4)
    x%crop_emerged = .true.
    x%potential_transpiration = stale_ptra
    x%rooted_nodes = 3
    allocate(x%cumulative_root_fraction(4))
    x%cumulative_root_fraction = distribution
  end subroutine configure_active_base

  logical function same_bits(a, b) result(equal)
    real(real64), intent(in) :: a, b
    integer(int64) :: ia, ib
    ia = transfer(a, ia)
    ib = transfer(b, ib)
    equal = ia == ib
  end function same_bits

  logical function all_bits_identical(a, b) result(equal)
    real(real64), intent(in) :: a(:), b(:)
    integer :: k
    equal = size(a) == size(b)
    if (.not. equal) return
    do k = 1, size(a)
      if (.not. same_bits(a(k), b(k))) then
        equal = .false.
        return
      end if
    end do
  end function all_bits_identical

  logical function all_zero_bits(a) result(equal)
    real(real64), intent(in) :: a(:)
    integer :: k
    equal = .true.
    do k = 1, size(a)
      if (.not. same_bits(a(k), 0.0_real64)) then
        equal = .false.
        return
      end if
    end do
  end function all_zero_bits

  logical function physical_snapshot_identical(a, b) result(equal)
    class(transaction_state_t), intent(in) :: a, b
    integer :: k
    equal = .false.
    select type (pa => a)
    type is (fmr_b110_physical_state_t)
      select type (pb => b)
      type is (fmr_b110_physical_state_t)
        if (pa%active_nodes /= pb%active_nodes) return
        do k = 1, pa%active_nodes
          if (.not. same_bits(pa%pressure_head(k), pb%pressure_head(k))) return
          if (.not. same_bits(pa%water_content(k), pb%water_content(k))) return
        end do
        if (.not. same_bits(pa%ponding_depth, pb%ponding_depth)) return
        if (.not. same_bits(pa%groundwater_level, pb%groundwater_level)) return
        equal = .true.
      end select
    end select
  end function physical_snapshot_identical

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FMR28_COMPOSITION_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fmr28_reference_et_root_uptake_execution
