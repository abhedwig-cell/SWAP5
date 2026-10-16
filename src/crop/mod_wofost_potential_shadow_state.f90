module mod_wofost_potential_shadow_state
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_wofost_actual_biomass_state, only: wofost_actual_biomass_state_t, WOFOST_BIOMASS_STATE_OK
  use mod_wofost_crop_owner_state, only: wofost_crop_owner_state_t, wofost_b110_reference_compatibility_t, &
       WOFOST_CROP_OWNER_OK
  use mod_wofost_one_day_rate_state_view, only: wofost_one_day_rate_state_view_t, &
       assemble_wofost_one_day_rate_state_view, WOFOST_RATE_STATE_VIEW_OK
  implicit none
  private

  integer, parameter, public :: WOFOST_POTENTIAL_SHADOW_OK = 0
  integer, parameter, public :: WOFOST_POTENTIAL_SHADOW_INVALID_STATE = 1
  integer, parameter, public :: WOFOST_POTENTIAL_SHADOW_INVALID_ACTUAL_OWNER = 2
  integer, parameter, public :: WOFOST_POTENTIAL_SHADOW_INVALID_VIEW = 3

  type, extends(transaction_state_t), public :: wofost_potential_shadow_state_t
    logical :: active = .false.
    type(wofost_actual_biomass_state_t), allocatable :: biomass
    type(wofost_b110_reference_compatibility_t), allocatable :: b110_reference_compatibility
  contains
    procedure :: clone => wofost_potential_shadow_clone
    procedure, public :: validate => wofost_potential_shadow_validate
    procedure, public :: root_biomass => wofost_potential_shadow_root_biomass
    procedure, public :: materialize_owner => wofost_potential_shadow_materialize_owner
    procedure, public :: absorb_owner => wofost_potential_shadow_absorb_owner
    procedure, public :: assemble_rate_state_view => wofost_potential_shadow_assemble_rate_state_view
  end type wofost_potential_shadow_state_t

  public :: initialize_wofost_potential_shadow_from_actual

