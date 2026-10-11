program test_fapp04_pmdirect_dynamic_top_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_pmdirect_swetr0_process, only: pmdirect_swetr0_interval_result_t, pmdirect_swetr0_diagnostics_t
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t
  use mod_fmr_pmdirect_dynamic_top_boundary_binding
  implicit none

  type(b110_dynamic_top_boundary_request_t) :: base_request, bound_request
  type(pmdirect_swetr0_interval_result_t) :: interval
  type(pmdirect_swetr0_diagnostics_t) :: upstream
  type(fmr_pmdirect_top_precip_binding_diagnostics_t) :: diagnostics
  real(real64) :: qnan

  qnan = ieee_value(0.0_real64, ieee_quiet_nan)

  call set_distinctive_base_request(base_request)
  interval = pmdirect_swetr0_interval_result_t()
  interval%net_rain_cm_per_day = 0.405938742948784959_real64
  upstream = pmdirect_swetr0_diagnostics_t()
  upstream%interval_result_produced = .true.

  call fmr_bind_pmdirect_net_rain_to_dynamic_top_request(base_request, interval, upstream, bound_request, diagnostics)
  call require(diagnostics%status == FMR_PMDIRECT_TOP_PRECIP_BINDING_OK, 'positive mapping status')
  call require(diagnostics%upstream_result_accepted, 'positive upstream not accepted')
  call require(diagnostics%incoming_precipitation_ignored, 'incoming precipitation not ignored')
  call require(diagnostics%precipitation_bound .and. diagnostics%result_produced, 'net rain not bound')
  call require(same_bits(bound_request%precipitation_rate_cm_per_day, interval%net_rain_cm_per_day), &
               'net rain mapping not bit exact')
  write(*,'(a)') 'FAPP04_PMDIRECT_NET_RAIN_EXACT_MAPPING=PASS'

  call require_nonprecipitation_fields_preserved(base_request, bound_request)
  write(*,'(a)') 'FAPP04_PMDIRECT_DYNAMIC_TOP_NONPRECIP_FIELDS_PRESERVED=PASS'
  call require(.not. same_bits(base_request%precipitation_rate_cm_per_day, &
                               bound_request%precipitation_rate_cm_per_day), &
               'incoming precipitation was not replaced')
  write(*,'(a)') 'FAPP04_PMDIRECT_INCOMING_PRECIP_IGNORED=PASS'

  call set_distinctive_base_request(base_request)
  interval = pmdirect_swetr0_interval_result_t()
  interval%net_rain_cm_per_day = 0.0_real64
  upstream = pmdirect_swetr0_diagnostics_t()
  upstream%interval_result_produced = .true.
  call fmr_bind_pmdirect_net_rain_to_dynamic_top_request(base_request, interval, upstream, bound_request, diagnostics)
  call require(diagnostics%status == FMR_PMDIRECT_TOP_PRECIP_BINDING_OK .and. diagnostics%result_produced, &
               'zero net rain rejected')
  call require(same_bits(bound_request%precipitation_rate_cm_per_day, 0.0_real64), &
               'zero net rain not mapped exactly')
  call require_nonprecipitation_fields_preserved(base_request, bound_request)
  write(*,'(a)') 'FAPP04_PMDIRECT_ZERO_NET_RAIN_MAPPING=PASS'

  call set_distinctive_base_request(base_request)
  interval = pmdirect_swetr0_interval_result_t()
  interval%net_rain_cm_per_day = qnan
  upstream = pmdirect_swetr0_diagnostics_t()
  upstream%interval_result_produced = .true.
  call fmr_bind_pmdirect_net_rain_to_dynamic_top_request(base_request, interval, upstream, bound_request, diagnostics)
  call require(diagnostics%status == FMR_PMDIRECT_TOP_PRECIP_INVALID_NET_RAIN .and. &
               .not. diagnostics%result_produced, 'NaN net rain did not fail closed')
  call require(default_request(bound_request), 'NaN rejection leaked request')
  write(*,'(a)') 'FAPP04_PMDIRECT_NET_RAIN_NONFINITE_FAIL_CLOSED=PASS'

  call set_distinctive_base_request(base_request)
  interval = pmdirect_swetr0_interval_result_t()
  interval%net_rain_cm_per_day = -0.1_real64
  upstream = pmdirect_swetr0_diagnostics_t()
  upstream%interval_result_produced = .true.
  call fmr_bind_pmdirect_net_rain_to_dynamic_top_request(base_request, interval, upstream, bound_request, diagnostics)
  call require(diagnostics%status == FMR_PMDIRECT_TOP_PRECIP_INVALID_NET_RAIN .and. &
               .not. diagnostics%result_produced, 'negative net rain did not fail closed')
  call require(default_request(bound_request), 'negative rejection leaked request')
  write(*,'(a)') 'FAPP04_PMDIRECT_NET_RAIN_NEGATIVE_FAIL_CLOSED=PASS'

  call set_distinctive_base_request(base_request)
  interval = pmdirect_swetr0_interval_result_t()
  interval%net_rain_cm_per_day = 0.25_real64
  upstream = pmdirect_swetr0_diagnostics_t()
  call fmr_bind_pmdirect_net_rain_to_dynamic_top_request(base_request, interval, upstream, bound_request, diagnostics)
  call require(diagnostics%status == FMR_PMDIRECT_TOP_PRECIP_UPSTREAM_REJECTED .and. &
               .not. diagnostics%result_produced, 'unproduced interval accepted')
  call require(default_request(bound_request), 'upstream rejection leaked request')
  write(*,'(a)') 'FAPP04_PMDIRECT_NET_RAIN_UPSTREAM_FAIL_CLOSED=PASS'

  write(*,'(a)') 'F-APP04 PMdirect dynamic-top binding PASS'

