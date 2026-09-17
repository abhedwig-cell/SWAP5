program test_fvq103_fapp04_composition_independent
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_pmdirect_swetr0_process, only: pmdirect_swetr0_interval_result_t, pmdirect_swetr0_daily_result_t, &
       pmdirect_swetr0_diagnostics_t
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t
  use mod_restricted_surface_evaporation, only: surface_evaporation_demand_t
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t
  use mod_fmr_pmdirect_ptra_root_input_binding
  use mod_fmr_pmdirect_surface_evaporation_binding
  use mod_fmr_pmdirect_dynamic_top_boundary_binding
  implicit none

  real(real64), parameter :: transport_values(8) = [ &
       0.0_real64, 1.0e-15_real64, 1.0e-12_real64, 0.03125_real64, &
       0.180673591545995882_real64, 0.405938742948784959_real64, &
       0.75_real64, 2.0_real64 ]
  real(real64), parameter :: surface_soil(6) = [ &
       0.0_real64, 1.0e-15_real64, 0.01_real64, 0.125_real64, &
       0.253814812232436682_real64, 1.0_real64 ]
  real(real64), parameter :: surface_pond(6) = [ &
       0.0_real64, 0.2_real64, 1.0e-15_real64, 0.0625_real64, &
       0.208567410149469362_real64, 2.0_real64 ]

  type(crop_root_uptake_input_t) :: root_base, root_bound
  type(surface_evaporation_demand_t) :: surface_demand
  type(b110_dynamic_top_boundary_request_t) :: top_base, top_bound
  type(pmdirect_swetr0_interval_result_t) :: interval
  type(pmdirect_swetr0_daily_result_t) :: daily
  type(pmdirect_swetr0_diagnostics_t) :: upstream
  type(fmr_pmdirect_ptra_root_binding_diagnostics_t) :: root_diag
  type(fmr_pmdirect_surface_demand_binding_diagnostics_t) :: surface_diag
  type(fmr_pmdirect_top_precip_binding_diagnostics_t) :: top_diag
  real(real64) :: qnan
  integer :: i

  qnan = ieee_value(0.0_real64, ieee_quiet_nan)

  ! Independent metamorphic root-binding sweep. The test treats PMdirect output
  ! as an already-qualified typed value and checks only transport semantics.
  do i = 1, size(transport_values)
    call set_root_geometry(root_base)
    root_base%potential_transpiration = 9.0_real64
    interval = pmdirect_swetr0_interval_result_t()
    interval%potential_transpiration_cm_per_day = transport_values(i)
    upstream = pmdirect_swetr0_diagnostics_t()
    upstream%interval_result_produced = .true.

    call fmr_bind_pmdirect_ptra_to_root_input(root_base, 4, interval, upstream, root_bound, root_diag)
    call require(root_diag%status == FMR_PMDIRECT_PTRA_ROOT_BINDING_OK, 'root sweep status')
    call require(root_diag%result_produced .and. root_diag%ptra_bound, 'root sweep no result')
    call require(root_diag%incoming_ptra_ignored, 'root sweep incoming ptra authoritative')
    call require(same_bits(root_bound%potential_transpiration, transport_values(i)), 'root ptra not bit exact')
    call require(root_geometry_equal(root_base, root_bound), 'root geometry changed')
  end do
  write(*,'(a,i0)') 'FVQ103_ROOT_IDENTITY_SWEEP=PASS n=', size(transport_values)

  root_base = crop_root_uptake_input_t()
  interval = pmdirect_swetr0_interval_result_t()
  interval%potential_transpiration_cm_per_day = 1.0e-24_real64
  upstream = pmdirect_swetr0_diagnostics_t()
  upstream%interval_result_produced = .true.
  call fmr_bind_pmdirect_ptra_to_root_input(root_base, 4, interval, upstream, root_bound, root_diag)
  call require(root_diag%status == FMR_PMDIRECT_PTRA_ROOT_BINDING_OK .and. root_diag%result_produced, &
               'inactive root rejected')
  call require(root_diag%inactive_crop_zero_applied .and. .not. root_diag%ptra_bound, &
               'inactive root did not retain canonical zero')
  call require(default_root(root_bound), 'inactive root not canonical default')
  write(*,'(a)') 'FVQ103_ROOT_INACTIVE_CANONICAL_ZERO=PASS'

  ! Independent surface-demand Cartesian sweep.
  do i = 1, size(surface_soil)
    daily = pmdirect_swetr0_daily_result_t()
    daily%potential_soil_evaporation_cm_per_day = surface_soil(i)
    daily%potential_pond_evaporation_cm_per_day = surface_pond(i)
    upstream = pmdirect_swetr0_diagnostics_t()
    upstream%daily_result_produced = .true.

    call fmr_bind_pmdirect_surface_evaporation_demand(daily, upstream, surface_demand, surface_diag)
    call require(surface_diag%status == FMR_PMDIRECT_SURFACE_DEMAND_BINDING_OK, 'surface sweep status')
    call require(surface_diag%demand_bound .and. surface_diag%result_produced, 'surface sweep no result')
    call require(same_bits(surface_demand%bare_soil_demand, surface_soil(i)), 'soil demand not bit exact')
    call require(same_bits(surface_demand%ponded_water_demand, surface_pond(i)), 'pond demand not bit exact')
  end do
  write(*,'(a,i0)') 'FVQ103_SURFACE_IDENTITY_SWEEP=PASS n=', size(surface_soil)

  ! Independent dynamic-top identity/preservation sweep.
  do i = 1, size(transport_values)
    call set_top_base(top_base, real(i, real64))
    interval = pmdirect_swetr0_interval_result_t()
    interval%net_rain_cm_per_day = transport_values(i)
    upstream = pmdirect_swetr0_diagnostics_t()
    upstream%interval_result_produced = .true.

    call fmr_bind_pmdirect_net_rain_to_dynamic_top_request(top_base, interval, upstream, top_bound, top_diag)
    call require(top_diag%status == FMR_PMDIRECT_TOP_PRECIP_BINDING_OK, 'top sweep status')
    call require(top_diag%result_produced .and. top_diag%precipitation_bound, 'top sweep no result')
    call require(top_diag%incoming_precipitation_ignored, 'top incoming precipitation authoritative')
    call require(same_bits(top_bound%precipitation_rate_cm_per_day, transport_values(i)), &
                 'top precipitation not bit exact')
    call require(top_nonprecipitation_equal(top_base, top_bound), 'top nonprecipitation field changed')
  end do
  write(*,'(a,i0)') 'FVQ103_DYNAMIC_TOP_IDENTITY_PRESERVATION_SWEEP=PASS n=', size(transport_values)

  ! Fail-closed checks are intentionally independent of owner-test values.
  call set_root_geometry(root_base)
  interval = pmdirect_swetr0_interval_result_t()
  interval%potential_transpiration_cm_per_day = qnan
  upstream = pmdirect_swetr0_diagnostics_t()
  upstream%interval_result_produced = .true.
  call fmr_bind_pmdirect_ptra_to_root_input(root_base, 4, interval, upstream, root_bound, root_diag)
  call require(root_diag%status == FMR_PMDIRECT_PTRA_ROOT_INVALID_PTRA .and. .not. root_diag%result_produced, &
               'root NaN did not fail closed')

  interval%potential_transpiration_cm_per_day = -1.0e-6_real64
  call fmr_bind_pmdirect_ptra_to_root_input(root_base, 4, interval, upstream, root_bound, root_diag)
  call require(root_diag%status == FMR_PMDIRECT_PTRA_ROOT_INVALID_PTRA .and. .not. root_diag%result_produced, &
               'root negative did not fail closed')

  interval%potential_transpiration_cm_per_day = 0.2_real64
  upstream = pmdirect_swetr0_diagnostics_t()
  call fmr_bind_pmdirect_ptra_to_root_input(root_base, 4, interval, upstream, root_bound, root_diag)
  call require(root_diag%status == FMR_PMDIRECT_PTRA_ROOT_UPSTREAM_REJECTED .and. .not. root_diag%result_produced, &
               'root upstream failure accepted')
  write(*,'(a)') 'FVQ103_ROOT_FAIL_CLOSED=PASS'

  daily = pmdirect_swetr0_daily_result_t()
  daily%potential_soil_evaporation_cm_per_day = qnan
  daily%potential_pond_evaporation_cm_per_day = 0.1_real64
  upstream = pmdirect_swetr0_diagnostics_t()
  upstream%daily_result_produced = .true.
  call fmr_bind_pmdirect_surface_evaporation_demand(daily, upstream, surface_demand, surface_diag)
  call require(surface_diag%status == FMR_PMDIRECT_SURFACE_DEMAND_INVALID_DEMAND .and. &
               .not. surface_diag%result_produced, 'surface NaN did not fail closed')

  daily%potential_soil_evaporation_cm_per_day = 0.1_real64
  daily%potential_pond_evaporation_cm_per_day = -1.0e-6_real64
  call fmr_bind_pmdirect_surface_evaporation_demand(daily, upstream, surface_demand, surface_diag)
  call require(surface_diag%status == FMR_PMDIRECT_SURFACE_DEMAND_INVALID_DEMAND .and. &
               .not. surface_diag%result_produced, 'surface negative did not fail closed')

  daily%potential_pond_evaporation_cm_per_day = 0.2_real64
  upstream = pmdirect_swetr0_diagnostics_t()
  call fmr_bind_pmdirect_surface_evaporation_demand(daily, upstream, surface_demand, surface_diag)
  call require(surface_diag%status == FMR_PMDIRECT_SURFACE_DEMAND_UPSTREAM_REJECTED .and. &
               .not. surface_diag%result_produced, 'surface upstream failure accepted')
  write(*,'(a)') 'FVQ103_SURFACE_FAIL_CLOSED=PASS'

  call set_top_base(top_base, 11.0_real64)
  interval = pmdirect_swetr0_interval_result_t()
  interval%net_rain_cm_per_day = qnan
  upstream = pmdirect_swetr0_diagnostics_t()
  upstream%interval_result_produced = .true.
  call fmr_bind_pmdirect_net_rain_to_dynamic_top_request(top_base, interval, upstream, top_bound, top_diag)
  call require(top_diag%status == FMR_PMDIRECT_TOP_PRECIP_INVALID_NET_RAIN .and. .not. top_diag%result_produced, &
               'top NaN did not fail closed')
  call require(default_top(top_bound), 'top NaN leaked output')

  interval%net_rain_cm_per_day = -1.0e-6_real64
  call fmr_bind_pmdirect_net_rain_to_dynamic_top_request(top_base, interval, upstream, top_bound, top_diag)
  call require(top_diag%status == FMR_PMDIRECT_TOP_PRECIP_INVALID_NET_RAIN .and. .not. top_diag%result_produced, &
               'top negative did not fail closed')
  call require(default_top(top_bound), 'top negative leaked output')

  interval%net_rain_cm_per_day = 0.2_real64
  upstream = pmdirect_swetr0_diagnostics_t()
  call fmr_bind_pmdirect_net_rain_to_dynamic_top_request(top_base, interval, upstream, top_bound, top_diag)
  call require(top_diag%status == FMR_PMDIRECT_TOP_PRECIP_UPSTREAM_REJECTED .and. .not. top_diag%result_produced, &
               'top upstream failure accepted')
  call require(default_top(top_bound), 'top upstream rejection leaked output')
  write(*,'(a)') 'FVQ103_DYNAMIC_TOP_FAIL_CLOSED=PASS'

  write(*,'(a)') 'F-VQ103 F-APP04 independent composition PASS'

