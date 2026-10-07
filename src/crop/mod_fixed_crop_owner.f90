module mod_fixed_crop_owner
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t
  use mod_wofost_rate_table, only: wofost_rate_table_t, WOFOST_RATE_TABLE_OK
  implicit none
  private

  integer, parameter, public :: FIXED_CROP_OK = 0
  integer, parameter, public :: FIXED_CROP_INVALID_STATE = 1
  integer, parameter, public :: FIXED_CROP_INVALID_PARAMETERS = 2
  integer, parameter, public :: FIXED_CROP_INVALID_FORCING = 3
  integer, parameter, public :: FIXED_CROP_TABLE_ERROR = 4

  integer, parameter, public :: FIXED_CROP_IDEV_CALENDAR = 1
  integer, parameter, public :: FIXED_CROP_IDEV_THERMAL = 2

  type, public :: fixed_crop_parameters_t
    integer :: development_mode = FIXED_CROP_IDEV_CALENDAR
    integer :: lifecycle_days = 0
    real(real64) :: base_temperature_c = 0.0_real64
    real(real64) :: temperature_sum_emergence_to_anthesis = 0.0_real64
    real(real64) :: temperature_sum_anthesis_to_maturity = 0.0_real64
    type(wofost_rate_table_t) :: leaf_area_by_dvs
    logical :: root_biomass_enabled = .false.
    type(wofost_rate_table_t) :: root_biomass_by_dvs
  contains
    procedure, public :: ready => fixed_crop_parameters_ready
  end type fixed_crop_parameters_t

  type, extends(transaction_state_t), public :: fixed_crop_owner_state_t
    logical :: crop_emerged = .false.
    real(real64) :: development_stage = 0.0_real64
    real(real64) :: temperature_sum = 0.0_real64
    real(real64) :: leaf_area_index = 0.0_real64
    real(real64) :: root_biomass = 0.0_real64
  contains
    procedure :: clone => fixed_crop_owner_clone
    procedure, public :: validate => fixed_crop_owner_validate
  end type fixed_crop_owner_state_t

  type, public :: fixed_crop_daily_forcing_t
    real(real64) :: average_temperature_c = 0.0_real64
  end type fixed_crop_daily_forcing_t

  type, public :: fixed_crop_daily_diagnostics_t
    real(real64) :: temperature_sum_increment = 0.0_real64
    real(real64) :: development_increment = 0.0_real64
    real(real64) :: root_growth = 0.0_real64
    real(real64) :: root_death = 0.0_real64
    logical :: candidate_built = .false.
  end type fixed_crop_daily_diagnostics_t

  public :: initialize_fixed_crop_owner
  public :: evaluate_fixed_crop_daily_candidate

