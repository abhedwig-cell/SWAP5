program test_fwof28_rate_state_view_assembly
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_wofost_crop_owner_state, only: wofost_crop_owner_state_t
  use mod_wofost_one_day_rate_state_view, only: &
       wofost_one_day_rate_state_view_t, assemble_wofost_one_day_rate_state_view, &
       WOFOST_RATE_STATE_VIEW_OK, WOFOST_RATE_STATE_VIEW_INVALID_OWNER, &
       WOFOST_RATE_STATE_VIEW_INVALID_CANOPY_PARAMETER, WOFOST_RATE_STATE_VIEW_INVALID_VALUE
  implicit none

  type(wofost_crop_owner_state_t) :: owner, before, inactive_owner, invalid_owner, negative_dvs_owner
  type(wofost_one_day_rate_state_view_t) :: view
  logical :: available
  integer :: status
  real(real64) :: nanv

  nanv = ieee_value(0.0_real64, ieee_quiet_nan)

  inactive_owner%crop_emerged = .false.
  inactive_owner%development_stage = -0.1_real64
  call assemble_wofost_one_day_rate_state_view(inactive_owner, nanv, nanv, view, available, status)
  call require(status == WOFOST_RATE_STATE_VIEW_OK, 'inactive route status')
  call require(.not. available, 'inactive route unavailable')
  call require(view%validate() == WOFOST_RATE_STATE_VIEW_OK, 'inactive zero view valid')
  call require(all_zero_view(view), 'inactive route returns zero view')
  write(*,'(A)') 'FWOF28_INACTIVE_ROUTE_NO_ACTIVE_CANOPY_DEPENDENCY=PASS'

  call seed_active_owner(owner)
  before = owner
  call assemble_wofost_one_day_rate_state_view(owner, 0.005_real64, 0.002_real64, &
       view, available, status)
  call require(status == WOFOST_RATE_STATE_VIEW_OK, 'active assembly status')
  call require(available, 'active view available')
  call require(view%validate() == WOFOST_RATE_STATE_VIEW_OK, 'active view validates')
  call require(same_bits(view%development_stage, 0.8_real64), 'DVS view')
  call require(same_bits(view%actual_root_biomass, 10.0_real64), 'WRT view')
  call require(same_bits(view%actual_stem_biomass, 20.0_real64), 'WST view')
  call require(same_bits(view%actual_storage_biomass, 30.0_real64), 'WSO view')
  call require(same_bits(view%living_leaf_biomass, 9.0_real64), 'WLV view')
  call require(abs(view%actual_leaf_area_index - 0.41_real64) <= 1.0e-15_real64, 'LAI view')
  call require(same_bits(view%exponential_leaf_area_index, 2.5_real64), 'LAIEXP view')
  call require(same_owner(owner, before), 'assembly is read only')
  write(*,'(A)') 'FWOF28_ACTIVE_SEMANTIC_RATE_STATE_VIEW=PASS'
  write(*,'(A)') 'FWOF28_ASSEMBLY_DOES_NOT_MUTATE_OWNER=PASS'

  call assemble_wofost_one_day_rate_state_view(owner, -0.001_real64, 0.0_real64, &
       view, available, status)
  call require(status == WOFOST_RATE_STATE_VIEW_INVALID_CANOPY_PARAMETER, 'negative SSA rejected')
  call require(.not. available, 'negative SSA unavailable')

  call assemble_wofost_one_day_rate_state_view(owner, 0.0_real64, nanv, &
       view, available, status)
  call require(status == WOFOST_RATE_STATE_VIEW_INVALID_CANOPY_PARAMETER, 'nonfinite SPA rejected')
  call require(.not. available, 'nonfinite SPA unavailable')
  write(*,'(A)') 'FWOF28_ACTIVE_CANOPY_PARAMETERS_FAIL_CLOSED=PASS'

  invalid_owner%crop_emerged = .true.
  invalid_owner%development_stage = 0.5_real64
  call assemble_wofost_one_day_rate_state_view(invalid_owner, 0.0_real64, 0.0_real64, &
       view, available, status)
  call require(status == WOFOST_RATE_STATE_VIEW_INVALID_OWNER, 'invalid owner rejected')
  call require(.not. available, 'invalid owner unavailable')
  write(*,'(A)') 'FWOF28_INVALID_OWNER_FAILS_CLOSED=PASS'

  negative_dvs_owner = owner
  negative_dvs_owner%development_stage = -0.01_real64
  call assemble_wofost_one_day_rate_state_view(negative_dvs_owner, 0.0_real64, 0.0_real64, &
       view, available, status)
  call require(status == WOFOST_RATE_STATE_VIEW_INVALID_VALUE, 'active negative DVS rejected')
  call require(.not. available, 'active negative DVS unavailable')
  write(*,'(A)') 'FWOF28_ACTIVE_NEGATIVE_DVS_FAILS_CLOSED=PASS'

  write(*,'(A)') 'FWOF28_RATE_STATE_VIEW_ASSEMBLY_TEST PASS'

