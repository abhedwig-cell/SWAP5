module mod_wofost_crop_owner_state
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t
  use mod_wofost_actual_biomass_state, only: wofost_actual_biomass_state_t, WOFOST_BIOMASS_STATE_OK
  implicit none
  private

  integer, parameter, public :: WOFOST_CROP_OWNER_OK = 0
  integer, parameter, public :: WOFOST_CROP_OWNER_INVALID_DVS = 1
  integer, parameter, public :: WOFOST_CROP_OWNER_BIOMASS_PRESENCE_MISMATCH = 2
  integer, parameter, public :: WOFOST_CROP_OWNER_INVALID_BIOMASS = 3
  integer, parameter, public :: WOFOST_CROP_OWNER_INVALID_CANOPY_PARAMETER = 4
  integer, parameter, public :: WOFOST_CROP_OWNER_INVALID_DERIVED_LAI = 5

  type, extends(transaction_state_t), public :: wofost_crop_owner_state_t
    logical :: crop_emerged = .false.
    real(real64) :: development_stage = 0.0_real64
    type(wofost_actual_biomass_state_t), allocatable :: biomass
  contains
    procedure :: clone => wofost_crop_owner_clone
    procedure, public :: validate => wofost_crop_owner_validate
    procedure, public :: crop_is_emerged => wofost_crop_is_emerged
    procedure, public :: current_development_stage => wofost_current_development_stage
    procedure, public :: read_actual_root_biomass => wofost_read_actual_root_biomass
    procedure, public :: derive_actual_leaf_area_index => wofost_derive_actual_leaf_area_index
  end type wofost_crop_owner_state_t

contains

  subroutine wofost_crop_owner_clone(self, copy)
    class(wofost_crop_owner_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy

    allocate(wofost_crop_owner_state_t :: copy)
    select type (typed_copy => copy)
    type is (wofost_crop_owner_state_t)
      typed_copy%crop_emerged = self%crop_emerged
      typed_copy%development_stage = self%development_stage
      if (allocated(self%biomass)) then
        allocate(typed_copy%biomass)
        typed_copy%biomass = self%biomass
      end if
    class default
      error stop 'WOFOST crop owner state: clone allocation failure'
    end select
  end subroutine wofost_crop_owner_clone

  integer function wofost_crop_owner_validate(self) result(status)
    class(wofost_crop_owner_state_t), intent(in) :: self
    integer :: biomass_status

    status = WOFOST_CROP_OWNER_OK

    if (.not. ieee_is_finite(self%development_stage)) then
      status = WOFOST_CROP_OWNER_INVALID_DVS
      return
    end if

    if (self%crop_emerged) then
      if (.not. allocated(self%biomass)) then
        status = WOFOST_CROP_OWNER_BIOMASS_PRESENCE_MISMATCH
        return
      end if
      biomass_status = self%biomass%validate()
      if (biomass_status /= WOFOST_BIOMASS_STATE_OK) then
        status = WOFOST_CROP_OWNER_INVALID_BIOMASS
        return
      end if
    else
      if (allocated(self%biomass)) then
        status = WOFOST_CROP_OWNER_BIOMASS_PRESENCE_MISMATCH
        return
      end if
    end if
  end function wofost_crop_owner_validate

  logical function wofost_crop_is_emerged(self) result(value)
    class(wofost_crop_owner_state_t), intent(in) :: self
    value = self%crop_emerged
  end function wofost_crop_is_emerged

  real(real64) function wofost_current_development_stage(self) result(value)
    class(wofost_crop_owner_state_t), intent(in) :: self
    value = self%development_stage
  end function wofost_current_development_stage

  subroutine wofost_read_actual_root_biomass(self, value, available, status)
    class(wofost_crop_owner_state_t), intent(in) :: self
    real(real64), intent(out) :: value
    logical, intent(out) :: available
    integer, intent(out) :: status

    value = 0.0_real64
    available = .false.
    status = self%validate()
    if (status /= WOFOST_CROP_OWNER_OK) return
    if (.not. self%crop_emerged) return

    value = self%biomass%actual_root_biomass()
    available = .true.
  end subroutine wofost_read_actual_root_biomass

  subroutine wofost_derive_actual_leaf_area_index(self, stem_area_coefficient, storage_area_coefficient, value, status)
    class(wofost_crop_owner_state_t), intent(in) :: self
    real(real64), intent(in) :: stem_area_coefficient
    real(real64), intent(in) :: storage_area_coefficient
    real(real64), intent(out) :: value
    integer, intent(out) :: status

    value = 0.0_real64
    status = self%validate()
    if (status /= WOFOST_CROP_OWNER_OK) return

    ! Preserve the dependency-free inactive route: stale or unavailable active
    ! crop parameters are not inspected before emergence.
    if (.not. self%crop_emerged) return

    if (.not. ieee_is_finite(stem_area_coefficient)) then
      status = WOFOST_CROP_OWNER_INVALID_CANOPY_PARAMETER
      return
    end if
    if (stem_area_coefficient < 0.0_real64) then
      status = WOFOST_CROP_OWNER_INVALID_CANOPY_PARAMETER
      return
    end if
    if (.not. ieee_is_finite(storage_area_coefficient)) then
      status = WOFOST_CROP_OWNER_INVALID_CANOPY_PARAMETER
      return
    end if
    if (storage_area_coefficient < 0.0_real64) then
      status = WOFOST_CROP_OWNER_INVALID_CANOPY_PARAMETER
      return
    end if

    value = self%biomass%leaf_area_sum() + &
         stem_area_coefficient * self%biomass%stem_biomass + &
         storage_area_coefficient * self%biomass%storage_biomass

    if (.not. ieee_is_finite(value)) then
      value = 0.0_real64
      status = WOFOST_CROP_OWNER_INVALID_DERIVED_LAI
      return
    end if
    if (value < 0.0_real64) then
      value = 0.0_real64
      status = WOFOST_CROP_OWNER_INVALID_DERIVED_LAI
      return
    end if
  end subroutine wofost_derive_actual_leaf_area_index

end module mod_wofost_crop_owner_state