contains

  logical function fixed_crop_parameters_ready(self) result(ready)
    class(fixed_crop_parameters_t), intent(in) :: self
    ready = .false.
    if (self%development_mode /= FIXED_CROP_IDEV_CALENDAR .and. self%development_mode /= FIXED_CROP_IDEV_THERMAL) return
    if (.not. self%leaf_area_by_dvs%ready()) return
    if (self%development_mode == FIXED_CROP_IDEV_CALENDAR) then
      if (self%lifecycle_days < 1 .or. self%lifecycle_days > 366) return
    else
      if (.not. ieee_is_finite(self%base_temperature_c)) return
      if (.not. ieee_is_finite(self%temperature_sum_emergence_to_anthesis) .or. &
          self%temperature_sum_emergence_to_anthesis <= 0.0_real64) return
      if (.not. ieee_is_finite(self%temperature_sum_anthesis_to_maturity) .or. &
          self%temperature_sum_anthesis_to_maturity <= 0.0_real64) return
    end if
    if (self%root_biomass_enabled .and. .not. self%root_biomass_by_dvs%ready()) return
    ready = .true.
  end function fixed_crop_parameters_ready

  integer function fixed_crop_owner_validate(self) result(status)
    class(fixed_crop_owner_state_t), intent(in) :: self
    status = FIXED_CROP_INVALID_STATE
    if (.not. ieee_is_finite(self%development_stage) .or. self%development_stage < 0.0_real64 .or. &
        self%development_stage > 2.0_real64) return
    if (.not. ieee_is_finite(self%temperature_sum) .or. self%temperature_sum < 0.0_real64) return
    if (.not. ieee_is_finite(self%leaf_area_index) .or. self%leaf_area_index < 0.0_real64) return
    if (.not. ieee_is_finite(self%root_biomass) .or. self%root_biomass < 0.0_real64) return
    status = FIXED_CROP_OK
  end function fixed_crop_owner_validate

  subroutine fixed_crop_owner_clone(self, copy)
    class(fixed_crop_owner_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fixed_crop_owner_state_t :: copy)
    select type (typed => copy)
    type is (fixed_crop_owner_state_t)
      typed%crop_emerged = self%crop_emerged
      typed%development_stage = self%development_stage
      typed%temperature_sum = self%temperature_sum
      typed%leaf_area_index = self%leaf_area_index
      typed%root_biomass = self%root_biomass
    class default
      error stop 'fixed crop owner clone failure'
    end select
  end subroutine fixed_crop_owner_clone

  subroutine initialize_fixed_crop_owner(parameters, crop_emerged, state, status)
    type(fixed_crop_parameters_t), intent(in) :: parameters
    logical, intent(in) :: crop_emerged
    type(fixed_crop_owner_state_t), intent(out) :: state
    integer, intent(out) :: status
    integer :: table_status

    state = fixed_crop_owner_state_t()
    status = FIXED_CROP_INVALID_PARAMETERS
    if (.not. parameters%ready()) return
    state%crop_emerged = crop_emerged
    state%development_stage = 0.0_real64
    state%temperature_sum = 0.0_real64
    call parameters%leaf_area_by_dvs%evaluate(0.0_real64, state%leaf_area_index, table_status)
    if (table_status /= WOFOST_RATE_TABLE_OK .or. state%leaf_area_index < 0.0_real64) then
      status = FIXED_CROP_TABLE_ERROR
      return
    end if
    if (parameters%root_biomass_enabled) then
      call parameters%root_biomass_by_dvs%evaluate(0.0_real64, state%root_biomass, table_status)
      if (table_status /= WOFOST_RATE_TABLE_OK .or. state%root_biomass < 0.0_real64) then
        status = FIXED_CROP_TABLE_ERROR
        return
      end if
    end if
    status = state%validate()
  end subroutine initialize_fixed_crop_owner

  subroutine evaluate_fixed_crop_daily_candidate(parameters, committed, forcing, candidate, diagnostics, status)
    type(fixed_crop_parameters_t), intent(in) :: parameters
    type(fixed_crop_owner_state_t), intent(in) :: committed
    type(fixed_crop_daily_forcing_t), intent(in) :: forcing
    type(fixed_crop_owner_state_t), intent(out) :: candidate
    type(fixed_crop_daily_diagnostics_t), intent(out) :: diagnostics
    integer, intent(out) :: status
    real(real64) :: dtsum, dvr, old_root
    integer :: table_status

    candidate = committed
    diagnostics = fixed_crop_daily_diagnostics_t()
    status = FIXED_CROP_INVALID_PARAMETERS
    if (.not. parameters%ready()) return
    status = committed%validate()
    if (status /= FIXED_CROP_OK) return
    if (.not. committed%crop_emerged) then
      diagnostics%candidate_built = .true.
      return
    end if
    status = FIXED_CROP_INVALID_FORCING
    if (.not. ieee_is_finite(forcing%average_temperature_c)) return

    ! B1.11 fixed.f90 always accumulates TSUM from max(0,TAV-TBASE),
    ! including IDEV=1 where DVS itself advances by the calendar clock.
    dtsum = max(0.0_real64, forcing%average_temperature_c - parameters%base_temperature_c)
    if (parameters%development_mode == FIXED_CROP_IDEV_CALENDAR) then
      dvr = 2.0_real64 / real(parameters%lifecycle_days, real64)
    else if (committed%development_stage < 1.0_real64) then
      dvr = dtsum / parameters%temperature_sum_emergence_to_anthesis
    else
      dvr = dtsum / parameters%temperature_sum_anthesis_to_maturity
    end if

    candidate%development_stage = min(committed%development_stage + dvr, 2.0_real64)
    candidate%temperature_sum = committed%temperature_sum + dtsum
    call parameters%leaf_area_by_dvs%evaluate(candidate%development_stage, candidate%leaf_area_index, table_status)
    if (table_status /= WOFOST_RATE_TABLE_OK .or. candidate%leaf_area_index < 0.0_real64) then
      status = FIXED_CROP_TABLE_ERROR
      return
    end if

    if (parameters%root_biomass_enabled) then
      old_root = committed%root_biomass
      call parameters%root_biomass_by_dvs%evaluate(candidate%development_stage, candidate%root_biomass, table_status)
      if (table_status /= WOFOST_RATE_TABLE_OK .or. candidate%root_biomass < 0.0_real64) then
        status = FIXED_CROP_TABLE_ERROR
        return
      end if
      diagnostics%root_growth = max(0.0_real64, candidate%root_biomass - old_root)
      diagnostics%root_death = abs(min(0.0_real64, candidate%root_biomass - old_root))
    end if

    diagnostics%temperature_sum_increment = dtsum
    diagnostics%development_increment = dvr
    status = candidate%validate()
    diagnostics%candidate_built = status == FIXED_CROP_OK
  end subroutine evaluate_fixed_crop_daily_candidate

end module mod_fixed_crop_owner