contains

  integer function wofost_potential_shadow_validate(self) result(status)
    class(wofost_potential_shadow_state_t), intent(in) :: self
    integer :: local_status
    status = WOFOST_POTENTIAL_SHADOW_OK
    if (.not. self%active) then
      if (allocated(self%biomass) .or. allocated(self%b110_reference_compatibility)) then
        status = WOFOST_POTENTIAL_SHADOW_INVALID_STATE
      end if
      return
    end if
    if (.not. allocated(self%biomass)) then
      status = WOFOST_POTENTIAL_SHADOW_INVALID_STATE
      return
    end if
    local_status = self%biomass%validate()
    if (local_status /= WOFOST_BIOMASS_STATE_OK) then
      status = WOFOST_POTENTIAL_SHADOW_INVALID_STATE
      return
    end if
    if (allocated(self%b110_reference_compatibility)) then
      local_status = self%b110_reference_compatibility%validate()
      if (local_status /= WOFOST_CROP_OWNER_OK) then
        status = WOFOST_POTENTIAL_SHADOW_INVALID_STATE
        return
      end if
    end if
  end function wofost_potential_shadow_validate

  subroutine wofost_potential_shadow_clone(self, copy)
    class(wofost_potential_shadow_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(wofost_potential_shadow_state_t :: copy)
    select type (typed => copy)
    type is (wofost_potential_shadow_state_t)
      typed%active = self%active
      if (allocated(self%biomass)) then
        allocate(typed%biomass)
        typed%biomass = self%biomass
      end if
      if (allocated(self%b110_reference_compatibility)) then
        allocate(typed%b110_reference_compatibility)
        typed%b110_reference_compatibility = self%b110_reference_compatibility
      end if
    class default
      error stop 'potential shadow clone failure'
    end select
  end subroutine wofost_potential_shadow_clone

  subroutine initialize_wofost_potential_shadow_from_actual(actual_owner, shadow, status)
    type(wofost_crop_owner_state_t), intent(in) :: actual_owner
    type(wofost_potential_shadow_state_t), intent(out) :: shadow
    integer, intent(out) :: status

    shadow = wofost_potential_shadow_state_t()
    status = WOFOST_POTENTIAL_SHADOW_INVALID_ACTUAL_OWNER
    if (actual_owner%validate() /= WOFOST_CROP_OWNER_OK) return
    if (.not. actual_owner%crop_emerged) then
      status = WOFOST_POTENTIAL_SHADOW_OK
      return
    end if
    shadow%active = .true.
    allocate(shadow%biomass)
    shadow%biomass = actual_owner%biomass
    if (allocated(actual_owner%b110_reference_compatibility)) then
      allocate(shadow%b110_reference_compatibility)
      shadow%b110_reference_compatibility = actual_owner%b110_reference_compatibility
    end if
    status = shadow%validate()
  end subroutine initialize_wofost_potential_shadow_from_actual

  real(real64) function wofost_potential_shadow_root_biomass(self) result(value)
    class(wofost_potential_shadow_state_t), intent(in) :: self
    value = 0.0_real64
    if (self%validate() /= WOFOST_POTENTIAL_SHADOW_OK) return
    if (.not. self%active) return
    value = self%biomass%root_biomass
  end function wofost_potential_shadow_root_biomass

  subroutine wofost_potential_shadow_materialize_owner(self, actual_owner, owner, available, status)
    class(wofost_potential_shadow_state_t), intent(in) :: self
    type(wofost_crop_owner_state_t), intent(in) :: actual_owner
    type(wofost_crop_owner_state_t), intent(out) :: owner
    logical, intent(out) :: available
    integer, intent(out) :: status

    owner = wofost_crop_owner_state_t()
    available = .false.
    status = self%validate()
    if (status /= WOFOST_POTENTIAL_SHADOW_OK) return
    if (actual_owner%validate() /= WOFOST_CROP_OWNER_OK) then
      status = WOFOST_POTENTIAL_SHADOW_INVALID_ACTUAL_OWNER
      return
    end if
    if (.not. self%active) then
      if (actual_owner%crop_emerged) then
        status = WOFOST_POTENTIAL_SHADOW_INVALID_STATE
      end if
      return
    end if
    if (.not. actual_owner%crop_emerged) then
      status = WOFOST_POTENTIAL_SHADOW_INVALID_ACTUAL_OWNER
      return
    end if

    owner%crop_emerged = .true.
    owner%development_stage = actual_owner%development_stage
    allocate(owner%biomass)
    owner%biomass = self%biomass
    if (allocated(actual_owner%evolution_continuation)) then
      allocate(owner%evolution_continuation)
      owner%evolution_continuation = actual_owner%evolution_continuation
    end if
    if (allocated(self%b110_reference_compatibility)) then
      allocate(owner%b110_reference_compatibility)
      owner%b110_reference_compatibility = self%b110_reference_compatibility
    end if
    if (owner%validate() /= WOFOST_CROP_OWNER_OK) then
      owner = wofost_crop_owner_state_t()
      status = WOFOST_POTENTIAL_SHADOW_INVALID_STATE
      return
    end if
    available = .true.
    status = WOFOST_POTENTIAL_SHADOW_OK
  end subroutine wofost_potential_shadow_materialize_owner

  subroutine wofost_potential_shadow_absorb_owner(self, evolved_owner, status)
    class(wofost_potential_shadow_state_t), intent(inout) :: self
    type(wofost_crop_owner_state_t), intent(in) :: evolved_owner
    integer, intent(out) :: status

    status = WOFOST_POTENTIAL_SHADOW_INVALID_STATE
    if (.not. self%active) return
    if (evolved_owner%validate() /= WOFOST_CROP_OWNER_OK .or. .not. evolved_owner%crop_emerged) return
    self%biomass = evolved_owner%biomass
    if (allocated(self%b110_reference_compatibility)) deallocate(self%b110_reference_compatibility)
    if (allocated(evolved_owner%b110_reference_compatibility)) then
      allocate(self%b110_reference_compatibility)
      self%b110_reference_compatibility = evolved_owner%b110_reference_compatibility
    end if
    status = self%validate()
  end subroutine wofost_potential_shadow_absorb_owner

  subroutine wofost_potential_shadow_assemble_rate_state_view(self, actual_owner, stem_area_coefficient, &
       storage_area_coefficient, view, available, status)
    class(wofost_potential_shadow_state_t), intent(in) :: self
    type(wofost_crop_owner_state_t), intent(in) :: actual_owner
    real(real64), intent(in) :: stem_area_coefficient, storage_area_coefficient
    type(wofost_one_day_rate_state_view_t), intent(out) :: view
    logical, intent(out) :: available
    integer, intent(out) :: status
    type(wofost_crop_owner_state_t) :: owner
    integer :: owner_status

    view = wofost_one_day_rate_state_view_t()
    available = .false.
    call self%materialize_owner(actual_owner, owner, available, status)
    if (status /= WOFOST_POTENTIAL_SHADOW_OK .or. .not. available) return
    call assemble_wofost_one_day_rate_state_view(owner, stem_area_coefficient, storage_area_coefficient, &
         view, available, owner_status)
    if (owner_status /= WOFOST_RATE_STATE_VIEW_OK .or. .not. available) then
      view = wofost_one_day_rate_state_view_t()
      status = WOFOST_POTENTIAL_SHADOW_INVALID_VIEW
      return
    end if
    status = WOFOST_POTENTIAL_SHADOW_OK
  end subroutine wofost_potential_shadow_assemble_rate_state_view

end module mod_wofost_potential_shadow_state
