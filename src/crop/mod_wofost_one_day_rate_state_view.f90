module mod_wofost_one_day_rate_state_view
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_wofost_crop_owner_state, only: wofost_crop_owner_state_t, WOFOST_CROP_OWNER_OK
  implicit none
  private

  integer, parameter, public :: WOFOST_RATE_STATE_VIEW_OK = 0
  integer, parameter, public :: WOFOST_RATE_STATE_VIEW_INVALID_OWNER = 1
  integer, parameter, public :: WOFOST_RATE_STATE_VIEW_INVALID_CANOPY_PARAMETER = 2
  integer, parameter, public :: WOFOST_RATE_STATE_VIEW_INVALID_VALUE = 3

  type, public :: wofost_one_day_rate_state_view_t
    real(real64) :: development_stage = 0.0_real64
    real(real64) :: actual_root_biomass = 0.0_real64
    real(real64) :: actual_stem_biomass = 0.0_real64
    real(real64) :: actual_storage_biomass = 0.0_real64
    real(real64) :: living_leaf_biomass = 0.0_real64
    real(real64) :: actual_leaf_area_index = 0.0_real64
    real(real64) :: exponential_leaf_area_index = 0.0_real64
  contains
    procedure, public :: validate => wofost_one_day_rate_state_view_validate
  end type wofost_one_day_rate_state_view_t

  public :: assemble_wofost_one_day_rate_state_view

contains

  subroutine assemble_wofost_one_day_rate_state_view(owner, stem_area_coefficient, &
       storage_area_coefficient, view, available, status)
    type(wofost_crop_owner_state_t), intent(in) :: owner
    real(real64), intent(in) :: stem_area_coefficient
    real(real64), intent(in) :: storage_area_coefficient
    type(wofost_one_day_rate_state_view_t), intent(out) :: view
    logical, intent(out) :: available
    integer, intent(out) :: status
    real(real64) :: root_biomass, leaf_area_index
    logical :: root_available
    integer :: owner_status

    view = wofost_one_day_rate_state_view_t()
    available = .false.
    status = WOFOST_RATE_STATE_VIEW_OK

    owner_status = owner%validate()
    if (owner_status /= WOFOST_CROP_OWNER_OK) then
      status = WOFOST_RATE_STATE_VIEW_INVALID_OWNER
      return
    end if

    ! Inactive WOFOST columns do not allocate biomass and do not depend on
    ! active-only canopy parameters. Preserve that optional-state boundary.
    if (.not. owner%crop_is_emerged()) return

    if (.not. valid_nonnegative(stem_area_coefficient)) then
      status = WOFOST_RATE_STATE_VIEW_INVALID_CANOPY_PARAMETER
      return
    end if
    if (.not. valid_nonnegative(storage_area_coefficient)) then
      status = WOFOST_RATE_STATE_VIEW_INVALID_CANOPY_PARAMETER
      return
    end if

    view%development_stage = owner%current_development_stage()
    if (.not. valid_nonnegative(view%development_stage)) then
      status = WOFOST_RATE_STATE_VIEW_INVALID_VALUE
      return
    end if

    call owner%read_actual_root_biomass(root_biomass, root_available, owner_status)
    if (owner_status /= WOFOST_CROP_OWNER_OK .or. .not. root_available) then
      status = WOFOST_RATE_STATE_VIEW_INVALID_OWNER
      return
    end if

    call owner%derive_actual_leaf_area_index(stem_area_coefficient, storage_area_coefficient, &
         leaf_area_index, owner_status)
    if (owner_status /= WOFOST_CROP_OWNER_OK) then
      status = WOFOST_RATE_STATE_VIEW_INVALID_CANOPY_PARAMETER
      return
    end if

    view%actual_root_biomass = root_biomass
    view%actual_stem_biomass = owner%biomass%stem_biomass
    view%actual_storage_biomass = owner%biomass%storage_biomass
    view%living_leaf_biomass = owner%biomass%living_leaf_biomass()
    view%actual_leaf_area_index = leaf_area_index
    view%exponential_leaf_area_index = owner%biomass%exponential_leaf_area_index

    if (view%validate() /= WOFOST_RATE_STATE_VIEW_OK) then
      view = wofost_one_day_rate_state_view_t()
      status = WOFOST_RATE_STATE_VIEW_INVALID_VALUE
      return
    end if

    available = .true.
  end subroutine assemble_wofost_one_day_rate_state_view

  integer function wofost_one_day_rate_state_view_validate(self) result(status)
    class(wofost_one_day_rate_state_view_t), intent(in) :: self
    real(real64) :: values(7)

    values = [self%development_stage, self%actual_root_biomass, &
         self%actual_stem_biomass, self%actual_storage_biomass, &
         self%living_leaf_biomass, self%actual_leaf_area_index, &
         self%exponential_leaf_area_index]

    status = WOFOST_RATE_STATE_VIEW_OK
    if (.not. all(ieee_is_finite(values))) then
      status = WOFOST_RATE_STATE_VIEW_INVALID_VALUE
      return
    end if
    if (any(values < 0.0_real64)) then
      status = WOFOST_RATE_STATE_VIEW_INVALID_VALUE
      return
    end if
  end function wofost_one_day_rate_state_view_validate

  pure logical function valid_nonnegative(value) result(valid)
    real(real64), intent(in) :: value
    valid = ieee_is_finite(value) .and. value >= 0.0_real64
  end function valid_nonnegative

end module mod_wofost_one_day_rate_state_view
