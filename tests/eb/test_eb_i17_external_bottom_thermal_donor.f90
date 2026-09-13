program test_eb_i17_external_bottom_thermal_donor
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_fmr_bottom_thermal_carrier, only: fmr_bottom_thermal_carrier_t, fmr_bottom_thermal_candidate_t
  use mod_liquid_water_sensible_enthalpy, only: liquid_water_sensible_enthalpy_parameters_t, &
       initialize_liquid_water_sensible_enthalpy_parameters, LWSE_OK
  use mod_fmr_external_bottom_thermal_donor, only: fmr_external_bottom_donor_request_t, &
       fmr_external_bottom_donor_response_t, initialize_fmr_external_bottom_donor_request
  use mod_fmr_bottom_sensible_energy, only: fmr_bottom_sensible_energy_result_t, &
       evaluate_fmr_bottom_sensible_energy, evaluate_fmr_bottom_sensible_energy_with_external_provider, &
       FMR_BOTTOM_ENERGY_COMPLETE, FMR_BOTTOM_ENERGY_INCOMPLETE_EXTERNAL_DONOR, &
       FMR_BOTTOM_ENERGY_INVALID_EXTERNAL_CONTEXT, FMR_BOTTOM_ENERGY_INVALID_EXTERNAL_RESPONSE
  implicit none

  integer :: provider_call_count = 0
  integer(int64) :: observed_token = 0_int64
  integer :: observed_ordinal = 0
  real(real64) :: observed_t0 = 0.0_real64
  real(real64) :: observed_t1 = 0.0_real64
  real(real64) :: observed_q = 0.0_real64
  real(real64) :: observed_quadrature_time = 0.0_real64

  call verify_complete_external_binding()
  call verify_legacy_entrypoint_stays_fail_closed()
  call verify_local_and_zero_do_not_call_provider()
  call verify_unavailable_and_stale_fail_closed()
  call verify_identity_mismatch_fails_closed()
  call verify_nonfinite_provider_cannot_form_complete_response()
  call verify_invalid_evaluation_token_fails_before_provider()
  call verify_mixed_reference_shift_identity()
  write(*,'(A)') 'EB_I17_EXTERNAL_BOTTOM_THERMAL_DONOR_GATE PASS'

