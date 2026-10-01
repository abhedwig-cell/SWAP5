module mod_ppa_wu05_perch19_exchange_reduction
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PERCH19_ACTION_NONE=0
  integer, parameter, public :: PERCH19_ACTION_REDUCE_TIMESTEP=1
  integer, parameter, public :: PERCH19_ACTION_ESCALATE_AND_RESET_TIMESTEP=2
  integer, parameter, public :: PERCH19_ACTION_EXHAUSTED=3

  integer, parameter :: MAX_REDUCTION_LEVEL=3
  integer, parameter :: RECOVERY_ACCEPTED_STEPS=10

  type, public :: perch19_exchange_reduction_persistence_t
    integer :: reduction_level=0
    integer :: recovery_accepted_steps=0
    real(real64) :: last_dt=0.0_real64
  end type perch19_exchange_reduction_persistence_t

  type, public :: perch19_exchange_reduction_state_t
    integer :: reduction_level=0
    integer :: recovery_accepted_steps=0
    real(real64) :: last_dt=0.0_real64
  contains
    procedure, public :: initialize => perch19_initialize
    procedure, public :: valid => perch19_valid
    procedure, public :: factor => perch19_factor
    procedure, public :: on_nonconvergence => perch19_on_nonconvergence
    procedure, public :: on_accept => perch19_on_accept
    procedure, public :: export_persistence => perch19_export_persistence
    procedure, public :: restore_persistence => perch19_restore_persistence
  end type perch19_exchange_reduction_state_t

contains

  subroutine perch19_initialize(self,initial_dt,ok)
    class(perch19_exchange_reduction_state_t),intent(inout)::self
    real(real64),intent(in)::initial_dt
    logical,intent(out)::ok

    self%reduction_level=0
    self%recovery_accepted_steps=0
    self%last_dt=0.0_real64
    ok=ieee_is_finite(initial_dt) .and. initial_dt>0.0_real64
    if(.not.ok)return
    self%last_dt=initial_dt
  end subroutine perch19_initialize

  pure logical function perch19_valid(self) result(ok)
    class(perch19_exchange_reduction_state_t),intent(in)::self
    ok=self%reduction_level>=0 .and. self%reduction_level<=MAX_REDUCTION_LEVEL .and. &
         self%recovery_accepted_steps>=0 .and. self%recovery_accepted_steps<=RECOVERY_ACCEPTED_STEPS .and. &
         ieee_is_finite(self%last_dt) .and. self%last_dt>0.0_real64
  end function perch19_valid

  pure real(real64) function perch19_factor(self) result(value)
    class(perch19_exchange_reduction_state_t),intent(in)::self
    if(.not.self%valid())then
      value=0.0_real64
      return
    end if
    value=0.1_real64**self%reduction_level
  end function perch19_factor

  subroutine perch19_on_nonconvergence(self,at_min_dt,current_dt,dtmin,dtmax,action,next_dt,ok)
    class(perch19_exchange_reduction_state_t),intent(inout)::self
    logical,intent(in)::at_min_dt
    real(real64),intent(in)::current_dt,dtmin,dtmax
    integer,intent(out)::action
    real(real64),intent(out)::next_dt
    logical,intent(out)::ok

    action=PERCH19_ACTION_EXHAUSTED
    next_dt=current_dt
    ok=.false.
    if(.not.self%valid())return
    if(.not.ieee_is_finite(current_dt) .or. .not.ieee_is_finite(dtmin) .or. .not.ieee_is_finite(dtmax))return
    if(current_dt<=0.0_real64 .or. dtmin<=0.0_real64 .or. dtmax<dtmin)return

    if(.not.at_min_dt)then
      action=PERCH19_ACTION_REDUCE_TIMESTEP
      ok=.true.
      return
    end if

    if(self%reduction_level>=MAX_REDUCTION_LEVEL)then
      action=PERCH19_ACTION_EXHAUSTED
      ok=.true.
      return
    end if

    self%reduction_level=self%reduction_level+1
    self%recovery_accepted_steps=0
    self%last_dt=current_dt
    next_dt=sqrt(dtmin*dtmax)
    action=PERCH19_ACTION_ESCALATE_AND_RESET_TIMESTEP
    ok=.true.
  end subroutine perch19_on_nonconvergence

  subroutine perch19_on_accept(self,current_dt,reduced,ok)
    class(perch19_exchange_reduction_state_t),intent(inout)::self
    real(real64),intent(in)::current_dt
    logical,intent(out)::reduced,ok

    reduced=.false.
    ok=.false.
    if(.not.self%valid())return
    if(.not.ieee_is_finite(current_dt) .or. current_dt<=0.0_real64)return

    if(self%reduction_level>0)then
      if(self%recovery_accepted_steps<RECOVERY_ACCEPTED_STEPS) &
           self%recovery_accepted_steps=self%recovery_accepted_steps+1
      if(current_dt>self%last_dt .or. self%recovery_accepted_steps>=RECOVERY_ACCEPTED_STEPS)then
        self%last_dt=current_dt
        self%recovery_accepted_steps=0
        self%reduction_level=self%reduction_level-1
        reduced=.true.
      end if
    end if
    ok=.true.
  end subroutine perch19_on_accept

  subroutine perch19_export_persistence(self,persistence,ok)
    class(perch19_exchange_reduction_state_t),intent(in)::self
    type(perch19_exchange_reduction_persistence_t),intent(out)::persistence
    logical,intent(out)::ok

    persistence=perch19_exchange_reduction_persistence_t()
    ok=self%valid()
    if(.not.ok)return
    persistence%reduction_level=self%reduction_level
    persistence%recovery_accepted_steps=self%recovery_accepted_steps
    persistence%last_dt=self%last_dt
  end subroutine perch19_export_persistence

  subroutine perch19_restore_persistence(self,persistence,ok)
    class(perch19_exchange_reduction_state_t),intent(inout)::self
    type(perch19_exchange_reduction_persistence_t),intent(in)::persistence
    logical,intent(out)::ok

    self%reduction_level=persistence%reduction_level
    self%recovery_accepted_steps=persistence%recovery_accepted_steps
    self%last_dt=persistence%last_dt
    ok=self%valid()
    if(.not.ok)then
      self%reduction_level=0
      self%recovery_accepted_steps=0
      self%last_dt=0.0_real64
    end if
  end subroutine perch19_restore_persistence

end module mod_ppa_wu05_perch19_exchange_reduction
