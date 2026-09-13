program test_eb_i17_external_bottom_thermal_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_fmr_bottom_thermal_carrier, only: fmr_bottom_thermal_carrier_t, fmr_bottom_thermal_candidate_t
  use mod_fmr_bottom_external_thermal_binding, only: fmr_bottom_external_thermal_binding_bundle_t, &
       FMR_EXT_THERMAL_BINDING_OK, FMR_EXT_THERMAL_BINDING_DUPLICATE, &
       FMR_EXT_THERMAL_BINDING_NONFINITE
  use mod_liquid_water_sensible_enthalpy, only: liquid_water_sensible_enthalpy_parameters_t, &
       initialize_liquid_water_sensible_enthalpy_parameters, LWSE_OK
  use mod_fmr_bottom_sensible_energy, only: fmr_bottom_sensible_energy_result_t, &
       evaluate_fmr_bottom_sensible_energy, evaluate_fmr_bottom_sensible_energy_with_external, &
       FMR_BOTTOM_ENERGY_COMPLETE, FMR_BOTTOM_ENERGY_INCOMPLETE_EXTERNAL_DONOR, &
       FMR_BOTTOM_ENERGY_INVALID_EXTERNAL_BINDING
  implicit none

  call verify_external_binding_completes_total()
  call verify_missing_binding_remains_fail_closed()
  call verify_lineage_mismatch_rejected()
  call verify_duplicate_and_nonfinite_rejected_without_mutation()
  call verify_binding_on_local_sample_rejected()
  call verify_existing_i15_route_unchanged_for_local_candidate()
  write(*,'(A)') 'EB_I17_EXTERNAL_BOTTOM_THERMAL_BINDING_GATE PASS'

