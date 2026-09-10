program test_fmr26_reference_et_ptra_root_input_binding
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_canonical_contracts, only: canonical_interval_t
  use mod_crop_root_uptake_input_contract
  use mod_reference_et_demand_process
  use mod_fmr_reference_et_demand_binding
  use mod_fmr_reference_et_ptra_root_input_binding
  implicit none

  integer :: failures

  failures = 0
  call test_authoritative_ptra_and_field_preservation(failures)
  call test_stale_ptra_is_ignored(failures)
  call test_upstream_rejection_fail_closed(failures)
  call test_invalid_geometry_fail_closed(failures)
  call test_nonemerged_semantics(failures)
  call test_inconsistent_et_result_fail_closed(failures)
  call test_stateless_a_b_a(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'FMR26_FAILURE_COUNT=', failures
    error stop 1
  end if

  write(*,'(A)') 'FMR26_FMR23_PTRA_AUTHORITY=PASS'
  write(*,'(A)') 'FMR26_NON_PTRA_FIELDS_PRESERVED=PASS'
  write(*,'(A)') 'FMR26_INCOMING_PTRA_IGNORED=PASS'
  write(*,'(A)') 'FMR26_UPSTREAM_REJECTION_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FMR26_INVALID_ROOT_GEOMETRY_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FMR26_NONEMERGED_SEMANTICS=PASS'
  write(*,'(A)') 'FMR26_ASSEMBLED_CONTRACT_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FMR26_STATELESS_A_B_A_IDENTITY=PASS'
  write(*,'(A)') 'FMR26_REFERENCE_ET_PTRA_ROOT_INPUT_BINDING_TEST PASS'

contains

  subroutine make_active_base(input, incoming_ptra)
    type(crop_root_uptake_input_t), intent(out) :: input
    real(real64), intent(in) :: incoming_ptra

    input = crop_root_uptake_input_t()
    input%crop_emerged = .true.
    input%potential_transpiration = incoming_ptra
    input%rooted_nodes = 2
    allocate(input%cumulative_root_fraction(3))
    input%cumulative_root_fraction = [0.0_real64, 0.4_real64, 1.0_real64]
  end subroutine make_active_base

  subroutine evaluate_et(reference_et, emerged, result, diagnostics)
    real(real64), intent(in) :: reference_et
    logical, intent(in) :: emerged
    type(reference_et_demand_result_t), intent(out) :: result
    type(fmr_reference_et_binding_diagnostics_t), intent(out) :: diagnostics

    type(canonical_interval_t) :: interval
    type(fmr_reference_et_forcing_span_t) :: forcing_span
    type(reference_et_demand_parameters_t) :: parameters
    type(reference_et_demand_canopy_view_t) :: canopy
    type(reference_et_demand_diagnostics_t) :: process_diagnostics

    interval%t0 = 11.125_real64
    interval%t1 = 11.375_real64
    forcing_span%t0 = 10.0_real64
    forcing_span%t1 = 12.0_real64
    forcing_span%reference_et_mm_per_day = reference_et
    parameters%pond_evaporation_factor = 1.2_real64
    canopy%crop_emerged = emerged
    canopy%vegetation_cover_fraction = 0.65_real64
    canopy%crop_factor = 1.1_real64
    canopy%co2_transpiration_factor = 0.9_real64

    call fmr_evaluate_reference_et_demand(interval, forcing_span, parameters, canopy, result, &
                                          process_diagnostics, diagnostics)
  end subroutine evaluate_et

  subroutine test_authoritative_ptra_and_field_preservation(failures)
    integer, intent(inout) :: failures
    type(crop_root_uptake_input_t) :: base, bound
    type(reference_et_demand_result_t) :: et_result
    type(fmr_reference_et_binding_diagnostics_t) :: et_diag
    type(fmr_ptra_root_input_binding_diagnostics_t) :: bind_diag

    call make_active_base(base, -123.0_real64)
    call evaluate_et(5.2_real64, .true., et_result, et_diag)
    call fmr_bind_reference_et_ptra_to_root_input(base, 4, et_result, et_diag, bound, bind_diag)

    call assert_true(bind_diag%status == FMR_PTRA_ROOT_INPUT_BINDING_OK, 'authority status', failures)
    call assert_true(bind_diag%upstream_result_accepted, 'upstream accepted', failures)
    call assert_true(bind_diag%incoming_ptra_ignored, 'incoming ptra ignored marker', failures)
    call assert_true(bind_diag%ptra_bound .and. bind_diag%result_produced, 'ptra produced', failures)
    call assert_same_real_bits(bound%potential_transpiration, et_result%potential_transpiration_cm_per_day, &
                               'authoritative ptra exact', failures)
    call assert_true(bound%crop_emerged .eqv. base%crop_emerged, 'crop emerged preserved', failures)
    call assert_true(bound%rooted_nodes == base%rooted_nodes, 'rooted nodes preserved', failures)
    call assert_true(allocated(bound%cumulative_root_fraction), 'root distribution allocated', failures)
    if (allocated(bound%cumulative_root_fraction)) then
      call assert_true(same_real_vector_bits(bound%cumulative_root_fraction, base%cumulative_root_fraction), &
                       'root distribution preserved', failures)
    end if
    call assert_same_real_bits(base%potential_transpiration, -123.0_real64, 'base not mutated', failures)
  end subroutine test_authoritative_ptra_and_field_preservation

  subroutine test_stale_ptra_is_ignored(failures)
    integer, intent(inout) :: failures
    type(crop_root_uptake_input_t) :: base, bound
    type(reference_et_demand_result_t) :: et_result
    type(fmr_reference_et_binding_diagnostics_t) :: et_diag
    type(fmr_ptra_root_input_binding_diagnostics_t) :: bind_diag

    call make_active_base(base, ieee_value(0.0_real64, ieee_quiet_nan))
    call evaluate_et(4.7_real64, .true., et_result, et_diag)
    call fmr_bind_reference_et_ptra_to_root_input(base, 4, et_result, et_diag, bound, bind_diag)

    call assert_true(bind_diag%status == FMR_PTRA_ROOT_INPUT_BINDING_OK, 'stale nan ignored status', failures)
    call assert_same_real_bits(bound%potential_transpiration, et_result%potential_transpiration_cm_per_day, &
                               'stale nan cannot influence ptra', failures)
  end subroutine test_stale_ptra_is_ignored

  subroutine test_upstream_rejection_fail_closed(failures)
    integer, intent(inout) :: failures
    type(crop_root_uptake_input_t) :: base, bound
    type(reference_et_demand_result_t) :: et_result
    type(fmr_reference_et_binding_diagnostics_t) :: et_diag
    type(fmr_ptra_root_input_binding_diagnostics_t) :: bind_diag

    call make_active_base(base, 0.0_real64)
    et_result%potential_transpiration_cm_per_day = 0.3_real64
    et_diag = fmr_reference_et_binding_diagnostics_t()
    et_diag%status = FMR_REFERENCE_ET_BINDING_INVALID_INTERVAL
    et_diag%result_produced = .false.

    call fmr_bind_reference_et_ptra_to_root_input(base, 4, et_result, et_diag, bound, bind_diag)
    call assert_true(bind_diag%status == FMR_PTRA_ROOT_INPUT_UPSTREAM_ET_REJECTED, 'upstream reject status', failures)
    call assert_true(is_default_root_input(bound), 'upstream reject empty output', failures)
    call assert_true(.not. bind_diag%ptra_bound .and. .not. bind_diag%result_produced, &
                     'upstream reject no publication', failures)
  end subroutine test_upstream_rejection_fail_closed

  subroutine test_invalid_geometry_fail_closed(failures)
    integer, intent(inout) :: failures
    type(crop_root_uptake_input_t) :: base, bound
    type(reference_et_demand_result_t) :: et_result
    type(fmr_reference_et_binding_diagnostics_t) :: et_diag
    type(fmr_ptra_root_input_binding_diagnostics_t) :: bind_diag

    call make_active_base(base, -1.0_real64)
    base%rooted_nodes = 5
    call evaluate_et(5.2_real64, .true., et_result, et_diag)
    call fmr_bind_reference_et_ptra_to_root_input(base, 4, et_result, et_diag, bound, bind_diag)

    call assert_true(bind_diag%status == FMR_PTRA_ROOT_INPUT_INVALID_ROOT_GEOMETRY, 'geometry reject status', failures)
    call assert_true(bind_diag%root_geometry_status == CROP_ROOT_INPUT_ROOTED_NODES_RANGE, &
                     'geometry contract status', failures)
    call assert_true(is_default_root_input(bound), 'geometry reject empty output', failures)
  end subroutine test_invalid_geometry_fail_closed

  subroutine test_nonemerged_semantics(failures)
    integer, intent(inout) :: failures
    type(crop_root_uptake_input_t) :: base, bound
    type(reference_et_demand_result_t) :: et_result
    type(fmr_reference_et_binding_diagnostics_t) :: et_diag
    type(fmr_ptra_root_input_binding_diagnostics_t) :: bind_diag

    base = crop_root_uptake_input_t()
    base%potential_transpiration = ieee_value(0.0_real64, ieee_quiet_nan)
    call evaluate_et(5.2_real64, .false., et_result, et_diag)
    call fmr_bind_reference_et_ptra_to_root_input(base, 4, et_result, et_diag, bound, bind_diag)

    call assert_true(bind_diag%status == FMR_PTRA_ROOT_INPUT_BINDING_OK, 'nonemerged status', failures)
    call assert_true(.not. bound%crop_emerged, 'nonemerged flag', failures)
    call assert_same_real_bits(bound%potential_transpiration, 0.0_real64, 'nonemerged ptra zero', failures)
    call assert_true(bound%rooted_nodes == 0 .and. .not. allocated(bound%cumulative_root_fraction), &
                     'nonemerged root geometry empty', failures)
  end subroutine test_nonemerged_semantics

  subroutine test_inconsistent_et_result_fail_closed(failures)
    integer, intent(inout) :: failures
    type(crop_root_uptake_input_t) :: base, bound
    type(reference_et_demand_result_t) :: et_result
    type(fmr_reference_et_binding_diagnostics_t) :: et_diag
    type(fmr_ptra_root_input_binding_diagnostics_t) :: bind_diag

    base = crop_root_uptake_input_t()
    et_result = reference_et_demand_result_t()
    et_result%potential_transpiration_cm_per_day = 0.25_real64
    et_diag = fmr_reference_et_binding_diagnostics_t()
    et_diag%status = FMR_REFERENCE_ET_BINDING_OK
    et_diag%result_produced = .true.

    call fmr_bind_reference_et_ptra_to_root_input(base, 4, et_result, et_diag, bound, bind_diag)
    call assert_true(bind_diag%status == FMR_PTRA_ROOT_INPUT_ASSEMBLED_INPUT_REJECTED, &
                     'assembled contract reject status', failures)
    call assert_true(bind_diag%assembled_input_status == CROP_ROOT_INPUT_NOT_CANONICAL, &
                     'assembled contract diagnostic', failures)
    call assert_true(is_default_root_input(bound), 'assembled reject empty output', failures)
  end subroutine test_inconsistent_et_result_fail_closed

  subroutine test_stateless_a_b_a(failures)
    integer, intent(inout) :: failures
    type(crop_root_uptake_input_t) :: base, a1, b, a2
    type(reference_et_demand_result_t) :: et_a, et_b
    type(fmr_reference_et_binding_diagnostics_t) :: diag_a, diag_b
    type(fmr_ptra_root_input_binding_diagnostics_t) :: bind_diag

    call make_active_base(base, 999.0_real64)
    call evaluate_et(3.8_real64, .true., et_a, diag_a)
    call evaluate_et(7.1_real64, .true., et_b, diag_b)

    call fmr_bind_reference_et_ptra_to_root_input(base, 4, et_a, diag_a, a1, bind_diag)
    call assert_true(bind_diag%status == FMR_PTRA_ROOT_INPUT_BINDING_OK, 'ABA A1 status', failures)
    call fmr_bind_reference_et_ptra_to_root_input(base, 4, et_b, diag_b, b, bind_diag)
    call assert_true(bind_diag%status == FMR_PTRA_ROOT_INPUT_BINDING_OK, 'ABA B status', failures)
    call fmr_bind_reference_et_ptra_to_root_input(base, 4, et_a, diag_a, a2, bind_diag)
    call assert_true(bind_diag%status == FMR_PTRA_ROOT_INPUT_BINDING_OK, 'ABA A2 status', failures)

    call assert_root_input_equal(a1, a2, 'ABA exact A replay', failures)
    call assert_true(real_bits(a1%potential_transpiration) /= real_bits(b%potential_transpiration), &
                     'ABA B differs', failures)
  end subroutine test_stateless_a_b_a

  logical function is_default_root_input(input)
    type(crop_root_uptake_input_t), intent(in) :: input
    is_default_root_input = (.not. input%crop_emerged) .and. &
                            real_bits(input%potential_transpiration) == real_bits(0.0_real64) .and. &
                            input%rooted_nodes == 0 .and. .not. allocated(input%cumulative_root_fraction)
  end function is_default_root_input

  subroutine assert_root_input_equal(a, b, label, failures)
    type(crop_root_uptake_input_t), intent(in) :: a, b
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    logical :: same

    same = (a%crop_emerged .eqv. b%crop_emerged) .and. a%rooted_nodes == b%rooted_nodes .and. &
           real_bits(a%potential_transpiration) == real_bits(b%potential_transpiration) .and. &
           (allocated(a%cumulative_root_fraction) .eqv. allocated(b%cumulative_root_fraction))
    if (same .and. allocated(a%cumulative_root_fraction)) then
      same = same_real_vector_bits(a%cumulative_root_fraction, b%cumulative_root_fraction)
    end if
    call assert_true(same, label, failures)
  end subroutine assert_root_input_equal

  logical function same_real_vector_bits(a, b)
    real(real64), intent(in) :: a(:), b(:)
    integer :: i

    same_real_vector_bits = .false.
    if (size(a) /= size(b)) return
    do i = 1, size(a)
      if (real_bits(a(i)) /= real_bits(b(i))) return
    end do
    same_real_vector_bits = .true.
  end function same_real_vector_bits

  subroutine assert_same_real_bits(a, b, label, failures)
    real(real64), intent(in) :: a, b
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    call assert_true(real_bits(a) == real_bits(b), label, failures)
  end subroutine assert_same_real_bits

  integer(int64) function real_bits(value)
    real(real64), intent(in) :: value
    real_bits = transfer(value, real_bits)
  end function real_bits

  subroutine assert_true(condition, label, failures)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    if (.not. condition) then
      failures = failures + 1
      write(*,'(A,A)') 'FAIL: ', trim(label)
    end if
  end subroutine assert_true

end program test_fmr26_reference_et_ptra_root_input_binding