contains

  subroutine make_parameters(reference_temperature_c, parameters)
    real(real64), intent(in) :: reference_temperature_c
    type(liquid_water_sensible_enthalpy_parameters_t), intent(out) :: parameters
    integer :: status

    call initialize_liquid_water_sensible_enthalpy_parameters(1000.0_real64, 4180.0_real64, &
         reference_temperature_c, parameters, status)
    call require(status == LWSE_OK .and. parameters%ready(), 'energy parameters ready')
  end subroutine make_parameters

  subroutine make_mixed_candidate(candidate)
    type(fmr_bottom_thermal_candidate_t), intent(out) :: candidate
    type(fmr_bottom_thermal_carrier_t) :: carrier
    logical :: ok

    call carrier%initialize(3, ok)
    call require(ok, 'mixed carrier initialize')
    call carrier%append_local(0.0_real64, 1.0_real64, 0.10_real64, 8.0_real64, 10.0_real64, ok)
    call require(ok, 'mixed local append')
    call carrier%append_external_incomplete(1.0_real64, 2.0_real64, -0.20_real64, ok)
    call require(ok, 'mixed external append')
    call carrier%append_zero(2.0_real64, 3.0_real64, ok)
    call require(ok, 'mixed zero append')
    call carrier%materialize_candidate(0.0_real64, 3.0_real64, candidate, ok)
    call require(ok .and. candidate%ready(), 'mixed candidate materialize')
  end subroutine make_mixed_candidate

  subroutine make_external_candidate(candidate)
    type(fmr_bottom_thermal_candidate_t), intent(out) :: candidate
    type(fmr_bottom_thermal_carrier_t) :: carrier
    logical :: ok

    call carrier%initialize(1, ok)
    call require(ok, 'external carrier initialize')
    call carrier%append_external_incomplete(4.0_real64, 5.0_real64, -0.25_real64, ok)
    call require(ok, 'external sample append')
    call carrier%materialize_candidate(4.0_real64, 5.0_real64, candidate, ok)
    call require(ok, 'external candidate materialize')
  end subroutine make_external_candidate

  subroutine reset_observation()
    provider_call_count = 0
    observed_token = 0_int64
    observed_ordinal = 0
    observed_t0 = 0.0_real64
    observed_t1 = 0.0_real64
    observed_q = 0.0_real64
    observed_quadrature_time = 0.0_real64
  end subroutine reset_observation

  subroutine verify_complete_external_binding()
    type(fmr_bottom_thermal_candidate_t) :: candidate
    type(liquid_water_sensible_enthalpy_parameters_t) :: parameters
    type(fmr_bottom_sensible_energy_result_t) :: result
    real(real64) :: total, local_subtotal, external_subtotal, expected_local, expected_external, expected_total
    logical :: available
    integer :: n, nlocal, nzero, nincomplete
    integer :: ncomplete, nunavailable, nstale, ninvalid, nmismatch

    call make_mixed_candidate(candidate)
    call make_parameters(5.0_real64, parameters)
    call reset_observation()
    call evaluate_fmr_bottom_sensible_energy_with_external_provider(candidate, parameters, 77_int64, &
         provider_complete_18c, result)

    call require(result%status() == FMR_BOTTOM_ENERGY_COMPLETE .and. result%complete(), 'mixed external result complete')
    call result%total_energy(total, available)
    call require(available, 'mixed external total available')
    expected_local = 0.01_real64*1000.0_real64*4180.0_real64*0.10_real64*(10.0_real64-5.0_real64)
    expected_external = 0.01_real64*1000.0_real64*4180.0_real64*(-0.20_real64)*(18.0_real64-5.0_real64)
    expected_total = expected_local + expected_external
    call require(close(total, expected_total, 1.0e-12_real64), 'external total uses candidate Q and provider T')

    call result%local_outward_subtotal(local_subtotal, available)
    call require(available .and. close(local_subtotal, expected_local, 1.0e-12_real64), 'local subtotal preserved')
    call result%external_inward_subtotal(external_subtotal, available)
    call require(available .and. close(external_subtotal, expected_external, 1.0e-12_real64), 'external subtotal exact')
    call result%counts(n, nlocal, nzero, nincomplete)
    call require(n == 3 .and. nlocal == 1 .and. nzero == 1 .and. nincomplete == 0, 'mixed counts exact')
    call result%external_counts(ncomplete, nunavailable, nstale, ninvalid, nmismatch)
    call require(ncomplete == 1 .and. nunavailable == 0 .and. nstale == 0 .and. ninvalid == 0 .and. nmismatch == 0, &
         'external complete counts exact')

    call require(provider_call_count == 1, 'provider called once only for external sample')
    call require(observed_token == 77_int64 .and. observed_ordinal == 2, 'request identity exact')
    call require(observed_t0 == 1.0_real64 .and. observed_t1 == 2.0_real64, 'request interval exact')
    call require(observed_q == -0.20_real64, 'request Q is candidate read-only context')
    call require(observed_quadrature_time == 2.0_real64, 'current-reference quadrature is sample t1')
    write(*,'(A)') 'EB_I17_COMPLETE_EXTERNAL_BINDING=PASS'
    write(*,'(A)') 'EB_I17_REQUEST_T1_QUADRATURE=PASS'
    write(*,'(A)') 'EB_I17_CANDIDATE_Q_AUTHORITY=PASS'
  end subroutine verify_complete_external_binding

  subroutine verify_legacy_entrypoint_stays_fail_closed()
    type(fmr_bottom_thermal_candidate_t) :: candidate
    type(liquid_water_sensible_enthalpy_parameters_t) :: parameters
    type(fmr_bottom_sensible_energy_result_t) :: result
    real(real64) :: total
    logical :: available

    call make_mixed_candidate(candidate)
    call make_parameters(5.0_real64, parameters)
    call evaluate_fmr_bottom_sensible_energy(candidate, parameters, result)
    call require(result%status() == FMR_BOTTOM_ENERGY_INCOMPLETE_EXTERNAL_DONOR .and. .not. result%complete(), &
         'legacy entrypoint remains fail closed')
    call result%total_energy(total, available)
    call require(.not. available .and. total == 0.0_real64, 'legacy incomplete total unavailable')
    write(*,'(A)') 'EB_I17_LEGACY_FAIL_CLOSED_PRESERVED=PASS'
  end subroutine verify_legacy_entrypoint_stays_fail_closed

  subroutine verify_local_and_zero_do_not_call_provider()
    type(fmr_bottom_thermal_carrier_t) :: carrier
    type(fmr_bottom_thermal_candidate_t) :: candidate
    type(liquid_water_sensible_enthalpy_parameters_t) :: parameters
    type(fmr_bottom_sensible_energy_result_t) :: result
    logical :: ok

    call carrier%initialize(2, ok)
    call require(ok, 'local-zero carrier initialize')
    call carrier%append_local(0.0_real64, 1.0_real64, 0.10_real64, 6.0_real64, 7.0_real64, ok)
    call require(ok, 'local-zero local append')
    call carrier%append_zero(1.0_real64, 2.0_real64, ok)
    call require(ok, 'local-zero zero append')
    call carrier%materialize_candidate(0.0_real64, 2.0_real64, candidate, ok)
    call require(ok, 'local-zero candidate materialize')
    call make_parameters(0.0_real64, parameters)
    call reset_observation()
    call evaluate_fmr_bottom_sensible_energy_with_external_provider(candidate, parameters, 88_int64, &
         provider_complete_18c, result)
    call require(result%complete() .and. provider_call_count == 0, 'provider skipped for local and zero samples')
    write(*,'(A)') 'EB_I17_NO_PROVIDER_FOR_LOCAL_OR_ZERO=PASS'
  end subroutine verify_local_and_zero_do_not_call_provider

  subroutine verify_unavailable_and_stale_fail_closed()
    type(fmr_bottom_thermal_candidate_t) :: candidate
    type(liquid_water_sensible_enthalpy_parameters_t) :: parameters
    type(fmr_bottom_sensible_energy_result_t) :: result
    real(real64) :: total
    logical :: available
    integer :: ncomplete, nunavailable, nstale, ninvalid, nmismatch

    call make_external_candidate(candidate)
    call make_parameters(5.0_real64, parameters)

    call evaluate_fmr_bottom_sensible_energy_with_external_provider(candidate, parameters, 91_int64, &
         provider_unavailable, result)
    call require(result%status() == FMR_BOTTOM_ENERGY_INCOMPLETE_EXTERNAL_DONOR .and. .not. result%complete(), &
         'unavailable provider fails closed')
    call result%external_counts(ncomplete, nunavailable, nstale, ninvalid, nmismatch)
    call require(ncomplete == 0 .and. nunavailable == 1 .and. nstale == 0 .and. ninvalid == 0 .and. nmismatch == 0, &
         'unavailable diagnostics exact')
    call result%total_energy(total, available)
    call require(.not. available, 'unavailable total not published')

    call evaluate_fmr_bottom_sensible_energy_with_external_provider(candidate, parameters, 92_int64, &
         provider_stale, result)
    call require(result%status() == FMR_BOTTOM_ENERGY_INCOMPLETE_EXTERNAL_DONOR .and. .not. result%complete(), &
         'stale provider fails closed')
    call result%external_counts(ncomplete, nunavailable, nstale, ninvalid, nmismatch)
    call require(ncomplete == 0 .and. nunavailable == 0 .and. nstale == 1 .and. ninvalid == 0 .and. nmismatch == 0, &
         'stale diagnostics exact')
    write(*,'(A)') 'EB_I17_UNAVAILABLE_STALE_FAIL_CLOSED=PASS'
  end subroutine verify_unavailable_and_stale_fail_closed

  subroutine verify_identity_mismatch_fails_closed()
    type(fmr_bottom_thermal_candidate_t) :: candidate
    type(liquid_water_sensible_enthalpy_parameters_t) :: parameters
    type(fmr_bottom_sensible_energy_result_t) :: result
    integer :: ncomplete, nunavailable, nstale, ninvalid, nmismatch

    call make_external_candidate(candidate)
    call make_parameters(5.0_real64, parameters)
    call evaluate_fmr_bottom_sensible_energy_with_external_provider(candidate, parameters, 101_int64, &
         provider_identity_mismatch, result)
    call require(result%status() == FMR_BOTTOM_ENERGY_INVALID_EXTERNAL_RESPONSE .and. .not. result%complete(), &
         'identity mismatch invalidates response')
    call result%external_counts(ncomplete, nunavailable, nstale, ninvalid, nmismatch)
    call require(ninvalid == 1 .and. nmismatch == 1, 'identity mismatch diagnostics exact')
    write(*,'(A)') 'EB_I17_IDENTITY_MISMATCH_FAIL_CLOSED=PASS'
  end subroutine verify_identity_mismatch_fails_closed

  subroutine verify_nonfinite_provider_cannot_form_complete_response()
    type(fmr_bottom_thermal_candidate_t) :: candidate
    type(liquid_water_sensible_enthalpy_parameters_t) :: parameters
    type(fmr_bottom_sensible_energy_result_t) :: result
    integer :: ncomplete, nunavailable, nstale, ninvalid, nmismatch

    call make_external_candidate(candidate)
    call make_parameters(5.0_real64, parameters)
    call evaluate_fmr_bottom_sensible_energy_with_external_provider(candidate, parameters, 102_int64, &
         provider_nonfinite_attempt, result)
    call require(result%status() == FMR_BOTTOM_ENERGY_INVALID_EXTERNAL_RESPONSE .and. .not. result%complete(), &
         'nonfinite complete response cannot be admitted')
    call result%external_counts(ncomplete, nunavailable, nstale, ninvalid, nmismatch)
    call require(ninvalid == 1 .and. nmismatch == 1, 'failed setter is invalid and cannot match live request')
    write(*,'(A)') 'EB_I17_NONFINITE_PROVIDER_FAIL_CLOSED=PASS'
  end subroutine verify_nonfinite_provider_cannot_form_complete_response

  subroutine verify_invalid_evaluation_token_fails_before_provider()
    type(fmr_bottom_thermal_candidate_t) :: candidate
    type(liquid_water_sensible_enthalpy_parameters_t) :: parameters
    type(fmr_bottom_sensible_energy_result_t) :: result

    call make_external_candidate(candidate)
    call make_parameters(5.0_real64, parameters)
    call reset_observation()
    call evaluate_fmr_bottom_sensible_energy_with_external_provider(candidate, parameters, 0_int64, &
         provider_complete_18c, result)
    call require(result%status() == FMR_BOTTOM_ENERGY_INVALID_EXTERNAL_CONTEXT .and. .not. result%complete(), &
         'invalid evaluation token rejected')
    call require(provider_call_count == 0, 'invalid token rejected before provider call')
    write(*,'(A)') 'EB_I17_INVALID_CONTEXT_FAIL_CLOSED=PASS'
  end subroutine verify_invalid_evaluation_token_fails_before_provider

  subroutine verify_mixed_reference_shift_identity()
    type(fmr_bottom_thermal_candidate_t) :: candidate
    type(liquid_water_sensible_enthalpy_parameters_t) :: p1, p2
    type(fmr_bottom_sensible_energy_result_t) :: r1, r2
    real(real64) :: e1, e2, expected_shift, delta_ref, qsum
    logical :: a1, a2

    call make_mixed_candidate(candidate)
    call make_parameters(5.0_real64, p1)
    delta_ref = 3.0_real64
    call make_parameters(8.0_real64, p2)
    call evaluate_fmr_bottom_sensible_energy_with_external_provider(candidate, p1, 120_int64, provider_complete_18c, r1)
    call evaluate_fmr_bottom_sensible_energy_with_external_provider(candidate, p2, 121_int64, provider_complete_18c, r2)
    call r1%total_energy(e1, a1)
    call r2%total_energy(e2, a2)
    qsum = 0.10_real64 - 0.20_real64
    expected_shift = -0.01_real64*1000.0_real64*4180.0_real64*delta_ref*qsum
    call require(a1 .and. a2 .and. close(e2-e1, expected_shift, 1.0e-12_real64), &
         'mixed local-external reference shift identity')
    write(*,'(A)') 'EB_I17_MIXED_REFERENCE_SHIFT=PASS'
  end subroutine verify_mixed_reference_shift_identity

  subroutine provider_complete_18c(request, response)
    type(fmr_external_bottom_donor_request_t), intent(in) :: request
    type(fmr_external_bottom_donor_response_t), intent(out) :: response
    logical :: ok, a1, a2, a3

    provider_call_count = provider_call_count + 1
    observed_token = request%evaluation_token()
    observed_ordinal = request%sample_ordinal()
    call request%interval(observed_t0, observed_t1, a1)
    call request%outward_exchange_context(observed_q, a2)
    call request%quadrature_time(observed_quadrature_time, a3)
    call require(a1 .and. a2 .and. a3, 'provider received ready request')
    call response%set_complete(request, 18.0_real64, 9001_int64, 4_int64, ok)
    call require(ok, 'complete provider response constructed')
  end subroutine provider_complete_18c

  subroutine provider_unavailable(request, response)
    type(fmr_external_bottom_donor_request_t), intent(in) :: request
    type(fmr_external_bottom_donor_response_t), intent(out) :: response
    logical :: ok
    call response%set_unavailable(request, ok)
    call require(ok, 'unavailable response constructed')
  end subroutine provider_unavailable

  subroutine provider_stale(request, response)
    type(fmr_external_bottom_donor_request_t), intent(in) :: request
    type(fmr_external_bottom_donor_response_t), intent(out) :: response
    logical :: ok
    call response%set_stale(request, 3001_int64, 8_int64, ok)
    call require(ok, 'stale response constructed')
  end subroutine provider_stale

  subroutine provider_identity_mismatch(request, response)
    type(fmr_external_bottom_donor_request_t), intent(in) :: request
    type(fmr_external_bottom_donor_response_t), intent(out) :: response
    type(fmr_external_bottom_donor_request_t) :: wrong_request
    real(real64) :: t0, t1, q
    logical :: ok, a1, a2

    call request%interval(t0, t1, a1)
    call request%outward_exchange_context(q, a2)
    call require(a1 .and. a2, 'mismatch provider request readable')
    call initialize_fmr_external_bottom_donor_request(request%evaluation_token()+1_int64, request%sample_ordinal(), &
         t0, t1, q, wrong_request, ok)
    call require(ok, 'wrong request constructed')
    call response%set_complete(wrong_request, 18.0_real64, 9002_int64, 1_int64, ok)
    call require(ok, 'mismatched response constructed')
  end subroutine provider_identity_mismatch

  subroutine provider_nonfinite_attempt(request, response)
    type(fmr_external_bottom_donor_request_t), intent(in) :: request
    type(fmr_external_bottom_donor_response_t), intent(out) :: response
    real(real64) :: nan_value
    logical :: ok

    nan_value = ieee_value(0.0_real64, ieee_quiet_nan)
    call response%set_complete(request, nan_value, 9003_int64, 1_int64, ok)
    call require(.not. ok, 'nonfinite complete response rejected by seam')
  end subroutine provider_nonfinite_attempt

  logical function close(a, b, tolerance) result(ok)
    real(real64), intent(in) :: a, b, tolerance
    ok = abs(a-b) <= tolerance * max(1.0_real64, abs(a), abs(b))
  end function close

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'EB_I17_TEST_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_eb_i17_external_bottom_thermal_donor
