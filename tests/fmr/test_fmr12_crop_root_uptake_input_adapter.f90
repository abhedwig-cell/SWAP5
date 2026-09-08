program test_fmr12_crop_root_uptake_input_adapter
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t, CROP_ROOT_INPUT_NOT_CANONICAL
  use mod_root_water_uptake_process, only: root_water_uptake_parameters_t, root_water_uptake_flux_result_t, &
       root_water_uptake_diagnostics_t, ROOT_UPTAKE_OK
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_new_b110_committed_state
  use mod_fmr_root_uptake_process_binding, only: fmr_root_uptake_crop_input_t, fmr_root_uptake_binding_diagnostics_t, &
       fmr_evaluate_committed_root_uptake, FMR_ROOT_UPTAKE_BINDING_OK
  use mod_fmr_crop_root_uptake_input_adapter, only: fmr_crop_root_uptake_adapter_diagnostics_t, &
       fmr_adapt_crop_root_uptake_input, fmr_evaluate_shared_crop_root_uptake, FMR_CROP_ROOT_ADAPTER_OK, &
       FMR_CROP_ROOT_ADAPTER_INVALID_CROP_INPUT
  implicit none

  type(root_water_uptake_parameters_t) :: parameters
  type(crop_root_uptake_input_t) :: shared_a, shared_a_before, shared_b, shared_inactive, shared_zero, shared_invalid
  type(fmr_root_uptake_crop_input_t) :: runtime_a, runtime_zero
  type(fmr_crop_root_uptake_adapter_diagnostics_t) :: adapt_a, adapt_zero, diag_a1, diag_b, diag_a2, diag_inactive, diag_invalid
  type(root_water_uptake_flux_result_t) :: flux_a1, flux_b, flux_a2, flux_inactive, flux_invalid, direct_flux
  type(root_water_uptake_diagnostics_t) :: proc_a1, proc_b, proc_a2, proc_inactive, proc_invalid, direct_proc
  type(fmr_root_uptake_binding_diagnostics_t) :: bind_a1, bind_b, bind_a2, bind_inactive, bind_invalid, direct_bind
  type(fmr_b110_physical_state_t) :: physical
  type(kernel_committed_state_t) :: committed, unavailable
  class(transaction_state_t), allocatable :: snapshot_before, snapshot_after
  integer(int64) :: revision_before
  logical :: ok

  call configure_parameters(parameters)

  shared_inactive = crop_root_uptake_input_t()
  call fmr_evaluate_shared_crop_root_uptake(unavailable, parameters, shared_inactive, flux_inactive, proc_inactive, &
                                             bind_inactive, diag_inactive)
  call require(diag_inactive%status == FMR_CROP_ROOT_ADAPTER_OK, 'inactive adapter status')
  call require(diag_inactive%adapted .and. diag_inactive%binding_called, 'inactive adapted and binding called')
  call require(bind_inactive%status == FMR_ROOT_UPTAKE_BINDING_OK, 'inactive FMR10 status')
  call require(bind_inactive%inactive_crop_zero_route, 'inactive FMR10 zero route preserved')
  call require(.not. bind_inactive%hydraulic_view_built, 'inactive route does not build hydraulic view')
  call require(proc_inactive%status == ROOT_UPTAKE_OK .and. proc_inactive%no_roots, 'inactive process zero route')
  call require(allocated(flux_inactive%root_extraction_sink), 'inactive sink allocated by FPM05')
  call require(maxval(abs(flux_inactive%root_extraction_sink)) <= tiny(1.0_real64), 'inactive sink is zero')
  write(*,'(A)') 'FMR12_INACTIVE_SHARED_DTO_PRESERVES_FMR10_DEPENDENCY_FREE_ROUTE=PASS'

  shared_zero = crop_root_uptake_input_t()
  shared_zero%crop_emerged = .true.
  shared_zero%potential_transpiration = 0.0_real64
  shared_zero%rooted_nodes = 0
  call fmr_adapt_crop_root_uptake_input(shared_zero, parameters%active_nodes, runtime_zero, adapt_zero)
  call require(adapt_zero%status == FMR_CROP_ROOT_ADAPTER_OK .and. adapt_zero%adapted, 'zero-root maps')
  call require(runtime_zero%crop_emerged, 'zero-root crop emerged preserved')
  call require(runtime_zero%rooted_nodes == 0, 'zero-root node count preserved')
  call require(.not. allocated(runtime_zero%cumulative_root_fraction), 'zero-root distribution remains absent')
  write(*,'(A)') 'FMR12_ACTIVE_ZERO_ROOT_EXACT_MAPPING=PASS'

  call configure_physical_state(physical)
  call fmr_new_b110_committed_state(committed, 1212_int64, physical, 4100.25_real64, ok)
  call require(ok, 'committed init')
  revision_before = committed%current_revision()
  call committed%snapshot(snapshot_before, ok)
  call require(ok, 'snapshot before')

  call configure_shared_input(shared_a, 0.30_real64, [0.0_real64, 0.15_real64, 0.50_real64, 1.0_real64])
  shared_a_before = shared_a
  call fmr_adapt_crop_root_uptake_input(shared_a, parameters%active_nodes, runtime_a, adapt_a)
  call require(adapt_a%status == FMR_CROP_ROOT_ADAPTER_OK .and. adapt_a%adapted, 'active A maps')
  call require(runtime_matches_shared(runtime_a, shared_a), 'active A exact field mapping')
  write(*,'(A)') 'FMR12_ACTIVE_ROOTED_FIELD_FOR_FIELD_MAPPING=PASS'

  call fmr_evaluate_committed_root_uptake(committed, parameters, runtime_a, direct_flux, direct_proc, direct_bind)
  call require(direct_bind%status == FMR_ROOT_UPTAKE_BINDING_OK, 'direct FMR10 status')

  call fmr_evaluate_shared_crop_root_uptake(committed, parameters, shared_a, flux_a1, proc_a1, bind_a1, diag_a1)
  call require(diag_a1%status == FMR_CROP_ROOT_ADAPTER_OK, 'adapter A status')
  call require(diag_a1%binding_called, 'adapter A called FMR10')
  call require(bind_a1%status == FMR_ROOT_UPTAKE_BINDING_OK, 'adapter A FMR10 status')
  call require(all_bits_identical(flux_a1%root_extraction_sink, direct_flux%root_extraction_sink), 'A root sink equals direct FMR10')
  call require(same_bits(flux_a1%actual_uptake_total, direct_flux%actual_uptake_total), 'A total equals direct FMR10')
  call require(process_diagnostics_identical(proc_a1, direct_proc), 'A process diagnostics equal direct FMR10')
  call require(binding_diagnostics_identical(bind_a1, direct_bind), 'A binding diagnostics equal direct FMR10')
  write(*,'(A)') 'FMR12_WRAPPER_BITWISE_EQUIVALENT_TO_DIRECT_FMR10=PASS'

  call committed%snapshot(snapshot_after, ok)
  call require(ok, 'snapshot after')
  call require(committed%current_revision() == revision_before, 'committed revision unchanged')
  call require(physical_snapshot_identical(snapshot_before, snapshot_after), 'committed state unchanged')
  call require(shared_inputs_identical(shared_a, shared_a_before), 'shared crop DTO unchanged')
  write(*,'(A)') 'FMR12_COMMITTED_AND_CROP_INPUT_READ_ONLY=PASS'

  shared_invalid = crop_root_uptake_input_t()
  shared_invalid%crop_emerged = .false.
  shared_invalid%potential_transpiration = 0.10_real64
  call fmr_evaluate_shared_crop_root_uptake(unavailable, parameters, shared_invalid, flux_invalid, proc_invalid, &
                                             bind_invalid, diag_invalid)
  call require(diag_invalid%status == FMR_CROP_ROOT_ADAPTER_INVALID_CROP_INPUT, 'noncanonical input rejected')
  call require(diag_invalid%crop_contract_status == CROP_ROOT_INPUT_NOT_CANONICAL, 'crop validation status preserved')
  call require(.not. diag_invalid%adapted .and. .not. diag_invalid%binding_called, 'invalid input rejected before FMR10')
  call require(.not. allocated(flux_invalid%root_extraction_sink), 'invalid input creates no process flux')
  write(*,'(A)') 'FMR12_INVALID_SHARED_DTO_FAILS_BEFORE_FMR10=PASS'

  call configure_shared_input(shared_b, 0.42_real64, [0.0_real64, 0.25_real64, 0.70_real64, 1.0_real64])
  call fmr_evaluate_shared_crop_root_uptake(committed, parameters, shared_b, flux_b, proc_b, bind_b, diag_b)
  call require(diag_b%status == FMR_CROP_ROOT_ADAPTER_OK, 'B status')
  call require(.not. all_bits_identical(flux_a1%root_extraction_sink, flux_b%root_extraction_sink), 'B distinct from A')
  call fmr_evaluate_shared_crop_root_uptake(committed, parameters, shared_a, flux_a2, proc_a2, bind_a2, diag_a2)
  call require(diag_a2%status == FMR_CROP_ROOT_ADAPTER_OK, 'A2 status')
  call require(all_bits_identical(flux_a1%root_extraction_sink, flux_a2%root_extraction_sink), 'A/B/A root sink')
  call require(same_bits(flux_a1%actual_uptake_total, flux_a2%actual_uptake_total), 'A/B/A total')
  call require(process_diagnostics_identical(proc_a1, proc_a2), 'A/B/A process diagnostics')
  call require(binding_diagnostics_identical(bind_a1, bind_a2), 'A/B/A binding diagnostics')
  call require(committed%current_revision() == revision_before, 'A/B/A committed revision unchanged')
  write(*,'(A)') 'FMR12_A_B_A_DETERMINISM=PASS'

  write(*,'(A,ES25.16)') 'FMR12_A_ACTUAL_UPTAKE_TOTAL=', flux_a1%actual_uptake_total
  write(*,'(A)') 'FMR12_CROP_ROOT_UPTAKE_INPUT_ADAPTER_TEST PASS'

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

  subroutine configure_shared_input(input, ptra, distribution)
    type(crop_root_uptake_input_t), intent(out) :: input
    real(real64), intent(in) :: ptra
    real(real64), intent(in) :: distribution(4)
    input%crop_emerged = .true.
    input%potential_transpiration = ptra
    input%rooted_nodes = 3
    allocate(input%cumulative_root_fraction(4))
    input%cumulative_root_fraction = distribution
  end subroutine configure_shared_input

  logical function runtime_matches_shared(runtime_input, shared_input) result(equal)
    type(fmr_root_uptake_crop_input_t), intent(in) :: runtime_input
    type(crop_root_uptake_input_t), intent(in) :: shared_input
    equal = .false.
    if (runtime_input%crop_emerged .neqv. shared_input%crop_emerged) return
    if (.not. same_bits(runtime_input%potential_transpiration, shared_input%potential_transpiration)) return
    if (runtime_input%rooted_nodes /= shared_input%rooted_nodes) return
    if (allocated(runtime_input%cumulative_root_fraction) .neqv. allocated(shared_input%cumulative_root_fraction)) return
    if (allocated(shared_input%cumulative_root_fraction)) then
      if (.not. all_bits_identical(runtime_input%cumulative_root_fraction, shared_input%cumulative_root_fraction)) return
    end if
    equal = .true.
  end function runtime_matches_shared

  logical function shared_inputs_identical(a, b) result(equal)
    type(crop_root_uptake_input_t), intent(in) :: a, b
    equal = .false.
    if (a%crop_emerged .neqv. b%crop_emerged) return
    if (.not. same_bits(a%potential_transpiration, b%potential_transpiration)) return
    if (a%rooted_nodes /= b%rooted_nodes) return
    if (allocated(a%cumulative_root_fraction) .neqv. allocated(b%cumulative_root_fraction)) return
    if (allocated(a%cumulative_root_fraction)) then
      if (.not. all_bits_identical(a%cumulative_root_fraction, b%cumulative_root_fraction)) return
    end if
    equal = .true.
  end function shared_inputs_identical

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

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FMR12_ADAPTER_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fmr12_crop_root_uptake_input_adapter