contains

  subroutine set_distinctive_base_request(request)
    type(b110_dynamic_top_boundary_request_t), intent(out) :: request

    request = b110_dynamic_top_boundary_request_t()
    request%conductivity_mean_method = 4
    request%pressure_head_top_cm = -123.5_real64
    request%water_content_top = 0.314_real64
    request%candidate_ponding_depth_cm = 0.07_real64
    request%previous_ponding_depth_cm = 0.03_real64
    request%step_duration_day = 0.125_real64
    request%precipitation_rate_cm_per_day = 9.0_real64
    request%irrigation_rate_cm_per_day = 0.11_real64
    request%snowmelt_rate_cm_per_day = 0.12_real64
    request%runon_rate_cm_per_day = 0.13_real64
    request%potential_bare_soil_evaporation_cm_per_day = 0.14_real64
    request%potential_pond_evaporation_cm_per_day = 0.15_real64
    request%ponding_max_cm = 0.16_real64
    request%runoff_resistance_day = 0.17_real64
    request%runoff_exponent = 1.0_real64
  end subroutine set_distinctive_base_request

  subroutine require_nonprecipitation_fields_preserved(before, after)
    type(b110_dynamic_top_boundary_request_t), intent(in) :: before, after

    call require(after%conductivity_mean_method == before%conductivity_mean_method, 'conductivity method changed')
    call require(same_bits(after%pressure_head_top_cm, before%pressure_head_top_cm), 'pressure head changed')
    call require(same_bits(after%water_content_top, before%water_content_top), 'water content changed')
    call require(same_bits(after%candidate_ponding_depth_cm, before%candidate_ponding_depth_cm), &
                 'candidate ponding changed')
    call require(same_bits(after%previous_ponding_depth_cm, before%previous_ponding_depth_cm), &
                 'previous ponding changed')
    call require(same_bits(after%step_duration_day, before%step_duration_day), 'step duration changed')
    call require(same_bits(after%irrigation_rate_cm_per_day, before%irrigation_rate_cm_per_day), &
                 'irrigation changed')
    call require(same_bits(after%snowmelt_rate_cm_per_day, before%snowmelt_rate_cm_per_day), 'snowmelt changed')
    call require(same_bits(after%runon_rate_cm_per_day, before%runon_rate_cm_per_day), 'runon changed')
    call require(same_bits(after%potential_bare_soil_evaporation_cm_per_day, &
                           before%potential_bare_soil_evaporation_cm_per_day), 'bare evaporation changed')
    call require(same_bits(after%potential_pond_evaporation_cm_per_day, &
                           before%potential_pond_evaporation_cm_per_day), 'pond evaporation changed')
    call require(same_bits(after%ponding_max_cm, before%ponding_max_cm), 'ponding max changed')
    call require(same_bits(after%runoff_resistance_day, before%runoff_resistance_day), 'runoff resistance changed')
    call require(same_bits(after%runoff_exponent, before%runoff_exponent), 'runoff exponent changed')
  end subroutine require_nonprecipitation_fields_preserved

  pure logical function same_bits(a, b) result(equal)
    real(real64), intent(in) :: a, b
    equal = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_bits

  pure logical function default_request(request) result(is_default)
    type(b110_dynamic_top_boundary_request_t), intent(in) :: request
    is_default = request%conductivity_mean_method == 0 .and. &
                 same_bits(request%pressure_head_top_cm, 0.0_real64) .and. &
                 same_bits(request%water_content_top, 0.0_real64) .and. &
                 same_bits(request%candidate_ponding_depth_cm, 0.0_real64) .and. &
                 same_bits(request%previous_ponding_depth_cm, 0.0_real64) .and. &
                 same_bits(request%step_duration_day, 0.0_real64) .and. &
                 same_bits(request%precipitation_rate_cm_per_day, 0.0_real64) .and. &
                 same_bits(request%irrigation_rate_cm_per_day, 0.0_real64) .and. &
                 same_bits(request%snowmelt_rate_cm_per_day, 0.0_real64) .and. &
                 same_bits(request%runon_rate_cm_per_day, 0.0_real64) .and. &
                 same_bits(request%potential_bare_soil_evaporation_cm_per_day, 0.0_real64) .and. &
                 same_bits(request%potential_pond_evaporation_cm_per_day, 0.0_real64) .and. &
                 same_bits(request%ponding_max_cm, 0.0_real64) .and. &
                 same_bits(request%runoff_resistance_day, 0.0_real64) .and. &
                 same_bits(request%runoff_exponent, 1.0_real64)
  end function default_request

  subroutine require(ok, label)
    logical, intent(in) :: ok
    character(*), intent(in) :: label
    if (.not. ok) then
      write(*,'(a)') trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fapp04_pmdirect_dynamic_top_binding
