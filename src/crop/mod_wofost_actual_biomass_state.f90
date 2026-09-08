module mod_wofost_actual_biomass_state
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t
  implicit none
  private

  integer, parameter, public :: WOFOST_BIOMASS_STATE_OK = 0
  integer, parameter, public :: WOFOST_BIOMASS_STATE_INVALID_ORGAN_BIOMASS = 1
  integer, parameter, public :: WOFOST_BIOMASS_STATE_INVALID_LAIEXP = 2
  integer, parameter, public :: WOFOST_BIOMASS_STATE_COHORT_ALLOCATION_MISMATCH = 3
  integer, parameter, public :: WOFOST_BIOMASS_STATE_COHORT_SHAPE_MISMATCH = 4
  integer, parameter, public :: WOFOST_BIOMASS_STATE_INVALID_COHORT = 5

  type, extends(transaction_state_t), public :: wofost_actual_biomass_state_t
    real(real64) :: root_biomass = 0.0_real64
    real(real64) :: stem_biomass = 0.0_real64
    real(real64) :: storage_biomass = 0.0_real64
    real(real64) :: exponential_leaf_area_index = 0.0_real64
    real(real64), allocatable :: leaf_biomass(:)
    real(real64), allocatable :: specific_leaf_area(:)
    real(real64), allocatable :: leaf_age(:)
  contains
    procedure :: clone => wofost_actual_biomass_clone
    procedure, public :: validate => wofost_actual_biomass_validate
    procedure, public :: active_leaf_cohort_count => wofost_active_leaf_cohort_count
    procedure, public :: living_leaf_biomass => wofost_living_leaf_biomass
    procedure, public :: leaf_area_sum => wofost_leaf_area_sum
    procedure, public :: actual_root_biomass => wofost_actual_root_biomass
  end type wofost_actual_biomass_state_t

contains

  subroutine wofost_actual_biomass_clone(self, copy)
    class(wofost_actual_biomass_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy

    allocate(wofost_actual_biomass_state_t :: copy)
    select type (typed_copy => copy)
    type is (wofost_actual_biomass_state_t)
      typed_copy%root_biomass = self%root_biomass
      typed_copy%stem_biomass = self%stem_biomass
      typed_copy%storage_biomass = self%storage_biomass
      typed_copy%exponential_leaf_area_index = self%exponential_leaf_area_index
      if (allocated(self%leaf_biomass)) typed_copy%leaf_biomass = self%leaf_biomass
      if (allocated(self%specific_leaf_area)) typed_copy%specific_leaf_area = self%specific_leaf_area
      if (allocated(self%leaf_age)) typed_copy%leaf_age = self%leaf_age
    class default
      error stop 'actual WOFOST biomass state: clone allocation failure'
    end select
  end subroutine wofost_actual_biomass_clone

  integer function wofost_actual_biomass_validate(self) result(status)
    class(wofost_actual_biomass_state_t), intent(in) :: self
    logical :: has_leaf, has_sla, has_age

    status = WOFOST_BIOMASS_STATE_OK

    if (.not. valid_nonnegative(self%root_biomass) .or. &
        .not. valid_nonnegative(self%stem_biomass) .or. &
        .not. valid_nonnegative(self%storage_biomass)) then
      status = WOFOST_BIOMASS_STATE_INVALID_ORGAN_BIOMASS
      return
    end if

    if (.not. valid_nonnegative(self%exponential_leaf_area_index)) then
      status = WOFOST_BIOMASS_STATE_INVALID_LAIEXP
      return
    end if

    has_leaf = allocated(self%leaf_biomass)
    has_sla = allocated(self%specific_leaf_area)
    has_age = allocated(self%leaf_age)
    if ((has_leaf .neqv. has_sla) .or. (has_leaf .neqv. has_age)) then
      status = WOFOST_BIOMASS_STATE_COHORT_ALLOCATION_MISMATCH
      return
    end if

    if (.not. has_leaf) return

    if (size(self%leaf_biomass) /= size(self%specific_leaf_area) .or. &
        size(self%leaf_biomass) /= size(self%leaf_age)) then
      status = WOFOST_BIOMASS_STATE_COHORT_SHAPE_MISMATCH
      return
    end if

    if (.not. all(ieee_is_finite(self%leaf_biomass)) .or. &
        .not. all(ieee_is_finite(self%specific_leaf_area)) .or. &
        .not. all(ieee_is_finite(self%leaf_age)) .or. &
        any(self%leaf_biomass < 0.0_real64) .or. &
        any(self%specific_leaf_area < 0.0_real64) .or. &
        any(self%leaf_age < 0.0_real64)) then
      status = WOFOST_BIOMASS_STATE_INVALID_COHORT
      return
    end if
  end function wofost_actual_biomass_validate

  integer function wofost_active_leaf_cohort_count(self) result(count)
    class(wofost_actual_biomass_state_t), intent(in) :: self
    if (allocated(self%leaf_biomass)) then
      count = size(self%leaf_biomass)
    else
      count = 0
    end if
  end function wofost_active_leaf_cohort_count

  real(real64) function wofost_living_leaf_biomass(self) result(value)
    class(wofost_actual_biomass_state_t), intent(in) :: self
    integer :: i

    value = 0.0_real64
    if (.not. allocated(self%leaf_biomass)) return
    do i = 1, size(self%leaf_biomass)
      value = value + self%leaf_biomass(i)
    end do
  end function wofost_living_leaf_biomass

  real(real64) function wofost_leaf_area_sum(self) result(value)
    class(wofost_actual_biomass_state_t), intent(in) :: self
    integer :: i

    value = 0.0_real64
    if (.not. allocated(self%leaf_biomass) .or. .not. allocated(self%specific_leaf_area)) return
    if (size(self%leaf_biomass) /= size(self%specific_leaf_area)) return
    do i = 1, size(self%leaf_biomass)
      value = value + self%leaf_biomass(i) * self%specific_leaf_area(i)
    end do
  end function wofost_leaf_area_sum

  real(real64) function wofost_actual_root_biomass(self) result(value)
    class(wofost_actual_biomass_state_t), intent(in) :: self
    value = self%root_biomass
  end function wofost_actual_root_biomass

  logical function valid_nonnegative(value) result(valid)
    real(real64), intent(in) :: value
    valid = ieee_is_finite(value) .and. value >= 0.0_real64
  end function valid_nonnegative

end module mod_wofost_actual_biomass_state
