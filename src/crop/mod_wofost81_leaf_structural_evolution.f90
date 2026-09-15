module mod_wofost81_leaf_structural_evolution
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_wofost_crop_owner_state, only: wofost_crop_owner_state_t, wofost_b110_reference_compatibility_t, &
       WOFOST_CROP_OWNER_OK
  use mod_wofost_one_day_structural_evolution, only: wofost_one_day_rate_packet_t
  implicit none
  private

  real(real64), parameter :: LAIEXP_CARRYOVER_THRESHOLD = 6.0_real64
  integer, parameter, public :: WOFOST81_LEAF_STRUCTURE_OK = 0
  integer, parameter, public :: WOFOST81_LEAF_STRUCTURE_INVALID_OWNER = 1
  integer, parameter, public :: WOFOST81_LEAF_STRUCTURE_INVALID_RATES = 2
  integer, parameter, public :: WOFOST81_LEAF_STRUCTURE_MISSING_GLAIEXP_CARRYOVER = 3
  integer, parameter, public :: WOFOST81_LEAF_STRUCTURE_INVALID_RESULT = 4

  type, public :: wofost81_leaf_structure_diagnostics_t
    integer :: cohort_count_before = 0
    integer :: cohort_count_after = 0
    real(real64) :: requested_combined_leaf_death = 0.0_real64
    real(real64) :: applied_leaf_death = 0.0_real64
    logical :: captured_lai_exponential_carryover = .false.
    logical :: used_lai_exponential_carryover = .false.
  end type

  public :: apply_wofost81_leaf_structural_update

contains

  subroutine apply_wofost81_leaf_structural_update(candidate, rates, diagnostics, status)
    type(wofost_crop_owner_state_t), intent(inout) :: candidate
    type(wofost_one_day_rate_packet_t), intent(in) :: rates
    type(wofost81_leaf_structure_diagnostics_t), intent(out) :: diagnostics
    integer, intent(out) :: status
    real(real64), allocatable :: new_leaf(:), new_sla(:), new_age(:)
    real(real64) :: remaining_death, total_before, lai_before, lai_rate
    integer :: n

    diagnostics = wofost81_leaf_structure_diagnostics_t()
    status = WOFOST81_LEAF_STRUCTURE_INVALID_OWNER
    if (candidate%validate() /= WOFOST_CROP_OWNER_OK) return
    if (.not. candidate%crop_emerged) then
      status = WOFOST81_LEAF_STRUCTURE_OK
      return
    end if
    status = WOFOST81_LEAF_STRUCTURE_INVALID_RATES
    if (.not. valid_leaf_rates(rates)) return

    n = candidate%biomass%active_leaf_cohort_count()
    diagnostics%cohort_count_before = n
    total_before = sum(candidate%biomass%leaf_biomass)
    diagnostics%requested_combined_leaf_death = rates%leaf_stress_death_rate
    remaining_death = rates%leaf_stress_death_rate

    ! WOFOST81 donor lvdth: consume the already-combined DRLV once from oldest cohorts.
    do while (remaining_death > 0.0_real64 .and. n >= 1)
      if (remaining_death >= candidate%biomass%leaf_biomass(n)) then
        remaining_death = remaining_death - candidate%biomass%leaf_biomass(n)
        candidate%biomass%leaf_biomass(n) = 0.0_real64
        n = n - 1
      else
        candidate%biomass%leaf_biomass(n) = candidate%biomass%leaf_biomass(n) - remaining_death
        remaining_death = 0.0_real64
      end if
    end do
    diagnostics%applied_leaf_death = total_before - sum(candidate%biomass%leaf_biomass)

    ! Deliberately no legacy SPAN sweep here: WOFOST81 ageing already entered DRLV as DALV.
    allocate(new_leaf(n + 1), new_sla(n + 1), new_age(n + 1))
    new_leaf(1) = rates%leaf_growth_rate
    new_sla(1) = rates%youngest_specific_leaf_area
    new_age(1) = 0.0_real64
    if (n > 0) then
      new_leaf(2:n + 1) = candidate%biomass%leaf_biomass(1:n)
      new_sla(2:n + 1) = candidate%biomass%specific_leaf_area(1:n)
      new_age(2:n + 1) = candidate%biomass%leaf_age(1:n) + rates%leaf_age_increment
    end if
    call move_alloc(new_leaf, candidate%biomass%leaf_biomass)
    call move_alloc(new_sla, candidate%biomass%specific_leaf_area)
    call move_alloc(new_age, candidate%biomass%leaf_age)

    lai_before = candidate%biomass%exponential_leaf_area_index
    if (lai_before < LAIEXP_CARRYOVER_THRESHOLD) then
      if (.not. rates%lai_exponential_rate_recomputed) then
        status = WOFOST81_LEAF_STRUCTURE_INVALID_RATES
        return
      end if
      lai_rate = rates%lai_exponential_growth_rate
      candidate%biomass%exponential_leaf_area_index = lai_before + lai_rate
      if (candidate%biomass%exponential_leaf_area_index >= LAIEXP_CARRYOVER_THRESHOLD) then
        if (.not. allocated(candidate%b110_reference_compatibility)) &
             allocate(wofost_b110_reference_compatibility_t :: candidate%b110_reference_compatibility)
        candidate%b110_reference_compatibility%lai_exponential_rate_carryover = lai_rate
        diagnostics%captured_lai_exponential_carryover = .true.
      end if
    else
      if (rates%lai_exponential_rate_recomputed) then
        status = WOFOST81_LEAF_STRUCTURE_INVALID_RATES
        return
      end if
      if (.not. allocated(candidate%b110_reference_compatibility)) then
        status = WOFOST81_LEAF_STRUCTURE_MISSING_GLAIEXP_CARRYOVER
        return
      end if
      lai_rate = candidate%b110_reference_compatibility%lai_exponential_rate_carryover
      candidate%biomass%exponential_leaf_area_index = lai_before + lai_rate
      diagnostics%used_lai_exponential_carryover = .true.
    end if

    diagnostics%cohort_count_after = candidate%biomass%active_leaf_cohort_count()
    status = WOFOST81_LEAF_STRUCTURE_INVALID_RESULT
    if (candidate%validate() /= WOFOST_CROP_OWNER_OK) return
    if (.not. ieee_is_finite(diagnostics%applied_leaf_death) .or. diagnostics%applied_leaf_death < 0.0_real64) return
    status = WOFOST81_LEAF_STRUCTURE_OK
  end subroutine

  pure logical function valid_leaf_rates(rates) result(valid)
    type(wofost_one_day_rate_packet_t), intent(in) :: rates
    real(real64) :: values(5)
    values = [rates%leaf_growth_rate, rates%leaf_stress_death_rate, rates%leaf_age_increment, &
         rates%youngest_specific_leaf_area, rates%lai_exponential_growth_rate]
    valid = all(ieee_is_finite(values)) .and. all(values >= 0.0_real64)
  end function

end module mod_wofost81_leaf_structural_evolution
