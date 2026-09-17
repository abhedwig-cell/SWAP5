program test_fapp04_pmdirect_typed_bindings
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_pmdirect_swetr0_process
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t
  use mod_restricted_surface_evaporation, only: surface_evaporation_demand_t
  use mod_fmr_pmdirect_ptra_root_input_binding
  use mod_fmr_pmdirect_surface_evaporation_binding
  implicit none

  type(crop_root_uptake_input_t) :: base_root, bound_root
  type(pmdirect_swetr0_interval_result_t) :: interval
  type(pmdirect_swetr0_daily_result_t) :: daily
  type(pmdirect_swetr0_diagnostics_t) :: upstream
  type(fmr_pmdirect_ptra_root_binding_diagnostics_t) :: root_diag
  type(surface_evaporation_demand_t) :: surface_demand
  type(fmr_pmdirect_surface_demand_binding_diagnostics_t) :: surface_diag
  real(real64) :: qnan

  qnan = ieee_value(0.0_real64, ieee_quiet_nan)

  call set_emerged_geometry(base_root)
  base_root%potential_transpiration = 9.0_real64
  interval = pmdirect_swetr0_interval_result_t()
  interval%potential_transpiration_cm_per_day = 0.180673591545995882_real64
  upstream = pmdirect_swetr0_diagnostics_t()
  upstream%interval_result_produced = .true.

  call fmr_bind_pmdirect_ptra_to_root_input(base_root, 4, interval, upstream, bound_root, root_diag)
  call require(root_diag%status == FMR_PMDIRECT_PTRA_ROOT_BINDING_OK, 'emerged root binding status')
  call require(root_diag%upstream_result_accepted, 'emerged upstream accepted')
  call require(root_diag%incoming_ptra_ignored, 'incoming ptra not ignored')
  call require(root_diag%ptra_bound .and. root_diag%result_produced, 'emerged ptra not bound')
  call require(.not. root_diag%inactive_crop_zero_applied, 'emerged crop incorrectly neutralized')
  call require(same_bits(bound_root%potential_transpiration, interval%potential_transpiration_cm_per_day), &
               'emerged ptra mapping not exact')
  call require(bound_root%crop_emerged .and. bound_root%rooted_nodes == 2, 'root geometry changed')
  call require(allocated(bound_root%cumulative_root_fraction), 'root fractions lost')
  call require(same_bits(bound_root%cumulative_root_fraction(1), 0.0_real64) .and. &
               same_bits(bound_root%cumulative_root_fraction(2), 0.35_real64) .and. &
               same_bits(bound_root%cumulative_root_fraction(3), 1.0_real64), &
               'root fractions changed')
  write(*,'(a)') 'FAPP04_PMDIRECT_ROOT_EXACT_MAPPING=PASS'

  base_root = crop_root_uptake_input_t()
  interval%potential_transpiration_cm_per_day = 1.0e-24_real64
  upstream = pmdirect_swetr0_diagnostics_t()
  upstream%interval_result_produced = .true.
  call fmr_bind_pmdirect_ptra_to_root_input(base_root, 4, interval, upstream, bound_root, root_diag)
  call require(root_diag%status == FMR_PMDIRECT_PTRA_ROOT_BINDING_OK .and. root_diag%result_produced, &
               'inactive root binding rejected')
  call require(root_diag%inactive_crop_zero_applied .and. .not. root_diag%ptra_bound, &
               'inactive crop canonical zero not applied')
  call require(.not. bound_root%crop_emerged .and. same_bits(bound_root%potential_transpiration, 0.0_real64) .and. &
               bound_root%rooted_nodes == 0 .and. .not. allocated(bound_root%cumulative_root_fraction), &
               'inactive root output not canonical')
  write(*,'(a)') 'FAPP04_PMDIRECT_INACTIVE_CROP_CANONICAL_ZERO=PASS'

  call set_emerged_geometry(base_root)
  interval%potential_transpiration_cm_per_day = qnan
  upstream = pmdirect_swetr0_diagnostics_t()
  upstream%interval_result_produced = .true.
  call fmr_bind_pmdirect_ptra_to_root_input(base_root, 4, interval, upstream, bound_root, root_diag)
  call require(root_diag%status == FMR_PMDIRECT_PTRA_ROOT_INVALID_PTRA .and. .not. root_diag%result_produced, &
               'nonfinite ptra did not fail closed')
  call require(.not. bound_root%crop_emerged, 'rejected ptra leaked root output')
  write(*,'(a)') 'FAPP04_PMDIRECT_ROOT_NONFINITE_FAIL_CLOSED=PASS'

  base_root = crop_root_uptake_input_t()
  base_root%crop_emerged = .true.
  base_root%rooted_nodes = 2
  interval%potential_transpiration_cm_per_day = 0.1_real64
  upstream = pmdirect_swetr0_diagnostics_t()
  upstream%interval_result_produced = .true.
  call fmr_bind_pmdirect_ptra_to_root_input(base_root, 4, interval, upstream, bound_root, root_diag)
  call require(root_diag%status == FMR_PMDIRECT_PTRA_ROOT_INVALID_ROOT_GEOMETRY .and. &
               .not. root_diag%result_produced, 'invalid root geometry did not fail closed')
  write(*,'(a)') 'FAPP04_PMDIRECT_ROOT_GEOMETRY_FAIL_CLOSED=PASS'

  call set_emerged_geometry(base_root)
  upstream = pmdirect_swetr0_diagnostics_t()
  interval%potential_transpiration_cm_per_day = 0.1_real64
  call fmr_bind_pmdirect_ptra_to_root_input(base_root, 4, interval, upstream, bound_root, root_diag)
  call require(root_diag%status == FMR_PMDIRECT_PTRA_ROOT_UPSTREAM_REJECTED .and. &
               .not. root_diag%result_produced, 'unproduced interval accepted')
  write(*,'(a)') 'FAPP04_PMDIRECT_ROOT_UPSTREAM_FAIL_CLOSED=PASS'

  daily = pmdirect_swetr0_daily_result_t()
  daily%potential_soil_evaporation_cm_per_day = 0.253814812232436682_real64
  daily%potential_pond_evaporation_cm_per_day = 0.208567410149469362_real64
  upstream = pmdirect_swetr0_diagnostics_t()
  upstream%daily_result_produced = .true.
  call fmr_bind_pmdirect_surface_evaporation_demand(daily, upstream, surface_demand, surface_diag)
  call require(surface_diag%status == FMR_PMDIRECT_SURFACE_DEMAND_BINDING_OK .and. &
               surface_diag%demand_bound .and. surface_diag%result_produced, 'surface demand binding rejected')
  call require(same_bits(surface_demand%bare_soil_demand, daily%potential_soil_evaporation_cm_per_day), &
               'bare-soil demand mapping not exact')
  call require(same_bits(surface_demand%ponded_water_demand, daily%potential_pond_evaporation_cm_per_day), &
               'ponded-water demand mapping not exact')
  write(*,'(a)') 'FAPP04_PMDIRECT_SURFACE_EXACT_MAPPING=PASS'

  daily%potential_soil_evaporation_cm_per_day = qnan
  upstream = pmdirect_swetr0_diagnostics_t()
  upstream%daily_result_produced = .true.
  call fmr_bind_pmdirect_surface_evaporation_demand(daily, upstream, surface_demand, surface_diag)
  call require(surface_diag%status == FMR_PMDIRECT_SURFACE_DEMAND_INVALID_DEMAND .and. &
               .not. surface_diag%result_produced, 'nonfinite surface demand did not fail closed')
  call require(same_bits(surface_demand%bare_soil_demand, 0.0_real64) .and. &
               same_bits(surface_demand%ponded_water_demand, 0.0_real64), 'rejected surface demand leaked output')
  write(*,'(a)') 'FAPP04_PMDIRECT_SURFACE_NONFINITE_FAIL_CLOSED=PASS'

  daily = pmdirect_swetr0_daily_result_t()
  daily%potential_soil_evaporation_cm_per_day = 0.1_real64
  daily%potential_pond_evaporation_cm_per_day = 0.2_real64
  upstream = pmdirect_swetr0_diagnostics_t()
  call fmr_bind_pmdirect_surface_evaporation_demand(daily, upstream, surface_demand, surface_diag)
  call require(surface_diag%status == FMR_PMDIRECT_SURFACE_DEMAND_UPSTREAM_REJECTED .and. &
               .not. surface_diag%result_produced, 'unproduced daily result accepted')
  write(*,'(a)') 'FAPP04_PMDIRECT_SURFACE_UPSTREAM_FAIL_CLOSED=PASS'

  write(*,'(a)') 'F-APP04 PMdirect typed bindings PASS'

contains

  subroutine set_emerged_geometry(input)
    type(crop_root_uptake_input_t), intent(out) :: input
    input = crop_root_uptake_input_t()
    input%crop_emerged = .true.
    input%rooted_nodes = 2
    allocate(input%cumulative_root_fraction(3))
    input%cumulative_root_fraction = [0.0_real64, 0.35_real64, 1.0_real64]
  end subroutine set_emerged_geometry

  pure logical function same_bits(a, b) result(same)
    real(real64), intent(in) :: a, b
    same = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_bits

  subroutine require(ok, label)
    logical, intent(in) :: ok
    character(*), intent(in) :: label
    if (.not. ok) then
      write(*,'(a)') trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fapp04_pmdirect_typed_bindings
