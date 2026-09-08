program test_fwof13_fmr12_bridge
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t
  use mod_crop_root_uptake_input_assembly, only: crop_root_state_view_t, root_uptake_et_result_t, &
       crop_root_uptake_assembly_diagnostics_t, assemble_crop_root_uptake_input, CROP_ROOT_ASSEMBLY_OK
  use mod_root_water_uptake_process, only: root_water_uptake_parameters_t, root_water_uptake_flux_result_t, &
       root_water_uptake_diagnostics_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_new_b110_committed_state
  use mod_fmr_root_uptake_process_binding, only: fmr_root_uptake_crop_input_t, fmr_root_uptake_binding_diagnostics_t, &
       fmr_evaluate_committed_root_uptake, FMR_ROOT_UPTAKE_BINDING_OK
  use mod_fmr_crop_root_uptake_input_adapter, only: fmr_crop_root_uptake_adapter_diagnostics_t, &
       fmr_evaluate_shared_crop_root_uptake, FMR_CROP_ROOT_ADAPTER_OK
  implicit none

  type(root_water_uptake_parameters_t) :: parameters
  type(crop_root_state_view_t) :: snapshot, snapshot_before
  type(root_uptake_et_result_t) :: et_result, et_before
  type(crop_root_uptake_input_t) :: shared_input
  type(crop_root_uptake_assembly_diagnostics_t) :: assembly_diag
  type(fmr_root_uptake_crop_input_t) :: direct_input
  type(root_water_uptake_flux_result_t) :: assembled_flux, direct_flux
  type(root_water_uptake_diagnostics_t) :: assembled_process_diag, direct_process_diag
  type(fmr_root_uptake_binding_diagnostics_t) :: assembled_binding_diag, direct_binding_diag
  type(fmr_crop_root_uptake_adapter_diagnostics_t) :: adapter_diag
  type(fmr_b110_physical_state_t) :: physical
  type(kernel_committed_state_t) :: committed
  class(transaction_state_t), allocatable :: state_before, state_after
  integer(int64) :: revision_before
  logical :: ok

  call configure_parameters(parameters)
  call configure_physical_state(physical)
  call fmr_new_b110_committed_state(committed, 1313_int64, physical, 4200.25_real64, ok)
  call require(ok, 'committed init')

  snapshot%crop_emerged = .true.
  snapshot%rooted_nodes = 3
  allocate(snapshot%cumulative_root_fraction(4))
  snapshot%cumulative_root_fraction = [0.0_real64, 0.15_real64, 0.50_real64, 1.0_real64]
  et_result%potential_transpiration = 0.30_real64
  snapshot_before = snapshot
  et_before = et_result

  call assemble_crop_root_uptake_input(snapshot, et_result, parameters%active_nodes, shared_input, assembly_diag)
  call require(assembly_diag%status == CROP_ROOT_ASSEMBLY_OK .and. assembly_diag%assembled, 'assembly succeeds')

  direct_input%crop_emerged = snapshot%crop_emerged
  direct_input%potential_transpiration = et_result%potential_transpiration
  direct_input%rooted_nodes = snapshot%rooted_nodes
  allocate(direct_input%cumulative_root_fraction(size(snapshot%cumulative_root_fraction)))
  direct_input%cumulative_root_fraction = snapshot%cumulative_root_fraction

  revision_before = committed%current_revision()
  call committed%snapshot(state_before, ok)
  call require(ok, 'state snapshot before')

  call fmr_evaluate_committed_root_uptake(committed, parameters, direct_input, direct_flux, direct_process_diag, &
                                          direct_binding_diag)
  call require(direct_binding_diag%status == FMR_ROOT_UPTAKE_BINDING_OK, 'direct FMR10 succeeds')

  call fmr_evaluate_shared_crop_root_uptake(committed, parameters, shared_input, assembled_flux, assembled_process_diag, &
                                             assembled_binding_diag, adapter_diag)
  call require(adapter_diag%status == FMR_CROP_ROOT_ADAPTER_OK, 'FMR12 adapter succeeds')
  call require(assembled_binding_diag%status == FMR_ROOT_UPTAKE_BINDING_OK, 'FMR12 to FMR10 binding succeeds')
  call require(all_bits_identical(assembled_flux%root_extraction_sink, direct_flux%root_extraction_sink), &
       'assembled root sink equals direct FMR10')
  call require(same_bits(assembled_flux%actual_uptake_total, direct_flux%actual_uptake_total), &
       'assembled total equals direct FMR10')
  call require(process_diagnostics_identical(assembled_process_diag, direct_process_diag), &
       'assembled process diagnostics equal direct FMR10')
  call require(binding_diagnostics_identical(assembled_binding_diag, direct_binding_diag), &
       'assembled binding diagnostics equal direct FMR10')
  write(*,'(A)') 'FWOF13_FMR12_TO_FMR10_BITWISE_IDENTITY=PASS'

  call committed%snapshot(state_after, ok)
  call require(ok, 'state snapshot after')
  call require(committed%current_revision() == revision_before, 'committed revision unchanged')
  call require(physical_snapshot_identical(state_before, state_after), 'committed state unchanged')
  call require(root_views_identical(snapshot, snapshot_before), 'snapshot unchanged')
  call require(same_bits(et_result%potential_transpiration, et_before%potential_transpiration), 'ET result unchanged')
  write(*,'(A)') 'FWOF13_DOWNSTREAM_COMMITTED_SNAPSHOT_ET_READ_ONLY=PASS'

  write(*,'(A,ES25.16)') 'FWOF13_ACTUAL_UPTAKE_TOTAL=', assembled_flux%actual_uptake_total
  write(*,'(A)') 'FWOF13_FMR12_BRIDGE_TEST PASS'

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

  logical function root_views_identical(a, b) result(equal)
    type(crop_root_state_view_t), intent(in) :: a, b
    equal = .false.
    if (a%crop_emerged .neqv. b%crop_emerged) return
    if (a%rooted_nodes /= b%rooted_nodes) return
    if (allocated(a%cumulative_root_fraction) .neqv. allocated(b%cumulative_root_fraction)) return
    if (allocated(a%cumulative_root_fraction)) then
      if (.not. all_bits_identical(a%cumulative_root_fraction, b%cumulative_root_fraction)) return
    end if
    equal = .true.
  end function root_views_identical

  logical function process_diagnostics_identical(a, b) result(equal)
    type(root_water_uptake_diagnostics_t), intent(in) :: a, b
    equal = .false.
    if (a%status /= b%status) return
    if (a%evaluated .neqv. b%evaluated) return
    if (a%no_roots .neqv. b%no_roots) return
    if (a%negligible_transpiration .neqv. b%negligible_transpiration) return
    if (.not. same_bits(a%critical_pressure_head, b%critical_pressure_head)) return
    if (.not. same_bits(a%potential_uptake_total, b%potential_uptake_total)) return
    if (.not. same_bits(a%drought_reduction_total, b%drought_reduction_total)) return
    if (allocated(a%potential_root_sink) .neqv. allocated(b%potential_root_sink)) return
    if (allocated(a%potential_root_sink)) then
      if (.not. all_bits_identical(a%potential_root_sink, b%potential_root_sink)) return
      if (.not. all_bits_identical(a%drought_reduction, b%drought_reduction)) return
      if (.not. all_bits_identical(a%drought_reduction_factor, b%drought_reduction_factor)) return
    end if
    equal = .true.
  end function process_diagnostics_identical

  logical function binding_diagnostics_identical(a, b) result(equal)
    type(fmr_root_uptake_binding_diagnostics_t), intent(in) :: a, b
    equal = a%status == b%status .and. a%process_status == b%process_status .and. &
            (a%crop_emerged .eqv. b%crop_emerged) .and. &
            (a%inactive_crop_zero_route .eqv. b%inactive_crop_zero_route) .and. &
            (a%hydraulic_view_built .eqv. b%hydraulic_view_built) .and. &
            (a%process_called .eqv. b%process_called)
  end function binding_diagnostics_identical

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

  logical function same_bits(a, b) result(equal)
    real(real64), intent(in) :: a, b
    integer(int64) :: ia, ib
    ia = transfer(a, ia)
    ib = transfer(b, ib)
    equal = ia == ib
  end function same_bits

  logical function all_bits_identical(a, b) result(equal)
    real(real64), intent(in) :: a(:), b(:)
    integer :: i
    equal = size(a) == size(b)
    if (.not. equal) return
    do i = 1, size(a)
      if (.not. same_bits(a(i), b(i))) then
        equal = .false.
        return
      end if
    end do
  end function all_bits_identical

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FWOF13_BRIDGE_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fwof13_fmr12_bridge
