program test_fvq41_fmr26_reference_et_ptra_root_input_qualification
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_canonical_contracts, only: canonical_interval_t
  use mod_crop_root_uptake_input_contract
  use mod_reference_et_demand_process
  use mod_fmr_reference_et_demand_binding
  use mod_fmr_reference_et_ptra_root_input_binding
  implicit none

  real(real64), parameter :: etr_values(4) = [0.0_real64, 1.3_real64, 5.2_real64, 9.7_real64]
  real(real64), parameter :: cover_values(4) = [0.0_real64, 0.2_real64, 0.65_real64, 1.0_real64]
  real(real64), parameter :: crop_factor_values(3) = [0.0_real64, 0.75_real64, 1.4_real64]
  real(real64), parameter :: co2_values(3) = [0.0_real64, 0.9_real64, 1.2_real64]

  integer :: failures
  integer :: active_cases

  failures = 0
  active_cases = 0

  call qualify_active_grid(failures, active_cases)
  call qualify_nonemerged_route(failures)
  call qualify_fail_closed_routes(failures)

  if (active_cases /= 2304) then
    failures = failures + 1
    write(*,'(A,I0)') 'FAIL: active case count=', active_cases
  end if

  if (failures /= 0) then
    write(*,'(A,I0)') 'FVQ41_FAILURE_COUNT=', failures
    error stop 1
  end if

  write(*,'(A,I0)') 'FVQ41_ACTIVE_GRID_CASES=', active_cases
  write(*,'(A)') 'FVQ41_INDEPENDENT_FROZEN_FORMULA_ORACLE=PASS'
  write(*,'(A)') 'FVQ41_FMR23_RESULT_MATCHES_ORACLE=PASS'
  write(*,'(A)') 'FVQ41_FMR26_EXACT_PTRA_FORWARDING=PASS'
  write(*,'(A)') 'FVQ41_INCOMING_PTRA_NONAUTHORITY=PASS'
  write(*,'(A)') 'FVQ41_ROOT_GEOMETRY_EXACT_PRESERVATION=PASS'
  write(*,'(A)') 'FVQ41_NONEMERGED_ZERO_PTRA=PASS'
  write(*,'(A)') 'FVQ41_FAIL_CLOSED_MATRIX=PASS'
  write(*,'(A)') 'FVQ41_REFERENCE_ET_PTRA_ROOT_INPUT_QUALIFICATION PASS'

