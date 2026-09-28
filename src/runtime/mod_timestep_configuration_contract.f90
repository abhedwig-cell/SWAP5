module mod_timestep_configuration_contract
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: TS_PROFILE_INVALID=0
  integer, parameter, public :: TS_PROFILE_LEGACY_NUMERICS=1
  integer, parameter, public :: TS_PROFILE_AUTO_REFERENCE=2

  type, public :: legacy_numerics_profile_t
    real(real64) :: dtmin=0.0_real64
    real(real64) :: dtmax=0.0_real64
    real(real64) :: initial_dt=0.0_real64
    integer :: numbit_crit=0
    integer :: maxit=0
    real(real64) :: increase_factor=0.0_real64
    real(real64) :: decrease_factor=0.0_real64
    real(real64) :: failure_divisor=0.0_real64
  end type legacy_numerics_profile_t

  type, public :: auto_reference_profile_t
    character(len=32) :: controller_id='not-qualified'
    logical :: expert_ceiling_present=.false.
    real(real64) :: expert_ceiling_dt=0.0_real64
    real(real64) :: solver_retry_floor_dt=0.0_real64
    logical :: controller_admitted=.false.
  end type auto_reference_profile_t

  type, public :: timestep_profile_t
    integer :: profile=TS_PROFILE_INVALID
    type(legacy_numerics_profile_t) :: legacy
    type(auto_reference_profile_t) :: automatic
  end type timestep_profile_t

  public :: valid_timestep_profile
  public :: execution_ready_timestep_profile

contains

  pure logical function valid_timestep_profile(config) result(ok)
    type(timestep_profile_t), intent(in) :: config
    ok=.false.
    select case(config%profile)
    case(TS_PROFILE_LEGACY_NUMERICS)
      ok=valid_legacy(config%legacy)
    case(TS_PROFILE_AUTO_REFERENCE)
      ok=valid_auto(config%automatic)
    case default
      ok=.false.
    end select
  end function

  pure logical function execution_ready_timestep_profile(config) result(ok)
    type(timestep_profile_t), intent(in) :: config
    ok=.false.
    if(.not.valid_timestep_profile(config)) return
    select case(config%profile)
    case(TS_PROFILE_LEGACY_NUMERICS)
      ok=.true.
    case(TS_PROFILE_AUTO_REFERENCE)
      ok=config%automatic%controller_admitted
    end select
  end function

  pure logical function valid_legacy(x) result(ok)
    type(legacy_numerics_profile_t), intent(in) :: x
    real(real64) :: vals(6)
    vals=[x%dtmin,x%dtmax,x%initial_dt,x%increase_factor,x%decrease_factor,x%failure_divisor]
    ok=all(ieee_is_finite(vals))
    if(.not.ok)return
    ok=x%dtmin>0.0_real64 .and. x%dtmax>=x%dtmin .and. &
       x%initial_dt>=x%dtmin .and. x%initial_dt<=x%dtmax .and. &
       x%numbit_crit>=0 .and. x%maxit>0 .and. x%numbit_crit<=x%maxit .and. &
       x%increase_factor>=1.0_real64 .and. x%decrease_factor>0.0_real64 .and. &
       x%decrease_factor<=1.0_real64 .and. x%failure_divisor>1.0_real64
  end function

  pure logical function valid_auto(x) result(ok)
    type(auto_reference_profile_t), intent(in) :: x
    ok=len_trim(x%controller_id)>0 .and. trim(x%controller_id)/='not-qualified'
    if(.not.ok) return
    ok=ieee_is_finite(x%solver_retry_floor_dt) .and. x%solver_retry_floor_dt>0.0_real64
    if(.not.ok) return
    if(x%expert_ceiling_present) then
      ok=ieee_is_finite(x%expert_ceiling_dt) .and. x%expert_ceiling_dt>x%solver_retry_floor_dt
    end if
  end function

end module mod_timestep_configuration_contract