contains

  subroutine make_parameters(parameters)
    type(liquid_water_sensible_enthalpy_parameters_t), intent(out) :: parameters
    integer :: status

    call initialize_liquid_water_sensible_enthalpy_parameters(1000.0_real64, 4180.0_real64, &
         5.0_real64, parameters, status)
    call require(status == LWSE_OK .and. parameters%ready(), 'parameters ready')
  end subroutine make_parameters

  subroutine make_mixed_candidate(candidate)
    type(fmr_bottom_thermal_candidate_t), intent(out) :: candidate
    type(fmr_bottom_thermal_carrier_t) :: carrier
    logical :: ok

    call carrier%initialize(3, ok)
    call require(ok, 'mixed carrier initialize')
    call carrier%append_local(0.0_real64, 0.25_real64, 0.10_real64, 8.0_real64, 10.0_real64, ok)
    call require(ok, 'mixed local append')
    call carrier%append_external_incomplete(0.25_real64, 0.75_real64, -0.20_real64, ok)
    call require(ok, 'mixed external append')
    call carrier%append_zero(0.75_real64, 1.0_real64, ok)
    call require(ok, 'mixed zero append')
    call carrier%materialize_candidate(0.0_real64, 1.0_real64, candidate, ok)
    call require(ok .and. candidate%ready(), 'mixed candidate materialize')
  end subroutine make_mixed_candidate

  subroutine make_local_candidate(candidate)
    type(fmr_bottom_thermal_candidate_t), intent(out) :: candidate
    type(fmr_bottom_thermal_carrier_t) :: carrier
    logical :: ok

    call carrier%initialize(1, ok)
    call require(ok, 'local carrier initialize')
    call carrier%append_local(0.0_real64, 1.0_real64, 0.15_real64, 9.0_real64, 11.0_real64, ok)
    call require(ok, 'local append')
    call carrier%materialize_candidate(0.0_real64, 1.0_real64, candidate, ok)
    call require(ok, 'local candidate materialize')
  end subroutine make_local_candidate

  subroutine verify_external_binding_completes_total()
    type(fmr_bottom_thermal_candidate_t) :: candidate
    type(fmr_bottom_external_thermal_binding_bundle_t) :: bindings
    type(liquid_water_sensible_enthalpy_parameters_t) :: parameters
    type(fmr_bottom_sensible_energy_result_t) :: old_result, result
    integer(int64), parameter :: lineage = 9001_int64
    real(real64) :: total, expected
    logical :: ok, available
    integer :: status, n, nlocal, nzero, nincomplete

    call make_parameters(parameters)
    call make_mixed_candidate(candidate)
    call evaluate_fmr_bottom_sensible_energy(candidate, parameters, old_result)
    call require(old_result%status() == FMR_BOTTOM_ENERGY_INCOMPLETE_EXTERNAL_DONOR, &
         'legacy I15 route remains incomplete for external inflow')

    call bindings%initialize(lineage, 1, ok)
    call require(ok .and. bindings%ready(), 'binding bundle initialize')
    call bindings%append(2, 7.0_real64, 12345_int64, status)
    call require(status == FMR_EXT_THERMAL_BINDING_OK .and. bindings%binding_count() == 1, 'external binding append')

    call evaluate_fmr_bottom_sensible_energy_with_external(candidate, lineage, bindings, parameters, result)
    call require(result%status() == FMR_BOTTOM_ENERGY_COMPLETE .and. result%complete(), 'external-aware result complete')
    call result%total_energy(total, available)
    call require(available, 'external-aware total available')
    expected = 0.01_real64 * 1000.0_real64 * 4180.0_real64 * &
         (0.10_real64*(10.0_real64-5.0_real64) + (-0.20_real64)*(7.0_real64-5.0_real64))
    call require(close(total, expected, 1.0e-12_real64), 'sample-resolved external donor energy')
    call result%counts(n, nlocal, nzero, nincomplete)
    call require(n == 3 .and. nlocal == 1 .and. nzero == 1 .and. nincomplete == 0, 'completed counts exact')
    write(*,'(A)') 'EB_I17_EXTERNAL_SAMPLE_RESOLVED_TOTAL=PASS'
  end subroutine verify_external_binding_completes_total

  subroutine verify_missing_binding_remains_fail_closed()
    type(fmr_bottom_thermal_candidate_t) :: candidate
    type(fmr_bottom_external_thermal_binding_bundle_t) :: bindings
    type(liquid_water_sensible_enthalpy_parameters_t) :: parameters
    type(fmr_bottom_sensible_energy_result_t) :: result
    integer(int64), parameter :: lineage = 9002_int64
    real(real64) :: total
    logical :: ok, available

    call make_parameters(parameters)
    call make_mixed_candidate(candidate)
    call bindings%initialize(lineage, 0, ok)
    call require(ok .and. bindings%ready() .and. bindings%binding_count() == 0, 'empty bundle ready without allocation')
    call evaluate_fmr_bottom_sensible_energy_with_external(candidate, lineage, bindings, parameters, result)
    call require(result%status() == FMR_BOTTOM_ENERGY_INCOMPLETE_EXTERNAL_DONOR .and. .not. result%complete(), &
         'missing external binding remains incomplete')
    call result%total_energy(total, available)
    call require(.not. available .and. total == 0.0_real64, 'missing binding exposes no total')
    write(*,'(A)') 'EB_I17_MISSING_BINDING_FAIL_CLOSED=PASS'
  end subroutine verify_missing_binding_remains_fail_closed

  subroutine verify_lineage_mismatch_rejected()
    type(fmr_bottom_thermal_candidate_t) :: candidate
    type(fmr_bottom_external_thermal_binding_bundle_t) :: bindings
    type(liquid_water_sensible_enthalpy_parameters_t) :: parameters
    type(fmr_bottom_sensible_energy_result_t) :: result
    real(real64) :: total
    logical :: ok, available
    integer :: status

    call make_parameters(parameters)
    call make_mixed_candidate(candidate)
    call bindings%initialize(9101_int64, 1, ok)
    call require(ok, 'lineage bundle initialize')
    call bindings%append(2, 7.0_real64, status=status)
    call require(status == FMR_EXT_THERMAL_BINDING_OK, 'lineage binding append')
    call evaluate_fmr_bottom_sensible_energy_with_external(candidate, 9102_int64, bindings, parameters, result)
    call require(result%status() == FMR_BOTTOM_ENERGY_INVALID_EXTERNAL_BINDING .and. .not. result%complete(), &
         'foreign candidate lineage rejected')
    call result%total_energy(total, available)
    call require(.not. available, 'lineage mismatch exposes no total')
    write(*,'(A)') 'EB_I17_LINEAGE_MISMATCH_REJECTED=PASS'
  end subroutine verify_lineage_mismatch_rejected

  subroutine verify_duplicate_and_nonfinite_rejected_without_mutation()
    type(fmr_bottom_external_thermal_binding_bundle_t) :: bindings, nonfinite_bindings
    real(real64) :: nan_value
    logical :: ok
    integer :: status

    call bindings%initialize(9201_int64, 2, ok)
    call require(ok, 'duplicate bundle initialize')
    call bindings%append(2, 7.0_real64, status=status)
    call require(status == FMR_EXT_THERMAL_BINDING_OK .and. bindings%binding_count() == 1, 'first binding append')
    call bindings%append(2, 8.0_real64, status=status)
    call require(status == FMR_EXT_THERMAL_BINDING_DUPLICATE .and. bindings%binding_count() == 1, &
         'duplicate rejected without mutation')

    nan_value = ieee_value(0.0_real64, ieee_quiet_nan)
    call nonfinite_bindings%initialize(9202_int64, 1, ok)
    call require(ok, 'nonfinite bundle initialize')
    call nonfinite_bindings%append(1, nan_value, status=status)
    call require(status == FMR_EXT_THERMAL_BINDING_NONFINITE .and. nonfinite_bindings%binding_count() == 0, &
         'nonfinite donor rejected without mutation')
    write(*,'(A)') 'EB_I17_DUPLICATE_NONFINITE_REJECTED=PASS'
  end subroutine verify_duplicate_and_nonfinite_rejected_without_mutation

  subroutine verify_binding_on_local_sample_rejected()
    type(fmr_bottom_thermal_candidate_t) :: candidate
    type(fmr_bottom_external_thermal_binding_bundle_t) :: bindings
    type(liquid_water_sensible_enthalpy_parameters_t) :: parameters
    type(fmr_bottom_sensible_energy_result_t) :: result
    logical :: ok
    integer :: status

    call make_parameters(parameters)
    call make_mixed_candidate(candidate)
    call bindings%initialize(9301_int64, 2, ok)
    call require(ok, 'wrong-class bundle initialize')
    call bindings%append(1, 9.0_real64, status=status)
    call require(status == FMR_EXT_THERMAL_BINDING_OK, 'wrong-class binding structurally appendable')
    call bindings%append(2, 7.0_real64, status=status)
    call require(status == FMR_EXT_THERMAL_BINDING_OK, 'required external binding append')
    call evaluate_fmr_bottom_sensible_energy_with_external(candidate, 9301_int64, bindings, parameters, result)
    call require(result%status() == FMR_BOTTOM_ENERGY_INVALID_EXTERNAL_BINDING .and. .not. result%complete(), &
         'binding attached to local sample rejected by evaluator')
    write(*,'(A)') 'EB_I17_NONEXTERNAL_BINDING_REJECTED=PASS'
  end subroutine verify_binding_on_local_sample_rejected

  subroutine verify_existing_i15_route_unchanged_for_local_candidate()
    type(fmr_bottom_thermal_candidate_t) :: candidate
    type(fmr_bottom_external_thermal_binding_bundle_t) :: bindings
    type(liquid_water_sensible_enthalpy_parameters_t) :: parameters
    type(fmr_bottom_sensible_energy_result_t) :: old_result, external_aware_result
    real(real64) :: old_total, new_total
    logical :: ok, old_available, new_available

    call make_parameters(parameters)
    call make_local_candidate(candidate)
    call bindings%initialize(9401_int64, 0, ok)
    call require(ok, 'empty local bundle initialize')
    call evaluate_fmr_bottom_sensible_energy(candidate, parameters, old_result)
    call evaluate_fmr_bottom_sensible_energy_with_external(candidate, 9401_int64, bindings, parameters, external_aware_result)
    call old_result%total_energy(old_total, old_available)
    call external_aware_result%total_energy(new_total, new_available)
    call require(old_result%status() == FMR_BOTTOM_ENERGY_COMPLETE .and. external_aware_result%status() == FMR_BOTTOM_ENERGY_COMPLETE, &
         'both local routes complete')
    call require(old_available .and. new_available .and. same_bits(old_total, new_total), &
         'existing I15 local result bit-identical through external-aware route')
    write(*,'(A)') 'EB_I17_I15_LOCAL_ROUTE_PRESERVED=PASS'
  end subroutine verify_existing_i15_route_unchanged_for_local_candidate

  logical function close(a, b, tolerance) result(ok)
    real(real64), intent(in) :: a, b, tolerance
    ok = abs(a-b) <= tolerance * max(1.0_real64, abs(a), abs(b))
  end function close

  logical function same_bits(a, b) result(ok)
    real(real64), intent(in) :: a, b
    integer(int64) :: ia, ib
    ia = transfer(a, ia)
    ib = transfer(b, ib)
    ok = ia == ib
  end function same_bits

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'EB_I17_TEST_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_eb_i17_external_bottom_thermal_binding
