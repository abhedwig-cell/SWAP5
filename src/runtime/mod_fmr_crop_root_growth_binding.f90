module mod_fmr_crop_root_growth_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_fmr_wofost_crop_transaction, only: fmr_wofost_crop_transaction_state_t, &
       fmr_wofost_root_growth_carrier_t
  use mod_wofost_crop_owner_state, only: wofost_crop_owner_state_t, WOFOST_CROP_OWNER_OK
  use mod_wofost_potential_shadow_state, only: wofost_potential_shadow_state_t, WOFOST_POTENTIAL_SHADOW_OK
  use mod_wofost_one_day_structural_evolution, only: wofost_accepted_window_aggregates_t
  use mod_crop_root_depth_rate_owner, only: crop_root_depth_rate_daily_forcing_t
  implicit none
  private

  integer, parameter, public :: FMR_CROP_ROOT_BIND_OK = 0
  integer, parameter, public :: FMR_CROP_ROOT_BIND_INVALID_TRANSACTION = 1
  integer, parameter, public :: FMR_CROP_ROOT_BIND_MISSING_POTENTIAL = 2
  integer, parameter, public :: FMR_CROP_ROOT_BIND_INVALID_AGGREGATES = 3

  type, public :: fmr_crop_root_growth_views_t
    type(crop_root_depth_rate_daily_forcing_t) :: swrd2
    type(wofost_crop_owner_state_t) :: actual_owner
    real(real64) :: potential_root_biomass = 0.0_real64
    logical :: swrd2_available = .false.
    logical :: swrd3_available = .false.
  end type

  public :: build_fmr_crop_root_growth_views

contains

  subroutine build_fmr_crop_root_growth_views(crop_transaction, aggregates, views, status)
    type(fmr_wofost_crop_transaction_state_t), intent(in) :: crop_transaction
    type(wofost_accepted_window_aggregates_t), intent(in) :: aggregates
    type(fmr_crop_root_growth_views_t), intent(out) :: views
    integer, intent(out) :: status

    type(fmr_wofost_root_growth_carrier_t) :: growth
    type(wofost_potential_shadow_state_t) :: shadow
    logical :: available

    views = fmr_crop_root_growth_views_t()
    status = FMR_CROP_ROOT_BIND_INVALID_TRANSACTION
    if (.not. crop_transaction%ready()) return

    status = FMR_CROP_ROOT_BIND_INVALID_AGGREGATES
    if (.not. ieee_is_finite(aggregates%actual_root_uptake) .or. &
        .not. ieee_is_finite(aggregates%potential_transpiration)) return
    if (aggregates%actual_root_uptake < 0.0_real64 .or. aggregates%potential_transpiration < 0.0_real64) return
    if (aggregates%actual_root_uptake > aggregates%potential_transpiration + &
        256.0_real64*epsilon(1.0_real64)*max(1.0_real64,aggregates%potential_transpiration)) return

    call crop_transaction%snapshot_owner(views%actual_owner, available)
    if (.not. available .or. views%actual_owner%validate() /= WOFOST_CROP_OWNER_OK) then
      status = FMR_CROP_ROOT_BIND_INVALID_TRANSACTION
      return
    end if

    status = FMR_CROP_ROOT_BIND_MISSING_POTENTIAL
    if (.not. crop_transaction%potential_shadow_enabled()) return

    call crop_transaction%snapshot_potential_shadow(shadow, available)
    if (.not. available .or. shadow%validate() /= WOFOST_POTENTIAL_SHADOW_OK .or. .not. shadow%active) return
    views%potential_root_biomass = shadow%root_biomass()
    if (.not. ieee_is_finite(views%potential_root_biomass) .or. views%potential_root_biomass < 0.0_real64) return
    views%swrd3_available = .true.

    call crop_transaction%snapshot_root_growth(growth, available)
    if (.not. available .or. .not. growth%ready()) return
    views%swrd2%potential_transpiration = aggregates%potential_transpiration
    views%swrd2%actual_root_uptake = aggregates%actual_root_uptake
    views%swrd2%actual_root_growth = growth%actual_gross_root_growth
    views%swrd2%potential_root_growth = growth%potential_gross_root_growth
    views%swrd2_available = .true.

    status = FMR_CROP_ROOT_BIND_OK
  end subroutine build_fmr_crop_root_growth_views

end module mod_fmr_crop_root_growth_binding