contains

  subroutine seed_active_owner(value)
    type(wofost_crop_owner_state_t), intent(out) :: value

    value%crop_emerged = .true.
    value%development_stage = 0.8_real64
    allocate(value%biomass)
    value%biomass%root_biomass = 10.0_real64
    value%biomass%stem_biomass = 20.0_real64
    value%biomass%storage_biomass = 30.0_real64
    value%biomass%exponential_leaf_area_index = 2.5_real64
    value%biomass%leaf_biomass = [4.0_real64, 3.0_real64, 2.0_real64]
    value%biomass%specific_leaf_area = [0.02_real64, 0.03_real64, 0.04_real64]
    value%biomass%leaf_age = [0.0_real64, 1.0_real64, 2.0_real64]
  end subroutine seed_active_owner

  logical function all_zero_view(value) result(equal)
    type(wofost_one_day_rate_state_view_t), intent(in) :: value
    equal = same_bits(value%development_stage, 0.0_real64) .and. &
         same_bits(value%actual_root_biomass, 0.0_real64) .and. &
         same_bits(value%actual_stem_biomass, 0.0_real64) .and. &
         same_bits(value%actual_storage_biomass, 0.0_real64) .and. &
         same_bits(value%living_leaf_biomass, 0.0_real64) .and. &
         same_bits(value%actual_leaf_area_index, 0.0_real64) .and. &
         same_bits(value%exponential_leaf_area_index, 0.0_real64)
  end function all_zero_view

  logical function same_owner(left, right) result(equal)
    type(wofost_crop_owner_state_t), intent(in) :: left, right
    integer :: i

    equal = .false.
    if (left%crop_emerged .neqv. right%crop_emerged) return
    if (.not. same_bits(left%development_stage, right%development_stage)) return
    if (allocated(left%biomass) .neqv. allocated(right%biomass)) return
    if (allocated(left%evolution_continuation) .neqv. allocated(right%evolution_continuation)) return
    if (allocated(left%b110_reference_compatibility) .neqv. allocated(right%b110_reference_compatibility)) return
    if (allocated(left%biomass)) then
      if (.not. same_bits(left%biomass%root_biomass, right%biomass%root_biomass)) return
      if (.not. same_bits(left%biomass%stem_biomass, right%biomass%stem_biomass)) return
      if (.not. same_bits(left%biomass%storage_biomass, right%biomass%storage_biomass)) return
      if (.not. same_bits(left%biomass%exponential_leaf_area_index, right%biomass%exponential_leaf_area_index)) return
      if (left%biomass%active_leaf_cohort_count() /= right%biomass%active_leaf_cohort_count()) return
      do i = 1, left%biomass%active_leaf_cohort_count()
        if (.not. same_bits(left%biomass%leaf_biomass(i), right%biomass%leaf_biomass(i))) return
        if (.not. same_bits(left%biomass%specific_leaf_area(i), right%biomass%specific_leaf_area(i))) return
        if (.not. same_bits(left%biomass%leaf_age(i), right%biomass%leaf_age(i))) return
      end do
    end if
    equal = .true.
  end function same_owner

  logical function same_bits(left, right) result(equal)
    real(real64), intent(in) :: left, right
    equal = transfer(left, 0_int64) == transfer(right, 0_int64)
  end function same_bits

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(A)') 'FAIL: ' // trim(message)
      error stop 1
    end if
  end subroutine require

end program test_fwof28_rate_state_view_assembly
