program test_eb_i18_external_bottom_thermal_provider
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_fmr_bottom_external_thermal_provider, only: fmr_external_bottom_thermal_request_t, &
       fmr_external_bottom_thermal_response_t, initialize_fmr_external_bottom_thermal_request, &
       FMR_EXT_THERMAL_RESPONSE_COMPLETE, FMR_EXT_THERMAL_RESPONSE_UNAVAILABLE, FMR_EXT_THERMAL_RESPONSE_STALE
  implicit none

  type(fmr_external_bottom_thermal_request_t) :: request_a, request_b, invalid_request
  type(fmr_external_bottom_thermal_response_t) :: response
  real(real64) :: temperature
  logical :: ok, available

  call initialize_fmr_external_bottom_thermal_request(17_int64, 2, 4.0_real64, 5.0_real64, &
       -0.125_real64, request_a, ok)
  call require(ok .and. request_a%ready(), 'valid request A')

  call initialize_fmr_external_bottom_thermal_request(17_int64, 2, 4.0_real64, 5.0_real64, &
       -0.250_real64, request_b, ok)
  call require(ok .and. request_b%ready(), 'valid request B')

  call response%set_complete(request_a, 12.5_real64, 701_int64, ok)
  call require(ok .and. response%ready(), 'complete response')
  call require(response%disposition() == FMR_EXT_THERMAL_RESPONSE_COMPLETE, 'complete disposition')
  call require(response%identity_matches(request_a), 'exact request identity')
  call require(.not. response%identity_matches(request_b), 'changed water transfer rejected')
  call response%donor_temperature(temperature, available)
  call require(available .and. temperature == 12.5_real64, 'donor temperature')
  call require(response%source_provenance_token() == 701_int64, 'source provenance')
  write(*,'(A)') 'EB_I18_PROVIDER_EXACT_SAMPLE_IDENTITY=PASS'

  call response%set_unavailable(request_a, 702_int64, ok)
  call require(ok .and. response%ready(), 'unavailable response')
  call require(response%disposition() == FMR_EXT_THERMAL_RESPONSE_UNAVAILABLE, 'unavailable disposition')
  call require(response%identity_matches(request_a), 'unavailable identity')
  call response%donor_temperature(temperature, available)
  call require(.not. available, 'unavailable has no temperature')
  write(*,'(A)') 'EB_I18_PROVIDER_UNAVAILABLE_FAIL_CLOSED=PASS'

  call response%set_stale(request_a, 703_int64, ok)
  call require(ok .and. response%ready(), 'stale response')
  call require(response%disposition() == FMR_EXT_THERMAL_RESPONSE_STALE, 'stale disposition')
  call require(response%identity_matches(request_a), 'stale identity')
  call response%donor_temperature(temperature, available)
  call require(.not. available, 'stale has no temperature')
  write(*,'(A)') 'EB_I18_PROVIDER_STALE_FAIL_CLOSED=PASS'

  call initialize_fmr_external_bottom_thermal_request(17_int64, 2, 4.0_real64, 5.0_real64, &
       0.0_real64, invalid_request, ok)
  call require(.not. ok .and. .not. invalid_request%ready(), 'zero is not external inflow request')
  call initialize_fmr_external_bottom_thermal_request(17_int64, 2, 4.0_real64, 5.0_real64, &
       0.125_real64, invalid_request, ok)
  call require(.not. ok .and. .not. invalid_request%ready(), 'outflow is not external inflow request')
  call response%set_complete(request_a, 12.5_real64, -1_int64, ok)
  call require(.not. ok .and. .not. response%ready(), 'negative provenance rejected')
  write(*,'(A)') 'EB_I18_PROVIDER_INVALID_INPUT_FAIL_CLOSED=PASS'

  write(*,'(A)') 'EB_I18_EXTERNAL_BOTTOM_THERMAL_PROVIDER_GATE PASS'

contains

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'EB_I18_PROVIDER_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_eb_i18_external_bottom_thermal_provider
