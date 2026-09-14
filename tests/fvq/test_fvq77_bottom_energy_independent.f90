program test_fvq77_bottom_energy_independent
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_liquid_water_sensible_enthalpy, only: liquid_water_sensible_enthalpy_parameters_t, &
       initialize_liquid_water_sensible_enthalpy_parameters, LWSE_OK
  use mod_fmr_bottom_thermal_carrier, only: fmr_bottom_thermal_carrier_t, fmr_bottom_thermal_candidate_t
  use mod_fmr_bottom_external_thermal_binding, only: fmr_bottom_external_thermal_binding_bundle_t, &
       FMR_EXT_THERMAL_BINDING_OK
  use mod_fmr_bottom_sensible_energy, only: fmr_bottom_sensible_energy_result_t, &
       evaluate_fmr_bottom_sensible_energy, evaluate_fmr_bottom_sensible_energy_with_external, &
       FMR_BOTTOM_ENERGY_COMPLETE, FMR_BOTTOM_ENERGY_INCOMPLETE_EXTERNAL_DONOR, &
       FMR_BOTTOM_ENERGY_INVALID_EXTERNAL_BINDING
  use mod_fmr_bottom_external_thermal_provider, only: fmr_external_bottom_thermal_request_t, &
       fmr_external_bottom_thermal_response_t, initialize_fmr_external_bottom_thermal_request, &
       FMR_EXT_THERMAL_RESPONSE_COMPLETE, FMR_EXT_THERMAL_RESPONSE_UNAVAILABLE
  implicit none

  type(liquid_water_sensible_enthalpy_parameters_t) :: properties
  type(fmr_bottom_thermal_carrier_t) :: carrier, checkpoint
  type(fmr_bottom_thermal_candidate_t) :: candidate
  type(fmr_bottom_external_thermal_binding_bundle_t) :: bindings, empty_bindings, extra_bindings
  type(fmr_bottom_sensible_energy_result_t) :: result
  type(fmr_external_bottom_thermal_request_t) :: request, changed_request
  type(fmr_external_bottom_thermal_response_t) :: response
  real(real64) :: energy, local_energy, expected_local, expected_total, donor_temperature
  integer(int64) :: token
  integer :: status, n, nlocal, nzero, nexternal
  logical :: ok, available

  call initialize_liquid_water_sensible_enthalpy_parameters(1000.0_real64, 4180.0_real64, 5.0_real64, properties, status)
  call require(status == LWSE_OK .and. properties%ready(), 'enthalpy properties')

  call carrier%initialize(4, ok)
  call require(ok, 'carrier initialize')
  call carrier%append_local(10.0_real64, 20.0_real64, 0.2_real64, 9.0_real64, 11.0_real64, ok)
  call require(ok, 'local sample')
  call carrier%append_external_incomplete(20.0_real64, 30.0_real64, -0.1_real64, ok)
  call require(ok, 'external sample')
  call carrier%append_zero(30.0_real64, 40.0_real64, ok)
  call require(ok, 'zero sample')
  call carrier%materialize_candidate(10.0_real64, 40.0_real64, candidate, ok)
  call require(ok .and. candidate%ready() .and. candidate%sample_count() == 3, 'candidate materialization')

  call evaluate_fmr_bottom_sensible_energy(candidate, properties, result)
  call require(result%status() == FMR_BOTTOM_ENERGY_INCOMPLETE_EXTERNAL_DONOR, 'missing external donor status')
  call require(.not. result%complete(), 'missing external donor incomplete')
  call result%total_energy(energy, available)
  call require(.not. available .and. energy == 0.0_real64, 'missing donor not encoded as available zero')
  call result%local_outward_subtotal(local_energy, available)
  expected_local = 0.01_real64 * 1000.0_real64 * 4180.0_real64 * 0.2_real64 * (11.0_real64 - 5.0_real64)
  call require(available .and. close_value(local_energy, expected_local), 'local donor energy identity')
  call result%counts(n, nlocal, nzero, nexternal)
  call require(n == 3 .and. nlocal == 1 .and. nzero == 1 .and. nexternal == 1, 'candidate donor counts')
  write(*,'(A)') 'FVQ77_MISSING_EXTERNAL_DONOR_FAIL_CLOSED=PASS'

  call bindings%initialize(7001_int64, 1, ok)
  call require(ok, 'binding bundle initialize')
  call bindings%append(2, 7.5_real64, 9001_int64, status)
  call require(status == FMR_EXT_THERMAL_BINDING_OK, 'external binding append')
  call evaluate_fmr_bottom_sensible_energy_with_external(candidate, 7001_int64, bindings, properties, result)
  call require(result%status() == FMR_BOTTOM_ENERGY_COMPLETE .and. result%complete(), 'resolved energy complete')
  call result%total_energy(energy, available)
  expected_total = expected_local + 0.01_real64 * 1000.0_real64 * 4180.0_real64 * (-0.1_real64) * &
       (7.5_real64 - 5.0_real64)
  call require(available .and. close_value(energy, expected_total), 'resolved energy identity')
  call require(close_value(expected_total, 39710.0_real64), 'independent expected energy')
  write(*,'(A,ES24.16)') 'FVQ77_RESOLVED_TOTAL_ENERGY_J_M2=', energy
  write(*,'(A)') 'FVQ77_RESOLVED_EXTERNAL_DONOR=PASS'

  call evaluate_fmr_bottom_sensible_energy_with_external(candidate, 7002_int64, bindings, properties, result)
  call require(result%status() == FMR_BOTTOM_ENERGY_INVALID_EXTERNAL_BINDING .and. .not. result%complete(), &
       'lineage mismatch fails closed')
  call result%total_energy(energy, available)
  call require(.not. available, 'lineage mismatch no total')
  write(*,'(A)') 'FVQ77_LINEAGE_MISMATCH_FAIL_CLOSED=PASS'

  call empty_bindings%initialize(7001_int64, 0, ok)
  call require(ok .and. empty_bindings%ready(), 'empty bundle initialize')
  call evaluate_fmr_bottom_sensible_energy_with_external(candidate, 7001_int64, empty_bindings, properties, result)
  call require(result%status() == FMR_BOTTOM_ENERGY_INCOMPLETE_EXTERNAL_DONOR .and. .not. result%complete(), &
       'unavailable binding remains incomplete')
  call result%total_energy(energy, available)
  call require(.not. available, 'unavailable binding no total')
  write(*,'(A)') 'FVQ77_UNAVAILABLE_BINDING_NO_ZERO_FALLBACK=PASS'

  call extra_bindings%initialize(7001_int64, 1, ok)
  call require(ok, 'extra bundle initialize')
  call extra_bindings%append(1, 6.0_real64, 9002_int64, status)
  call require(status == FMR_EXT_THERMAL_BINDING_OK, 'extra local binding append')
  call evaluate_fmr_bottom_sensible_energy_with_external(candidate, 7001_int64, extra_bindings, properties, result)
  call require(result%status() == FMR_BOTTOM_ENERGY_INVALID_EXTERNAL_BINDING .and. .not. result%complete(), &
       'cross-class binding fails closed')
  write(*,'(A)') 'FVQ77_CROSS_CLASS_BINDING_FAIL_CLOSED=PASS'

  call initialize_fmr_external_bottom_thermal_request(42_int64, 2, 20.0_real64, 30.0_real64, -0.1_real64, request, ok)
  call require(ok .and. request%ready(), 'provider request')
  call response%set_complete(request, 7.5_real64, 12345_int64, ok)
  call require(ok .and. response%ready(), 'provider complete response')
  call require(response%identity_matches(request), 'provider exact request identity')
  call require(response%disposition() == FMR_EXT_THERMAL_RESPONSE_COMPLETE, 'provider complete disposition')
  call response%donor_temperature(donor_temperature, available)
  call require(available .and. donor_temperature == 7.5_real64, 'provider donor temperature')
  token = response%source_provenance_token()
  call require(token == 12345_int64, 'provider provenance token')

  call initialize_fmr_external_bottom_thermal_request(42_int64, 2, 20.0_real64, 30.0_real64, -0.11_real64, changed_request, ok)
  call require(ok .and. .not. response%identity_matches(changed_request), 'provider exchange identity mismatch')
  call response%set_unavailable(request, 12346_int64, ok)
  call require(ok .and. response%ready(), 'provider unavailable response')
  call require(response%disposition() == FMR_EXT_THERMAL_RESPONSE_UNAVAILABLE, 'provider unavailable disposition')
  call response%donor_temperature(donor_temperature, available)
  call require(.not. available, 'unavailable response has no donor temperature')
  write(*,'(A)') 'FVQ77_PROVIDER_IDENTITY_AND_UNAVAILABLE=PASS'

  call carrier%clear()
  call carrier%initialize(3, ok)
  call require(ok, 'rollback carrier initialize')
  call carrier%append_local(0.0_real64, 1.0_real64, 0.05_real64, 8.0_real64, 9.0_real64, ok)
  call require(ok, 'rollback committed sample')
  call carrier%copy_to(checkpoint)
  call carrier%append_zero(1.0_real64, 2.0_real64, ok)
  call require(ok .and. carrier%sample_count() == 2, 'trial carrier mutation')
  call carrier%restore_from(checkpoint)
  call require(carrier%sample_count() == 1, 'carrier rollback count')
  call carrier%materialize_candidate(0.0_real64, 1.0_real64, candidate, ok)
  call require(ok .and. candidate%sample_count() == 1, 'carrier rollback materialization')
  write(*,'(A)') 'FVQ77_CARRIER_CHECKPOINT_ROLLBACK=PASS'

  write(*,'(A)') 'FVQ77_BOTTOM_ENERGY_INDEPENDENT_ORACLE=PASS'

contains

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,A)') 'FVQ77_ASSERT_FAIL ', trim(label)
      error stop 77
    end if
  end subroutine require

  logical function close_value(a, b) result(ok_close)
    real(real64), intent(in) :: a, b
    real(real64) :: scale
    scale = max(1.0_real64, abs(a), abs(b))
    ok_close = abs(a-b) <= 1.0e-12_real64 * scale
  end function close_value

end program test_fvq77_bottom_energy_independent
