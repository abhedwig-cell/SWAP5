module mod_timestep_numerical_profile
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  integer, parameter, public :: TIMESTEP_PROFILE_INVALID = 0
  integer, parameter, public :: TIMESTEP_PROFILE_LEGACY_NUMERICS = 1
  integer, parameter, public :: TIMESTEP_PROFILE_AUTO_REFERENCE = 2

  integer, parameter, public :: TIMESTEP_PROFILE_STATUS_OK = 0
  integer, parameter, public :: TIMESTEP_PROFILE_STATUS_INVALID = 1
  integer, parameter, public :: TIMESTEP_PROFILE_STATUS_CONTROLLER_UNAVAILABLE = 2

  type, public :: legacy_numerics_profile_t
    real(real64) :: dtmin = 0.0_real64
    real(real64) :: dtmax = 0.0_real64
    real(real64) :: initial_dt = 0.0_real64
    integer :: numbit_crit = 0
    integer :: maxit = 0
    real(real64) :: fact_increase = 0.0_real64
    real(real64) :: fact_decrease = 0.0_real64
    real(real64) :: fact_failure = 0.0_real64
  end type legacy_numerics_profile_t

  type, public :: auto_reference_profile_t
    character(len=48) :: controller_id = ''
    real(real64) :: internal_retry_floor = 0.0_real64
    logical :: expert_ceiling_present = .false.
    real(real64) :: expert_ceiling = 0.0_real64
    logical :: controller_admitted = .false.
  end type auto_reference_profile_t

  type, public :: timestep_numerical_profile_t
    integer :: kind = TIMESTEP_PROFILE_INVALID
    type(legacy_numerics_profile_t) :: legacy
    type(auto_reference_profile_t) :: automatic
  contains
    procedure, public :: validate => timestep_profile_validate
    procedure, public :: execution_ready => timestep_profile_execution_ready
  end type timestep_numerical_profile_t

  public :: make_legacy_numerics_profile
  public :: make_auto_reference_profile

contains

  pure function make_legacy_numerics_profile(dtmin, dtmax, initial_dt, numbit_crit, maxit, &
       fact_increase, fact_decrease, fact_failure) result(profile)
    real(real64), intent(in) :: dtmin, dtmax, initial_dt
    integer, intent(in) :: numbit_crit, maxit
    real(real64), intent(in) :: fact_increase, fact_decrease, fact_failure
    type(timestep_numerical_profile_t) :: profile

    profile%kind = TIMESTEP_PROFILE_LEGACY_NUMERICS
    profile%legacy%dtmin = dtmin
    profile%legacy%dtmax = dtmax
    profile%legacy%initial_dt = initial_dt
    profile%legacy%numbit_crit = numbit_crit
    profile%legacy%maxit = maxit
    profile%legacy%fact_increase = fact_increase
    profile%legacy%fact_decrease = fact_decrease
    profile%legacy%fact_failure = fact_failure
  end function make_legacy_numerics_profile

  pure function make_auto_reference_profile(controller_id, internal_retry_floor, expert_ceiling_present, &
       expert_ceiling, controller_admitted) result(profile)
    character(len=*), intent(in) :: controller_id
    real(real64), intent(in) :: internal_retry_floor
    logical, intent(in) :: expert_ceiling_present
    real(real64), intent(in) :: expert_ceiling
    logical, intent(in), optional :: controller_admitted
    type(timestep_numerical_profile_t) :: profile

    profile%kind = TIMESTEP_PROFILE_AUTO_REFERENCE
    profile%automatic%controller_id = controller_id
    profile%automatic%internal_retry_floor = internal_retry_floor
    profile%automatic%expert_ceiling_present = expert_ceiling_present
    profile%automatic%expert_ceiling = expert_ceiling
    profile%automatic%controller_admitted = .false.
    if (present(controller_admitted)) profile%automatic%controller_admitted = controller_admitted
  end function make_auto_reference_profile

  pure subroutine timestep_profile_validate(self, status)
    class(timestep_numerical_profile_t), intent(in) :: self
    integer, intent(out) :: status

    status = TIMESTEP_PROFILE_STATUS_INVALID

    select case (self%kind)
    case (TIMESTEP_PROFILE_LEGACY_NUMERICS)
      if (.not. all(ieee_is_finite([self%legacy%dtmin, self%legacy%dtmax, self%legacy%initial_dt, &
           self%legacy%fact_increase, self%legacy%fact_decrease, self%legacy%fact_failure]))) return
      if (self%legacy%dtmin <= 0.0_real64) return
      if (self%legacy%dtmax < self%legacy%dtmin) return
      if (self%legacy%initial_dt < self%legacy%dtmin .or. self%legacy%initial_dt > self%legacy%dtmax) return
      if (self%legacy%numbit_crit < 0) return
      if (self%legacy%maxit <= 0 .or. self%legacy%numbit_crit > self%legacy%maxit) return
      if (self%legacy%fact_increase < 1.0_real64) return
      if (self%legacy%fact_decrease <= 0.0_real64 .or. self%legacy%fact_decrease > 1.0_real64) return
      if (self%legacy%fact_failure <= 1.0_real64) return
      status = TIMESTEP_PROFILE_STATUS_OK

    case (TIMESTEP_PROFILE_AUTO_REFERENCE)
      if (len_trim(self%automatic%controller_id) == 0) return
      if (.not. ieee_is_finite(self%automatic%internal_retry_floor)) return
      if (self%automatic%internal_retry_floor <= 0.0_real64) return
      if (self%automatic%expert_ceiling_present) then
        if (.not. ieee_is_finite(self%automatic%expert_ceiling)) return
        if (self%automatic%expert_ceiling <= self%automatic%internal_retry_floor) return
      end if
      status = TIMESTEP_PROFILE_STATUS_OK

    case default
      return
    end select
  end subroutine timestep_profile_validate

  pure logical function timestep_profile_execution_ready(self) result(ready)
    class(timestep_numerical_profile_t), intent(in) :: self
    integer :: status

    call self%validate(status)
    ready = .false.
    if (status /= TIMESTEP_PROFILE_STATUS_OK) return

    select case (self%kind)
    case (TIMESTEP_PROFILE_LEGACY_NUMERICS)
      ready = .true.
    case (TIMESTEP_PROFILE_AUTO_REFERENCE)
      ready = self%automatic%controller_admitted
    end select
  end function timestep_profile_execution_ready

end module mod_timestep_numerical_profile
