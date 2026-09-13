program test_fvq36_fmr23_reference_et_runtime_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_canonical_contracts, only: canonical_interval_t
  use mod_reference_et_demand_process
  use mod_fmr_reference_et_demand_binding
  implicit none

  integer :: failures, grid_cases

  failures = 0
  grid_cases = 0

  call independent_grid_oracle(failures, grid_cases)
  call exact_boundary_and_outside_oracle(failures)
  call invalid_time_geometry_oracle(failures)
  call inactive_crop_dependency_oracle(failures)
  call stateless_replay_oracle(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'FVQ36_FAILURE_COUNT=', failures
    error stop 1
  end if

  write(*,'(A,I0)') 'FVQ36_INDEPENDENT_GRID_CASES=', grid_cases
  write(*,'(A)') 'FVQ36_GENERIC_SIGNED_TIME_ORIGINS=PASS'
  write(*,'(A)') 'FVQ36_VARIABLE_FORCING_SPAN_LENGTHS=PASS'
  write(*,'(A)') 'FVQ36_INDEPENDENT_ET_RATE_ORACLE=PASS'
  write(*,'(A)') 'FVQ36_RATE_INVARIANT_TO_CONTAINED_INTERVAL_DURATION=PASS'
  write(*,'(A)') 'FVQ36_EXACT_FORCING_BOUNDARIES=PASS'
  write(*,'(A)') 'FVQ36_OUTSIDE_FORCING_FAILS_BEFORE_PROCESS=PASS'
  write(*,'(A)') 'FVQ36_INVALID_TIME_GEOMETRY_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FVQ36_NONEMERGED_DEPENDENCY_SEMANTICS=PASS'
  write(*,'(A)') 'FVQ36_STATELESS_A_B_A_IDENTITY=PASS'
  write(*,'(A)') 'FVQ36_FMR23_REFERENCE_ET_RUNTIME_ORACLE PASS'

contains

  subroutine independent_grid_oracle(failures, grid_cases)
    integer, intent(inout) :: failures, grid_cases
    real(real64), parameter :: et_values(4) = [0.0_real64, 1.3_real64, 5.2_real64, 9.7_real64]
    real(real64), parameter :: cover_values(4) = [0.0_real64, 0.2_real64, 0.65_real64, 1.0_real64]
    real(real64), parameter :: pond_values(3) = [0.0_real64, 1.0_real64, 1.4_real64]
    real(real64), parameter :: crop_values(2) = [0.7_real64, 1.1_real64]
    real(real64), parameter :: co2_values(2) = [0.85_real64, 1.0_real64]
    real(real64), parameter :: span_starts(3) = [-10.75_real64, 0.0_real64, 2700.125_real64]
    real(real64), parameter :: span_lengths(3) = [0.5_real64, 1.0_real64, 2.75_real64]
    real(real64), parameter :: left_fraction(4) = [0.0_real64, 0.1_real64, 0.2_real64, 0.9_real64]
    real(real64), parameter :: right_fraction(4) = [1.0_real64, 0.4_real64, 0.8_real64, 1.0_real64]
    integer :: ie, iv, ip, ic, ico2, is, il, iemerge, itime
    logical :: emerged
    type(canonical_interval_t) :: interval
    type(fmr_reference_et_forcing_span_t) :: span
    type(reference_et_demand_parameters_t) :: parameters
    type(reference_et_demand_canopy_view_t) :: canopy
    type(reference_et_demand_result_t) :: result, baseline_result
    type(reference_et_demand_diagnostics_t) :: process_diagnostics
    type(fmr_reference_et_binding_diagnostics_t) :: diagnostics
    real(real64) :: expected_peva, expected_epond, expected_ptra
    logical :: baseline_set

    do is = 1, size(span_starts)
      do il = 1, size(span_lengths)
        span%t0 = span_starts(is)
        span%t1 = span%t0 + span_lengths(il)
        do ie = 1, size(et_values)
          span%reference_et_mm_per_day = et_values(ie)
          do iv = 1, size(cover_values)
            do ip = 1, size(pond_values)
              parameters%pond_evaporation_factor = pond_values(ip)
              do iemerge = 0, 1
                emerged = iemerge == 1
                do ic = 1, size(crop_values)
                  do ico2 = 1, size(co2_values)
                    canopy%crop_emerged = emerged
                    canopy%vegetation_cover_fraction = cover_values(iv)
                    canopy%crop_factor = crop_values(ic)
                    canopy%co2_transpiration_factor = co2_values(ico2)

                    expected_peva = max(et_values(ie) * (1.0_real64 - cover_values(iv)) * 0.1_real64, 0.0_real64)
                    expected_epond = max(et_values(ie) * (1.0_real64 - cover_values(iv)) * pond_values(ip) * &
                                         0.1_real64, 0.0_real64)
                    if (emerged) then
                      expected_ptra = max(et_values(ie) * cover_values(iv) * crop_values(ic) * 0.1_real64, &
                                          0.0_real64) * co2_values(ico2)
                    else
                      expected_ptra = 0.0_real64
                    end if

                    baseline_set = .false.
                    do itime = 1, size(left_fraction)
                      interval%t0 = span%t0 + span_lengths(il) * left_fraction(itime)
                      interval%t1 = span%t0 + span_lengths(il) * right_fraction(itime)
                      call fmr_evaluate_reference_et_demand(interval, span, parameters, canopy, result, &
                                                            process_diagnostics, diagnostics)
                      grid_cases = grid_cases + 1
                      call assert_true(diagnostics%status == FMR_REFERENCE_ET_BINDING_OK, 'grid binding status', failures)
                      call assert_true(process_diagnostics%status == REF_ET_DEMAND_OK, 'grid process status', failures)
                      call assert_close(result%potential_soil_evaporation_cm_per_day, expected_peva, 'grid peva', failures)
                      call assert_close(result%potential_pond_evaporation_cm_per_day, expected_epond, 'grid epond', failures)
                      call assert_close(result%potential_transpiration_cm_per_day, expected_ptra, 'grid ptra', failures)
                      if (.not. baseline_set) then
                        baseline_result = result
                        baseline_set = .true.
                      else
                        call assert_same_result_bits(result, baseline_result, 'grid time rate invariance', failures)
                      end if
                    end do
                  end do
                end do
              end do
            end do
          end do
        end do
      end do
    end do
  end subroutine independent_grid_oracle

  subroutine exact_boundary_and_outside_oracle(failures)
    integer, intent(inout) :: failures
    type(canonical_interval_t) :: interval
    type(fmr_reference_et_forcing_span_t) :: span
    type(reference_et_demand_parameters_t) :: parameters
    type(reference_et_demand_canopy_view_t) :: canopy
    type(reference_et_demand_result_t) :: result
    type(reference_et_demand_diagnostics_t) :: process_diagnostics
    type(fmr_reference_et_binding_diagnostics_t) :: diagnostics

    span%t0 = 42.125_real64
    span%t1 = 43.625_real64
    span%reference_et_mm_per_day = 4.0_real64
    parameters%pond_evaporation_factor = 1.1_real64
    canopy%crop_emerged = .true.
    canopy%vegetation_cover_fraction = 0.5_real64
    canopy%crop_factor = 1.0_real64
    canopy%co2_transpiration_factor = 1.0_real64

    interval%t0 = span%t0
    interval%t1 = span%t1
    call fmr_evaluate_reference_et_demand(interval, span, parameters, canopy, result, process_diagnostics, diagnostics)
    call assert_true(diagnostics%status == FMR_REFERENCE_ET_BINDING_OK, 'exact boundary full span', failures)
    call assert_close(result%potential_transpiration_cm_per_day, 0.2_real64, 'exact boundary ptra', failures)

    interval%t0 = span%t0 - 0.125_real64
    interval%t1 = span%t0 + 0.125_real64
    call fmr_evaluate_reference_et_demand(interval, span, parameters, canopy, result, process_diagnostics, diagnostics)
    call assert_true(diagnostics%status == FMR_REFERENCE_ET_BINDING_FORCING_NOT_COVERING_INTERVAL, &
                     'outside left status', failures)
    call assert_true(.not. diagnostics%process_called, 'outside left process not called', failures)
    call assert_zero_result(result, 'outside left zero result', failures)

    interval%t0 = span%t1 - 0.125_real64
    interval%t1 = span%t1 + 0.125_real64
    call fmr_evaluate_reference_et_demand(interval, span, parameters, canopy, result, process_diagnostics, diagnostics)
    call assert_true(diagnostics%status == FMR_REFERENCE_ET_BINDING_FORCING_NOT_COVERING_INTERVAL, &
                     'outside right status', failures)
    call assert_true(.not. diagnostics%process_called, 'outside right process not called', failures)
    call assert_zero_result(result, 'outside right zero result', failures)
  end subroutine exact_boundary_and_outside_oracle

  subroutine invalid_time_geometry_oracle(failures)
    integer, intent(inout) :: failures
    type(canonical_interval_t) :: interval
    type(fmr_reference_et_forcing_span_t) :: span
    type(reference_et_demand_parameters_t) :: parameters
    type(reference_et_demand_canopy_view_t) :: canopy
    type(reference_et_demand_result_t) :: result
    type(reference_et_demand_diagnostics_t) :: process_diagnostics
    type(fmr_reference_et_binding_diagnostics_t) :: diagnostics

    span%t0 = 0.0_real64
    span%t1 = 1.0_real64
    span%reference_et_mm_per_day = 2.0_real64
    parameters%pond_evaporation_factor = 1.0_real64
    canopy%crop_emerged = .false.
    canopy%vegetation_cover_fraction = 0.0_real64

    interval%t0 = 0.5_real64
    interval%t1 = 0.5_real64
    call fmr_evaluate_reference_et_demand(interval, span, parameters, canopy, result, process_diagnostics, diagnostics)
    call assert_true(diagnostics%status == FMR_REFERENCE_ET_BINDING_INVALID_INTERVAL, 'zero interval', failures)
    call assert_true(.not. diagnostics%process_called, 'zero interval no process', failures)

    interval%t0 = ieee_value(0.0_real64, ieee_quiet_nan)
    interval%t1 = 0.5_real64
    call fmr_evaluate_reference_et_demand(interval, span, parameters, canopy, result, process_diagnostics, diagnostics)
    call assert_true(diagnostics%status == FMR_REFERENCE_ET_BINDING_INVALID_INTERVAL, 'NaN interval', failures)

    interval%t0 = 0.25_real64
    interval%t1 = 0.5_real64
    span%t1 = span%t0
    call fmr_evaluate_reference_et_demand(interval, span, parameters, canopy, result, process_diagnostics, diagnostics)
    call assert_true(diagnostics%status == FMR_REFERENCE_ET_BINDING_INVALID_FORCING_SPAN, 'zero span', failures)
    call assert_true(.not. diagnostics%process_called, 'zero span no process', failures)
  end subroutine invalid_time_geometry_oracle

  subroutine inactive_crop_dependency_oracle(failures)
    integer, intent(inout) :: failures
    type(canonical_interval_t) :: interval
    type(fmr_reference_et_forcing_span_t) :: span
    type(reference_et_demand_parameters_t) :: parameters
    type(reference_et_demand_canopy_view_t) :: canopy
    type(reference_et_demand_result_t) :: result
    type(reference_et_demand_diagnostics_t) :: process_diagnostics
    type(fmr_reference_et_binding_diagnostics_t) :: diagnostics

    interval%t0 = -4.5_real64
    interval%t1 = -4.25_real64
    span%t0 = -5.0_real64
    span%t1 = -4.0_real64
    span%reference_et_mm_per_day = 5.2_real64
    parameters%pond_evaporation_factor = 1.2_real64
    canopy%crop_emerged = .false.
    canopy%vegetation_cover_fraction = 0.3_real64
    canopy%crop_factor = ieee_value(0.0_real64, ieee_quiet_nan)
    canopy%co2_transpiration_factor = ieee_value(0.0_real64, ieee_quiet_nan)

    call fmr_evaluate_reference_et_demand(interval, span, parameters, canopy, result, process_diagnostics, diagnostics)
    call assert_true(diagnostics%status == FMR_REFERENCE_ET_BINDING_OK, 'inactive crop binding status', failures)
    call assert_true(.not. process_diagnostics%crop_specific_factors_consumed, 'inactive crop factors ignored', failures)
    call assert_close(result%potential_transpiration_cm_per_day, 0.0_real64, 'inactive ptra', failures)
    call assert_close(result%potential_soil_evaporation_cm_per_day, 0.364_real64, 'inactive peva', failures)
    call assert_close(result%potential_pond_evaporation_cm_per_day, 0.4368_real64, 'inactive epond', failures)
  end subroutine inactive_crop_dependency_oracle

  subroutine stateless_replay_oracle(failures)
    integer, intent(inout) :: failures
    type(canonical_interval_t) :: ia, ib
    type(fmr_reference_et_forcing_span_t) :: sa, sb
    type(reference_et_demand_parameters_t) :: pa, pb
    type(reference_et_demand_canopy_view_t) :: ca, cb
    type(reference_et_demand_result_t) :: ra1, rb, ra2
    type(reference_et_demand_diagnostics_t) :: process_diagnostics
    type(fmr_reference_et_binding_diagnostics_t) :: diagnostics

    ia%t0 = 100.125_real64
    ia%t1 = 100.375_real64
    sa%t0 = 100.0_real64
    sa%t1 = 101.0_real64
    sa%reference_et_mm_per_day = 5.2_real64
    pa%pond_evaporation_factor = 1.2_real64
    ca%crop_emerged = .true.
    ca%vegetation_cover_fraction = 0.65_real64
    ca%crop_factor = 1.1_real64
    ca%co2_transpiration_factor = 0.9_real64

    ib%t0 = -2.0_real64
    ib%t1 = -1.0_real64
    sb%t0 = -3.0_real64
    sb%t1 = 0.0_real64
    sb%reference_et_mm_per_day = 2.0_real64
    pb%pond_evaporation_factor = 0.5_real64
    cb%crop_emerged = .false.
    cb%vegetation_cover_fraction = 0.1_real64

    call fmr_evaluate_reference_et_demand(ia, sa, pa, ca, ra1, process_diagnostics, diagnostics)
    call fmr_evaluate_reference_et_demand(ib, sb, pb, cb, rb, process_diagnostics, diagnostics)
    call fmr_evaluate_reference_et_demand(ia, sa, pa, ca, ra2, process_diagnostics, diagnostics)
    call assert_same_result_bits(ra1, ra2, 'A-B-A', failures)
  end subroutine stateless_replay_oracle

  subroutine assert_zero_result(result, label, failures)
    type(reference_et_demand_result_t), intent(in) :: result
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    call assert_close(result%potential_transpiration_cm_per_day, 0.0_real64, trim(label)//' ptra', failures)
    call assert_close(result%potential_soil_evaporation_cm_per_day, 0.0_real64, trim(label)//' peva', failures)
    call assert_close(result%potential_pond_evaporation_cm_per_day, 0.0_real64, trim(label)//' epond', failures)
  end subroutine assert_zero_result

  subroutine assert_same_result_bits(a, b, label, failures)
    type(reference_et_demand_result_t), intent(in) :: a, b
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    call assert_true(same_bits(a%potential_transpiration_cm_per_day, b%potential_transpiration_cm_per_day), &
                     trim(label)//' ptra bits', failures)
    call assert_true(same_bits(a%potential_soil_evaporation_cm_per_day, b%potential_soil_evaporation_cm_per_day), &
                     trim(label)//' peva bits', failures)
    call assert_true(same_bits(a%potential_pond_evaporation_cm_per_day, b%potential_pond_evaporation_cm_per_day), &
                     trim(label)//' epond bits', failures)
  end subroutine assert_same_result_bits

  subroutine assert_true(condition, label, failures)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    if (.not. condition) then
      failures = failures + 1
      write(*,'(A,A)') 'FAIL ', trim(label)
    end if
  end subroutine assert_true

  subroutine assert_close(actual, expected, label, failures)
    real(real64), intent(in) :: actual, expected
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    real(real64) :: tolerance
    tolerance = 2.0e-13_real64 * max(1.0_real64, abs(expected))
    if (abs(actual - expected) > tolerance) then
      failures = failures + 1
      write(*,'(A,A,2(1X,ES24.16))') 'FAIL ', trim(label), actual, expected
    end if
  end subroutine assert_close

  logical function same_bits(a, b) result(equal)
    real(real64), intent(in) :: a, b
    equal = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_bits

end program test_fvq36_fmr23_reference_et_runtime_oracle
