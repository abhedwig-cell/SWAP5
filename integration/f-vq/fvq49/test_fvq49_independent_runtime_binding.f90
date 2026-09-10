program test_fvq49_independent_runtime_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t, &
       drainage_node_transfer_t, drainage_distribution_diagnostics_t, &
       distribute_single_level_positive_divdra, DRAIN_DIST_OK
  use mod_fmr_divdra_runtime_binding, only: fmr_divdra_binding_diagnostics_t, &
       fmr_bind_single_level_positive_divdra, FMR_DIVDRA_BIND_OK, &
       FMR_DIVDRA_BIND_TARGET_ALREADY_BOUND, FMR_DIVDRA_BIND_PROCESS_REJECTED
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, &
       bind_b110_source_sink_provider
  implicit none

  integer, parameter :: node_counts(5) = [1, 2, 3, 5, 8]
  integer, parameter :: cases_per_size = 80
  integer :: i, j, failures, valid_cases, consumer_cases, repeat_cases
  integer :: zero_cases, process_reject_cases, overwrite_guard_cases
  real(real64) :: checksum

  failures = 0
  valid_cases = 0
  consumer_cases = 0
  repeat_cases = 0
  zero_cases = 0
  process_reject_cases = 0
  overwrite_guard_cases = 0
  checksum = 0.0_real64

  do i = 1, size(node_counts)
    do j = 1, cases_per_size
      call run_valid_case(node_counts(i), j, failures, valid_cases, &
           consumer_cases, repeat_cases, checksum)
    end do
    call run_zero_case(node_counts(i), failures, zero_cases)
    call run_failure_cases(node_counts(i), failures, process_reject_cases)
    call run_preallocated_guard(node_counts(i), failures, overwrite_guard_cases)
  end do

  call check(valid_cases == 400, 'independent valid case count', failures)
  call check(consumer_cases == 400, 'consumer composition case count', failures)
  call check(repeat_cases == 400, 'fresh-target repeat case count', failures)
  call check(zero_cases == 5, 'zero transfer case count', failures)
  call check(process_reject_cases == 20, 'process rejection case count', failures)
  call check(overwrite_guard_cases == 5, 'overwrite guard case count', failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'F-VQ49 FAILURES=', failures
    error stop 1
  end if

  write(*,'(A)') 'F-VQ49 PASS'
  write(*,'(A,I0)') 'VALID_RUNTIME_CASES=', valid_cases
  write(*,'(A,I0)') 'CONSUMER_COMPOSITION_CASES=', consumer_cases
  write(*,'(A,I0)') 'FRESH_TARGET_REPEAT_CASES=', repeat_cases
  write(*,'(A,I0)') 'ZERO_TRANSFER_CASES=', zero_cases
  write(*,'(A,I0)') 'PROCESS_REJECTION_CASES=', process_reject_cases
  write(*,'(A,I0)') 'PREALLOCATED_TARGET_GUARDS=', overwrite_guard_cases
  write(*,'(A,ES24.16)') 'INDEPENDENT_MATRIX_CHECKSUM=', checksum
  write(*,'(A)') 'ROW_COPY_IDENTITY=TRUE'
  write(*,'(A)') 'NO_ADDITIONAL_RUNTIME_MASS_DISCREPANCY=TRUE'
  write(*,'(A)') 'EXPLICIT_HYDRAULIC_VIEW_ONLY=TRUE'

contains

  subroutine run_valid_case(n, case_id, failures, valid_cases, &
       consumer_cases, repeat_cases, checksum)
    integer, intent(in) :: n, case_id
    integer, intent(inout) :: failures, valid_cases, consumer_cases, repeat_cases
    real(real64), intent(inout) :: checksum
    type(drainage_distribution_parameters_t) :: p
    type(process_hydraulic_view_t) :: view
    type(drainage_node_transfer_t) :: direct
    type(drainage_distribution_diagnostics_t) :: direct_diag
    type(fmr_divdra_binding_diagnostics_t) :: bind_diag, repeat_diag
    type(b110_source_sink_provider_t) :: provider
    real(real64), allocatable, target :: runtime_row(:,:), repeat_row(:,:)
    real(real64), allocatable, target :: irrigation(:), root_sink(:)
    real(real64), allocatable :: source(:), sink(:)
    real(real64) :: scalar, total_depth, fraction

    call make_parameters(n, case_id, p, total_depth)
    fraction = 0.125_real64 + 0.03125_real64 * &
         real(mod(3 * case_id + 2 * n, 20), real64)
    call make_view(n, -total_depth * fraction, case_id, view)
    scalar = 0.125_real64 * real(1 + mod(5 * case_id + n, 31), real64)

    call distribute_single_level_positive_divdra(p, view, scalar, direct, direct_diag)
    call check(direct_diag%status == DRAIN_DIST_OK, &
         'canonical process admits generated case', failures)
    if (direct_diag%status /= DRAIN_DIST_OK) return

    call fmr_bind_single_level_positive_divdra(p, view, scalar, runtime_row, bind_diag)
    call check(bind_diag%status == FMR_DIVDRA_BIND_OK, &
         'candidate binding admits generated case', failures)
    call check(bind_diag%published, 'candidate marks publication', failures)
    call check(allocated(runtime_row), 'candidate allocates publication target', failures)
    if (.not. allocated(runtime_row)) return

    call check(size(runtime_row, 1) == 1, 'single drainage level materialized', failures)
    call check(size(runtime_row, 2) == n, 'active-node shape preserved', failures)
    call check(allocated(direct%soil_to_drain_rate), &
         'canonical process produced node row', failures)
    if (.not. allocated(direct%soil_to_drain_rate)) return

    call check(all(runtime_row(1,:) == direct%soil_to_drain_rate), &
         'published row bit-identical to canonical process row', failures)
    call check(sum(runtime_row(1,:)) == sum(direct%soil_to_drain_rate), &
         'binding adds zero ordered-sum mass discrepancy', failures)
    call check(bind_diag%authoritative_scalar_transfer == scalar, &
         'authoritative scalar propagated exactly', failures)
    call check(bind_diag%process_status == direct_diag%status, &
         'process status propagated exactly', failures)
    call check(bind_diag%process%water_table_node == direct_diag%water_table_node, &
         'process diagnostic water-table node propagated', failures)
    valid_cases = valid_cases + 1

    allocate(irrigation(n), root_sink(n), source(n), sink(n))
    irrigation = 0.0_real64
    root_sink = 0.0_real64
    call bind_b110_source_sink_provider(provider, runtime_row, irrigation, root_sink)
    call provider%evaluate(view%pressure_head, view%water_content, source, sink)
    call check(all(source == 0.0_real64), 'consumer source remains zero', failures)
    call check(all(sink == runtime_row(1,:)), &
         'consumer receives published drainage row unchanged', failures)
    consumer_cases = consumer_cases + 1

    call fmr_bind_single_level_positive_divdra(p, view, scalar, repeat_row, repeat_diag)
    call check(repeat_diag%status == FMR_DIVDRA_BIND_OK, &
         'fresh-target repeat admitted', failures)
    call check(allocated(repeat_row), 'fresh-target repeat published', failures)
    if (allocated(repeat_row)) then
      call check(all(repeat_row == runtime_row), &
           'fresh-target repeat bit-identical', failures)
      repeat_cases = repeat_cases + 1
    end if

    checksum = checksum + sum(runtime_row(1,:)) * &
         real(1 + mod(case_id + 7 * n, 13), real64)
  end subroutine run_valid_case

  subroutine run_zero_case(n, failures, zero_cases)
    integer, intent(in) :: n
    integer, intent(inout) :: failures, zero_cases
    type(drainage_distribution_parameters_t) :: p
    type(process_hydraulic_view_t) :: view
    type(drainage_node_transfer_t) :: direct
    type(drainage_distribution_diagnostics_t) :: direct_diag
    type(fmr_divdra_binding_diagnostics_t) :: bind_diag
    real(real64), allocatable :: target(:,:)
    real(real64) :: total_depth

    call make_parameters(n, 101 + n, p, total_depth)
    call make_view(n, -0.375_real64 * total_depth, 101 + n, view)
    call distribute_single_level_positive_divdra(p, view, 0.0_real64, direct, direct_diag)
    call check(direct_diag%status == DRAIN_DIST_OK, 'zero direct status', failures)
    call fmr_bind_single_level_positive_divdra(p, view, 0.0_real64, target, bind_diag)
    call check(bind_diag%status == FMR_DIVDRA_BIND_OK, 'zero binding status', failures)
    call check(allocated(target), 'zero target published', failures)
    if (allocated(target)) then
      call check(size(target,1) == 1 .and. size(target,2) == n, &
           'zero target shape', failures)
      call check(all(target == 0.0_real64), 'zero target values', failures)
      zero_cases = zero_cases + 1
    end if
  end subroutine run_zero_case

  subroutine run_failure_cases(n, failures, process_reject_cases)
    integer, intent(in) :: n
    integer, intent(inout) :: failures, process_reject_cases
    type(drainage_distribution_parameters_t) :: p, invalid_p
    type(process_hydraulic_view_t) :: view, invalid_view
    real(real64) :: total_depth

    call make_parameters(n, 211 + n, p, total_depth)
    call make_view(n, -0.25_real64 * total_depth, 211 + n, view)

    invalid_p = p
    invalid_p%drain_spacing = 0.0_real64
    call check_process_rejection(invalid_p, view, 0.5_real64, &
         failures, process_reject_cases)

    invalid_view = view
    invalid_view%groundwater_level = -total_depth
    call check_process_rejection(p, invalid_view, 0.5_real64, &
         failures, process_reject_cases)

    call check_process_rejection(p, view, -0.5_real64, &
         failures, process_reject_cases)
    call check_process_rejection(p, view, 1.0e-10_real64, &
         failures, process_reject_cases)
  end subroutine run_failure_cases

  subroutine check_process_rejection(p, view, scalar, failures, process_reject_cases)
    type(drainage_distribution_parameters_t), intent(in) :: p
    type(process_hydraulic_view_t), intent(in) :: view
    real(real64), intent(in) :: scalar
    integer, intent(inout) :: failures, process_reject_cases
    type(drainage_node_transfer_t) :: direct
    type(drainage_distribution_diagnostics_t) :: direct_diag
    type(fmr_divdra_binding_diagnostics_t) :: bind_diag
    real(real64), allocatable :: target(:,:)

    call distribute_single_level_positive_divdra(p, view, scalar, direct, direct_diag)
    call check(direct_diag%status /= DRAIN_DIST_OK, &
         'canonical process rejects failure fixture', failures)
    call fmr_bind_single_level_positive_divdra(p, view, scalar, target, bind_diag)
    call check(bind_diag%status == FMR_DIVDRA_BIND_PROCESS_REJECTED, &
         'candidate reports process rejection', failures)
    call check(bind_diag%process_status == direct_diag%status, &
         'candidate propagates exact non-OK process status', failures)
    call check(.not. bind_diag%published, 'rejected case not published', failures)
    call check(.not. allocated(target), 'rejected case leaves target unallocated', failures)
    if (direct_diag%status /= DRAIN_DIST_OK .and. &
        bind_diag%status == FMR_DIVDRA_BIND_PROCESS_REJECTED .and. &
        bind_diag%process_status == direct_diag%status .and. &
        .not. allocated(target)) process_reject_cases = process_reject_cases + 1
  end subroutine check_process_rejection

  subroutine run_preallocated_guard(n, failures, overwrite_guard_cases)
    integer, intent(in) :: n
    integer, intent(inout) :: failures, overwrite_guard_cases
    type(drainage_distribution_parameters_t) :: p
    type(process_hydraulic_view_t) :: view
    type(fmr_divdra_binding_diagnostics_t) :: diag
    real(real64), allocatable :: target(:,:)
    real(real64) :: total_depth, sentinel

    sentinel = -9876.5_real64
    call make_parameters(n, 307 + n, p, total_depth)
    call make_view(n, -0.5_real64 * total_depth, 307 + n, view)
    allocate(target(2,n))
    target = sentinel
    call fmr_bind_single_level_positive_divdra(p, view, 0.75_real64, target, diag)
    call check(diag%status == FMR_DIVDRA_BIND_TARGET_ALREADY_BOUND, &
         'preallocated target rejected', failures)
    call check(.not. diag%process_evaluated, &
         'preallocated target prevents process evaluation', failures)
    call check(.not. diag%published, 'preallocated target not published', failures)
    call check(size(target,1) == 2 .and. size(target,2) == n, &
         'preallocated target shape unchanged', failures)
    call check(all(target == sentinel), 'preallocated target bytes unchanged', failures)
    if (diag%status == FMR_DIVDRA_BIND_TARGET_ALREADY_BOUND .and. &
        all(target == sentinel)) overwrite_guard_cases = overwrite_guard_cases + 1
  end subroutine run_preallocated_guard

  subroutine make_parameters(n, case_id, p, total_depth)
    integer, intent(in) :: n, case_id
    type(drainage_distribution_parameters_t), intent(out) :: p
    real(real64), intent(out) :: total_depth
    integer :: k

    p%active_nodes = n
    allocate(p%dz(n), p%zbotcp(n), p%saturated_conductivity(n), &
         p%horizontal_anisotropy_factor(n))
    total_depth = 0.0_real64
    do k = 1, n
      p%dz(k) = 0.5_real64 * real(5 + mod(case_id + 3 * k, 12), real64)
      total_depth = total_depth + p%dz(k)
      p%zbotcp(k) = -total_depth
      p%saturated_conductivity(k) = 0.25_real64 * &
           real(1 + mod(2 * case_id + 5 * k, 24), real64)
      p%horizontal_anisotropy_factor(k) = 0.25_real64 * &
           real(1 + mod(7 * case_id + 3 * k, 16), real64)
    end do
    p%drain_spacing = 2.0_real64 * real(8 + mod(case_id + n, 45), real64)
  end subroutine make_parameters

  subroutine make_view(n, groundwater_level, case_id, view)
    integer, intent(in) :: n, case_id
    real(real64), intent(in) :: groundwater_level
    type(process_hydraulic_view_t), intent(out) :: view
    integer :: k

    view%active_nodes = n
    allocate(view%pressure_head(n), view%water_content(n))
    do k = 1, n
      view%pressure_head(k) = -real(2 * case_id + 3 * k, real64)
      view%water_content(k) = 0.125_real64 + 0.0078125_real64 * &
           real(mod(case_id + k, 20), real64)
    end do
    view%groundwater_level = groundwater_level
  end subroutine make_view

  subroutine check(condition, label, failures)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures

    if (.not. condition) then
      failures = failures + 1
      write(*,'(A,A)') 'CHECK_FAIL: ', trim(label)
    end if
  end subroutine check

end program test_fvq49_independent_runtime_binding