contains

  subroutine set_root_geometry(input)
    type(crop_root_uptake_input_t), intent(out) :: input
    input = crop_root_uptake_input_t()
    input%crop_emerged = .true.
    input%rooted_nodes = 2
    allocate(input%cumulative_root_fraction(3))
    input%cumulative_root_fraction = [0.0_real64, 0.4_real64, 1.0_real64]
  end subroutine set_root_geometry

  pure logical function root_geometry_equal(before, after) result(equal)
    type(crop_root_uptake_input_t), intent(in) :: before, after
    equal = before%crop_emerged .eqv. after%crop_emerged
    if (.not. equal) return
    equal = before%rooted_nodes == after%rooted_nodes
    if (.not. equal) return
    equal = allocated(before%cumulative_root_fraction) .eqv. allocated(after%cumulative_root_fraction)
    if (.not. equal) return
    if (allocated(before%cumulative_root_fraction)) then
      equal = size(before%cumulative_root_fraction) == size(after%cumulative_root_fraction)
      if (.not. equal) return
      equal = all(transfer(before%cumulative_root_fraction, [0_int64,0_int64,0_int64]) == &
                  transfer(after%cumulative_root_fraction, [0_int64,0_int64,0_int64]))
    end if
  end function root_geometry_equal

  pure logical function default_root(input) result(is_default)
    type(crop_root_uptake_input_t), intent(in) :: input
    is_default = .not. input%crop_emerged .and. input%rooted_nodes == 0 .and. &
                 same_bits(input%potential_transpiration, 0.0_real64) .and. &
                 .not. allocated(input%cumulative_root_fraction)
  end function default_root

  subroutine set_top_base(request, seed)
    type(b110_dynamic_top_boundary_request_t), intent(out) :: request
    real(real64), intent(in) :: seed
    request = b110_dynamic_top_boundary_request_t()
    request%conductivity_mean_method = 4
    request%pressure_head_top_cm = -100.0_real64 - seed
    request%water_content_top = 0.2_real64 + 0.001_real64 * seed
    request%candidate_ponding_depth_cm = 0.01_real64 * seed
    request%previous_ponding_depth_cm = 0.005_real64 * seed
    request%step_duration_day = 0.01_real64 + 0.001_real64 * seed
    request%precipitation_rate_cm_per_day = 8.0_real64 + seed
    request%irrigation_rate_cm_per_day = 0.02_real64 * seed
    request%snowmelt_rate_cm_per_day = 0.03_real64 * seed
    request%runon_rate_cm_per_day = 0.04_real64 * seed
    request%potential_bare_soil_evaporation_cm_per_day = 0.05_real64 * seed
    request%potential_pond_evaporation_cm_per_day = 0.06_real64 * seed
    request%ponding_max_cm = 0.1_real64 + 0.01_real64 * seed
    request%runoff_resistance_day = 0.2_real64 + 0.01_real64 * seed
    request%runoff_exponent = 1.0_real64 + 0.01_real64 * seed
  end subroutine set_top_base

  pure logical function top_nonprecipitation_equal(before, after) result(equal)
    type(b110_dynamic_top_boundary_request_t), intent(in) :: before, after
    equal = before%conductivity_mean_method == after%conductivity_mean_method .and. &
            same_bits(before%pressure_head_top_cm, after%pressure_head_top_cm) .and. &
            same_bits(before%water_content_top, after%water_content_top) .and. &
            same_bits(before%candidate_ponding_depth_cm, after%candidate_ponding_depth_cm) .and. &
            same_bits(before%previous_ponding_depth_cm, after%previous_ponding_depth_cm) .and. &
            same_bits(before%step_duration_day, after%step_duration_day) .and. &
            same_bits(before%irrigation_rate_cm_per_day, after%irrigation_rate_cm_per_day) .and. &
            same_bits(before%snowmelt_rate_cm_per_day, after%snowmelt_rate_cm_per_day) .and. &
            same_bits(before%runon_rate_cm_per_day, after%runon_rate_cm_per_day) .and. &
            same_bits(before%potential_bare_soil_evaporation_cm_per_day, &
                      after%potential_bare_soil_evaporation_cm_per_day) .and. &
            same_bits(before%potential_pond_evaporation_cm_per_day, &
                      after%potential_pond_evaporation_cm_per_day) .and. &
            same_bits(before%ponding_max_cm, after%ponding_max_cm) .and. &
            same_bits(before%runoff_resistance_day, after%runoff_resistance_day) .and. &
            same_bits(before%runoff_exponent, after%runoff_exponent)
  end function top_nonprecipitation_equal

  pure logical function default_top(request) result(is_default)
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
  end function default_top

  pure logical function same_bits(a, b) result(equal)
    real(real64), intent(in) :: a, b
    equal = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_bits

  subroutine require(ok, label)
    logical, intent(in) :: ok
    character(*), intent(in) :: label
    if (.not. ok) then
      write(*,'(a)') trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fvq103_fapp04_composition_independent