contains

  subroutine qualify_active_grid(failures, active_cases)
    integer, intent(inout) :: failures
    integer, intent(inout) :: active_cases

    integer :: ie, iv, ic, ico2, iptra, ig, it
    type(crop_root_uptake_input_t) :: base_input, bound_input
    type(reference_et_demand_result_t) :: et_result
    type(fmr_reference_et_binding_diagnostics_t) :: et_diag
    type(fmr_ptra_root_input_binding_diagnostics_t) :: bind_diag
    real(real64) :: expected_ptra
    integer(int64) :: incoming_bits

    do ie = 1, size(etr_values)
      do iv = 1, size(cover_values)
        do ic = 1, size(crop_factor_values)
          do ico2 = 1, size(co2_values)
            do iptra = 1, 4
              do ig = 1, 2
                do it = 1, 2
                  call make_active_root_input(base_input, ig, iptra)
                  incoming_bits = real_bits(base_input%potential_transpiration)

                  call evaluate_et_case(etr_values(ie), cover_values(iv), crop_factor_values(ic), co2_values(ico2), &
                                        it, .true., et_result, et_diag)
                  call assert_true(et_diag%status == FMR_REFERENCE_ET_BINDING_OK, &
                                   'active grid ET status', failures)
                  call assert_true(et_diag%result_produced, 'active grid ET produced', failures)

                  expected_ptra = max(etr_values(ie) * cover_values(iv) * crop_factor_values(ic) * 0.1_real64, &
                                      0.0_real64) * co2_values(ico2)
                  call assert_close(et_result%potential_transpiration_cm_per_day, expected_ptra, &
                                    'FMR23 versus independent frozen formula', failures)

                  call fmr_bind_reference_et_ptra_to_root_input(base_input, 5, et_result, et_diag, &
                                                                bound_input, bind_diag)
                  call assert_true(bind_diag%status == FMR_PTRA_ROOT_INPUT_BINDING_OK, &
                                   'active grid bind status', failures)
                  call assert_true(bind_diag%upstream_result_accepted .and. bind_diag%incoming_ptra_ignored, &
                                   'active grid ownership diagnostics', failures)
                  call assert_true(bind_diag%ptra_bound .and. bind_diag%result_produced, &
                                   'active grid publication diagnostics', failures)
                  call assert_true(real_bits(bound_input%potential_transpiration) == &
                                   real_bits(et_result%potential_transpiration_cm_per_day), &
                                   'exact FMR23 ptra forwarding', failures)
                  call assert_root_geometry_bits(base_input, bound_input, &
                                                 'root geometry preservation', failures)
                  call assert_true(real_bits(base_input%potential_transpiration) == incoming_bits, &
                                   'incoming ptra source not mutated', failures)

                  active_cases = active_cases + 1
                end do
              end do
            end do
          end do
        end do
      end do
    end do
  end subroutine qualify_active_grid

  subroutine make_active_root_input(input, geometry_case, incoming_case)
    type(crop_root_uptake_input_t), intent(out) :: input
    integer, intent(in) :: geometry_case
    integer, intent(in) :: incoming_case

    input = crop_root_uptake_input_t()
    input%crop_emerged = .true.

    select case (incoming_case)
    case (1)
      input%potential_transpiration = 77.25_real64
    case (2)
      input%potential_transpiration = -9.5_real64
    case (3)
      input%potential_transpiration = 0.0_real64
    case (4)
      input%potential_transpiration = ieee_value(0.0_real64, ieee_quiet_nan)
    case default
      error stop 'invalid incoming ptra case'
    end select

    select case (geometry_case)
    case (1)
      input%rooted_nodes = 1
      allocate(input%cumulative_root_fraction(2))
      input%cumulative_root_fraction = [0.0_real64, 1.0_real64]
    case (2)
      input%rooted_nodes = 3
      allocate(input%cumulative_root_fraction(4))
      input%cumulative_root_fraction = [0.0_real64, 0.2_real64, 0.7_real64, 1.0_real64]
    case default
      error stop 'invalid geometry case'
    end select
  end subroutine make_active_root_input

  subroutine evaluate_et_case(etr, cover, crop_factor, co2_factor, interval_case, emerged, result, diagnostics)
    real(real64), intent(in) :: etr, cover, crop_factor, co2_factor
    integer, intent(in) :: interval_case
    logical, intent(in) :: emerged
    type(reference_et_demand_result_t), intent(out) :: result
    type(fmr_reference_et_binding_diagnostics_t), intent(out) :: diagnostics

    type(canonical_interval_t) :: interval
    type(fmr_reference_et_forcing_span_t) :: forcing_span
    type(reference_et_demand_parameters_t) :: parameters
    type(reference_et_demand_canopy_view_t) :: canopy
    type(reference_et_demand_diagnostics_t) :: process_diagnostics

    forcing_span%t0 = 500.0_real64
    forcing_span%t1 = 501.0_real64
    forcing_span%reference_et_mm_per_day = etr

    select case (interval_case)
    case (1)
      interval%t0 = 500.125_real64
      interval%t1 = 500.375_real64
    case (2)
      interval%t0 = 500.625_real64
      interval%t1 = 500.875_real64
    case default
      error stop 'invalid interval case'
    end select

    parameters%pond_evaporation_factor = 1.15_real64
    canopy%crop_emerged = emerged
    canopy%vegetation_cover_fraction = cover
    canopy%crop_factor = crop_factor
    canopy%co2_transpiration_factor = co2_factor

    call fmr_evaluate_reference_et_demand(interval, forcing_span, parameters, canopy, result, &
                                          process_diagnostics, diagnostics)
  end subroutine evaluate_et_case

  subroutine qualify_nonemerged_route(failures)
    integer, intent(inout) :: failures

    type(crop_root_uptake_input_t) :: base_input, bound_input
    type(reference_et_demand_result_t) :: et_result
    type(fmr_reference_et_binding_diagnostics_t) :: et_diag
    type(fmr_ptra_root_input_binding_diagnostics_t) :: bind_diag

    base_input = crop_root_uptake_input_t()
    base_input%potential_transpiration = ieee_value(0.0_real64, ieee_quiet_nan)

    call evaluate_et_case(8.2_real64, 0.9_real64, 1.4_real64, 1.2_real64, 1, .false., et_result, et_diag)
    call assert_true(et_diag%status == FMR_REFERENCE_ET_BINDING_OK .and. et_diag%result_produced, &
                     'nonemerged ET accepted', failures)
    call assert_true(real_bits(et_result%potential_transpiration_cm_per_day) == real_bits(0.0_real64), &
                     'nonemerged ET ptra zero', failures)

    call fmr_bind_reference_et_ptra_to_root_input(base_input, 5, et_result, et_diag, bound_input, bind_diag)
    call assert_true(bind_diag%status == FMR_PTRA_ROOT_INPUT_BINDING_OK, 'nonemerged binding status', failures)
    call assert_true(.not. bound_input%crop_emerged, 'nonemerged crop flag', failures)
    call assert_true(real_bits(bound_input%potential_transpiration) == real_bits(0.0_real64), &
                     'nonemerged bound ptra zero', failures)
    call assert_true(bound_input%rooted_nodes == 0 .and. .not. allocated(bound_input%cumulative_root_fraction), &
                     'nonemerged empty root geometry', failures)
  end subroutine qualify_nonemerged_route

  subroutine qualify_fail_closed_routes(failures)
    integer, intent(inout) :: failures

    type(crop_root_uptake_input_t) :: base_input, bound_input
    type(reference_et_demand_result_t) :: et_result
    type(fmr_reference_et_binding_diagnostics_t) :: et_diag
    type(fmr_ptra_root_input_binding_diagnostics_t) :: bind_diag

    call make_active_root_input(base_input, 1, 3)
    et_result = reference_et_demand_result_t()
    et_result%potential_transpiration_cm_per_day = 0.25_real64
    et_diag = fmr_reference_et_binding_diagnostics_t()
    et_diag%status = FMR_REFERENCE_ET_BINDING_INVALID_INTERVAL
    et_diag%result_produced = .false.
    call fmr_bind_reference_et_ptra_to_root_input(base_input, 5, et_result, et_diag, bound_input, bind_diag)
    call assert_true(bind_diag%status == FMR_PTRA_ROOT_INPUT_UPSTREAM_ET_REJECTED, &
                     'rejected upstream status', failures)
    call assert_default_input(bound_input, 'rejected upstream empty output', failures)

    et_diag = fmr_reference_et_binding_diagnostics_t()
    et_diag%status = FMR_REFERENCE_ET_BINDING_OK
    et_diag%result_produced = .false.
    call fmr_bind_reference_et_ptra_to_root_input(base_input, 5, et_result, et_diag, bound_input, bind_diag)
    call assert_true(bind_diag%status == FMR_PTRA_ROOT_INPUT_UPSTREAM_ET_REJECTED, &
                     'missing upstream result status', failures)
    call assert_default_input(bound_input, 'missing upstream result empty output', failures)

    call evaluate_et_case(5.2_real64, 0.65_real64, 1.0_real64, 0.9_real64, 1, .true., et_result, et_diag)
    call fmr_bind_reference_et_ptra_to_root_input(base_input, 0, et_result, et_diag, bound_input, bind_diag)
    call assert_true(bind_diag%status == FMR_PTRA_ROOT_INPUT_INVALID_ROOT_GEOMETRY, &
                     'invalid active nodes status', failures)
    call assert_true(bind_diag%root_geometry_status == CROP_ROOT_INPUT_INVALID_ACTIVE_NODES, &
                     'invalid active nodes diagnostic', failures)
    call assert_default_input(bound_input, 'invalid active nodes empty output', failures)

    base_input = crop_root_uptake_input_t()
    base_input%crop_emerged = .true.
    base_input%rooted_nodes = 4
    allocate(base_input%cumulative_root_fraction(5))
    base_input%cumulative_root_fraction = [0.0_real64, 0.2_real64, 0.5_real64, 0.8_real64, 1.0_real64]
    call fmr_bind_reference_et_ptra_to_root_input(base_input, 3, et_result, et_diag, bound_input, bind_diag)
    call assert_true(bind_diag%status == FMR_PTRA_ROOT_INPUT_INVALID_ROOT_GEOMETRY, &
                     'rooted nodes out of range status', failures)
    call assert_true(bind_diag%root_geometry_status == CROP_ROOT_INPUT_ROOTED_NODES_RANGE, &
                     'rooted nodes out of range diagnostic', failures)
    call assert_default_input(bound_input, 'invalid root geometry empty output', failures)

    base_input = crop_root_uptake_input_t()
    et_result = reference_et_demand_result_t()
    et_result%potential_transpiration_cm_per_day = 0.2_real64
    et_diag = fmr_reference_et_binding_diagnostics_t()
    et_diag%status = FMR_REFERENCE_ET_BINDING_OK
    et_diag%result_produced = .true.
    call fmr_bind_reference_et_ptra_to_root_input(base_input, 5, et_result, et_diag, bound_input, bind_diag)
    call assert_true(bind_diag%status == FMR_PTRA_ROOT_INPUT_ASSEMBLED_INPUT_REJECTED, &
                     'forged nonemerged ptra status', failures)
    call assert_true(bind_diag%assembled_input_status == CROP_ROOT_INPUT_NOT_CANONICAL, &
                     'forged nonemerged ptra diagnostic', failures)
    call assert_default_input(bound_input, 'forged nonemerged ptra empty output', failures)

    call make_active_root_input(base_input, 1, 3)
    et_result%potential_transpiration_cm_per_day = ieee_value(0.0_real64, ieee_quiet_nan)
    call fmr_bind_reference_et_ptra_to_root_input(base_input, 5, et_result, et_diag, bound_input, bind_diag)
    call assert_true(bind_diag%status == FMR_PTRA_ROOT_INPUT_ASSEMBLED_INPUT_REJECTED, &
                     'nonfinite authoritative ptra status', failures)
    call assert_true(bind_diag%assembled_input_status == CROP_ROOT_INPUT_NONFINITE_PTRA, &
                     'nonfinite authoritative ptra diagnostic', failures)
    call assert_default_input(bound_input, 'nonfinite authoritative ptra empty output', failures)

    et_result%potential_transpiration_cm_per_day = -0.1_real64
    call fmr_bind_reference_et_ptra_to_root_input(base_input, 5, et_result, et_diag, bound_input, bind_diag)
    call assert_true(bind_diag%status == FMR_PTRA_ROOT_INPUT_ASSEMBLED_INPUT_REJECTED, &
                     'negative authoritative ptra status', failures)
    call assert_true(bind_diag%assembled_input_status == CROP_ROOT_INPUT_NEGATIVE_PTRA, &
                     'negative authoritative ptra diagnostic', failures)
    call assert_default_input(bound_input, 'negative authoritative ptra empty output', failures)
  end subroutine qualify_fail_closed_routes

  subroutine assert_root_geometry_bits(a, b, label, failures)
    type(crop_root_uptake_input_t), intent(in) :: a, b
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    logical :: same
    integer :: i

    same = (a%crop_emerged .eqv. b%crop_emerged) .and. a%rooted_nodes == b%rooted_nodes .and. &
           (allocated(a%cumulative_root_fraction) .eqv. allocated(b%cumulative_root_fraction))

    if (same .and. allocated(a%cumulative_root_fraction)) then
      same = size(a%cumulative_root_fraction) == size(b%cumulative_root_fraction)
      if (same) then
        do i = 1, size(a%cumulative_root_fraction)
          if (real_bits(a%cumulative_root_fraction(i)) /= real_bits(b%cumulative_root_fraction(i))) then
            same = .false.
            exit
          end if
        end do
      end if
    end if

    call assert_true(same, label, failures)
  end subroutine assert_root_geometry_bits

  subroutine assert_default_input(input, label, failures)
    type(crop_root_uptake_input_t), intent(in) :: input
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    logical :: is_default

    is_default = (.not. input%crop_emerged) .and. &
                 real_bits(input%potential_transpiration) == real_bits(0.0_real64) .and. &
                 input%rooted_nodes == 0 .and. .not. allocated(input%cumulative_root_fraction)
    call assert_true(is_default, label, failures)
  end subroutine assert_default_input

  subroutine assert_close(actual, expected, label, failures)
    real(real64), intent(in) :: actual, expected
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    real(real64) :: tolerance

    tolerance = 64.0_real64 * epsilon(1.0_real64) * max(1.0_real64, abs(expected))
    call assert_true(abs(actual - expected) <= tolerance, label, failures)
  end subroutine assert_close

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

end program test_fvq41_fmr26_reference_et_ptra_root_input_qualification
