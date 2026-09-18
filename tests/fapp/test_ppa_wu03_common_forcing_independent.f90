program test_ppa_wu03_common_forcing_independent
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t
  use mod_ppa_wu03_common_forcing_adapter, only: ppa_wu03_common_forcing_config_t, &
       ppa_wu03_common_forcing_input_t, ppa_wu03_common_forcing_result_t, &
       ppa_wu03_common_forcing_diagnostics_t, materialize_ppa_wu03_common_forcing, &
       PPA_WU03_OK, PPA_WU03_UNSUPPORTED_ET, PPA_WU03_UNSUPPORTED_INTERCEPTION, &
       PPA_WU03_UNSUPPORTED_IRRIGATION, PPA_WU03_ET_REFERENCE, &
       PPA_WU03_INTERCEPTION_NONE, PPA_WU03_IRRIGATION_NONE, &
       PPA_WU03_IRRIGATION_RESOLVED_SURFACE
  implicit none

  real(real64), parameter :: TOL = 1.0e-14_real64
  real(real64), parameter :: durations(3) = [0.03125_real64, 0.125_real64, 0.75_real64]
  real(real64), parameter :: et_values(3) = [0.0_real64, 2.5_real64, 6.0_real64]
  real(real64), parameter :: covers(3) = [0.0_real64, 0.4_real64, 0.9_real64]
  type(ppa_wu03_common_forcing_config_t) :: config, bad_config
  type(ppa_wu03_common_forcing_input_t) :: input, bad_input
  type(ppa_wu03_common_forcing_result_t) :: result
  type(ppa_wu03_common_forcing_diagnostics_t) :: diagnostics
  type(b110_dynamic_top_boundary_request_t) :: base_request
  real(real64) :: expected_soil, expected_pond, expected_ptra, irrigation
  integer :: i, j, k, mode, cases

  base_request = b110_dynamic_top_boundary_request_t()
  base_request%conductivity_mean_method = 1
  base_request%pressure_head_top_cm = -80.0_real64
  base_request%water_content_top = 0.25_real64
  base_request%candidate_ponding_depth_cm = 0.0_real64
  base_request%previous_ponding_depth_cm = 0.0_real64
  base_request%ponding_max_cm = 2.0_real64
  base_request%runoff_resistance_day = 1.0_real64
  base_request%runoff_exponent = 1.0_real64

  config%et_mode = PPA_WU03_ET_REFERENCE
  config%interception_mode = PPA_WU03_INTERCEPTION_NONE
  config%reference_et_parameters%pond_evaporation_factor = 0.85_real64

  cases = 0
  do i = 1, size(durations)
    do j = 1, size(et_values)
      do k = 1, size(covers)
        do mode = 0, 1
          input = ppa_wu03_common_forcing_input_t()
          input%interval%t0 = 5000.123_real64 + 0.01_real64 * real(i+j+k+mode, real64)
          input%interval%t1 = input%interval%t0 + durations(i)
          input%forcing_t0 = input%interval%t0 - 0.2_real64
          input%forcing_t1 = input%interval%t1 + 0.2_real64
          input%reference_et%t0 = input%forcing_t0
          input%reference_et%t1 = input%forcing_t1
          input%reference_et%reference_et_mm_per_day = et_values(j)
          input%precipitation_rate_cm_per_day = 0.01_real64 * real(i+j, real64)
          input%canopy%vegetation_cover_fraction = covers(k)
          input%canopy%crop_emerged = mod(i+j+k,2) == 0
          input%canopy%crop_factor = 0.75_real64 + 0.05_real64 * real(k, real64)
          input%canopy%co2_transpiration_factor = 0.9_real64 + 0.02_real64 * real(j, real64)

          if (mode == 0) then
            config%irrigation_mode = PPA_WU03_IRRIGATION_NONE
            irrigation = 0.0_real64
          else
            config%irrigation_mode = PPA_WU03_IRRIGATION_RESOLVED_SURFACE
            irrigation = 0.002_real64 * real(i+k, real64)
          end if
          input%surface_irrigation_rate_cm_per_day = irrigation

          call materialize_ppa_wu03_common_forcing(config, input, base_request, result, diagnostics)
          call require(diagnostics%status == PPA_WU03_OK .and. result%valid, 'matrix case accepted')

          expected_soil = et_values(j) * (1.0_real64 - covers(k)) * 0.1_real64
          expected_pond = expected_soil * config%reference_et_parameters%pond_evaporation_factor
          expected_ptra = 0.0_real64
          if (input%canopy%crop_emerged) then
            expected_ptra = et_values(j) * covers(k) * input%canopy%crop_factor * 0.1_real64 * &
                 input%canopy%co2_transpiration_factor
          end if

          call require(abs(result%reference_et_demand%potential_soil_evaporation_cm_per_day - &
               expected_soil) <= TOL, 'independent soil evaporation oracle')
          call require(abs(result%reference_et_demand%potential_pond_evaporation_cm_per_day - &
               expected_pond) <= TOL, 'independent pond evaporation oracle')
          call require(abs(result%reference_et_demand%potential_transpiration_cm_per_day - &
               expected_ptra) <= TOL, 'independent transpiration oracle')
          call require(result%top_request%step_duration_day == durations(i), 'generic duration identity')
          call require(result%top_request%precipitation_rate_cm_per_day == input%precipitation_rate_cm_per_day, &
               'precipitation transport identity')
          call require(result%top_request%irrigation_rate_cm_per_day == irrigation, &
               'irrigation transport identity')
          call require(result%top_request%snowmelt_rate_cm_per_day == 0.0_real64 .and. &
               result%top_request%runon_rate_cm_per_day == 0.0_real64, 'excluded surface terms remain zero')
          cases = cases + 1
        end do
      end do
    end do
  end do

  call require(cases == 54, 'independent matrix cardinality')

  bad_config = config
  bad_config%et_mode = -1
  call materialize_ppa_wu03_common_forcing(bad_config, input, base_request, result, diagnostics)
  call require(diagnostics%status == PPA_WU03_UNSUPPORTED_ET .and. .not. result%valid, &
       'independent unsupported ET')

  bad_config = config
  bad_config%interception_mode = 3
  call materialize_ppa_wu03_common_forcing(bad_config, input, base_request, result, diagnostics)
  call require(diagnostics%status == PPA_WU03_UNSUPPORTED_INTERCEPTION .and. .not. result%valid, &
       'independent unsupported interception')

  bad_config = config
  bad_config%irrigation_mode = 8
  call materialize_ppa_wu03_common_forcing(bad_config, input, base_request, result, diagnostics)
  call require(diagnostics%status == PPA_WU03_UNSUPPORTED_IRRIGATION .and. .not. result%valid, &
       'independent unsupported irrigation')

  bad_input = input
  bad_input%forcing_t0 = bad_input%interval%t0 + 1.0e-3_real64
  call materialize_ppa_wu03_common_forcing(config, bad_input, base_request, result, diagnostics)
  call require(.not. result%valid, 'independent noncovering common span')

  bad_input = input
  bad_input%reference_et%t1 = bad_input%interval%t1 - 1.0e-3_real64
  call materialize_ppa_wu03_common_forcing(config, bad_input, base_request, result, diagnostics)
  call require(.not. result%valid, 'independent noncovering reference ET span')

  bad_input = input
  bad_input%precipitation_rate_cm_per_day = -epsilon(1.0_real64)
  call materialize_ppa_wu03_common_forcing(config, bad_input, base_request, result, diagnostics)
  call require(.not. result%valid, 'independent negative precipitation')

  base_request%snowmelt_rate_cm_per_day = 0.01_real64
  call materialize_ppa_wu03_common_forcing(config, input, base_request, result, diagnostics)
  call require(.not. result%valid, 'independent excluded snowmelt fails closed')

  print '(a,i0)', 'PPA_WU03_INDEPENDENT_MATRIX_CASES=', cases
  print '(a)', 'PPA_WU03_INDEPENDENT_ET_ORACLE=PASS'
  print '(a)', 'PPA_WU03_INDEPENDENT_GENERIC_TIME=PASS'
  print '(a)', 'PPA_WU03_INDEPENDENT_TRANSPORT_IDENTITY=PASS'
  print '(a)', 'PPA_WU03_INDEPENDENT_FAIL_CLOSED=PASS'
  print '(a)', 'PPA-WU03 INDEPENDENT QUALIFICATION PASS'

contains

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a,1x,a)') 'PPA_WU03_INDEPENDENT_FAIL', trim(message)
      error stop 1
    end if
  end subroutine require

end program test_ppa_wu03_common_forcing_independent
