module mod_interception_source_window_runtime
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: INTWIN_OK=0, INTWIN_INVALID=1, INTWIN_MISMATCH=2, INTWIN_ORDER=3
  integer, parameter, public :: INTWIN_RESTART_SCHEMA=1

  type, public :: interception_source_window_t
    private
    integer(int64) :: id=0_int64
    real(real64) :: t0=0.0_real64, t1=0.0_real64, aggregate=0.0_real64
  contains
    procedure, public :: valid => window_valid
    procedure, public :: aggregate_value
    procedure, public :: start_time => window_start_time
    procedure, public :: end_time => window_end_time
  end type

  type, public :: interception_progress_t
    private
    logical :: initialized=.false.
    integer(int64) :: id=0_int64
    real(real64) :: t0=0.0_real64, t1=0.0_real64, accepted_until=0.0_real64
  contains
    procedure, public :: valid_for => progress_valid_for
    procedure, public :: accepted_amount
    procedure, public :: accepted_time
    procedure, public :: complete
  end type

  type, public :: interception_trial_t
    private
    logical :: initialized=.false.
    integer(int64) :: id=0_int64
    real(real64) :: source_t0=0.0_real64, source_t1=0.0_real64
    real(real64) :: origin=0.0_real64, endpoint=0.0_real64, amount=0.0_real64
  contains
    procedure, public :: ready => trial_ready
    procedure, public :: apportioned_amount
  end type

  type, public :: interception_restart_t
    integer :: schema=0
    integer(int64) :: id=0_int64
    real(real64) :: t0=0.0_real64, t1=0.0_real64, aggregate=0.0_real64, accepted_until=0.0_real64
  end type

  public :: initialize_interception_window, initialize_interception_progress
  public :: prepare_interception_trial, accept_interception_trial
  public :: export_interception_restart, restore_interception_restart
contains
  subroutine initialize_interception_window(id,t0,t1,aggregate,window,status)
    integer(int64),intent(in)::id
    real(real64),intent(in)::t0,t1,aggregate
    type(interception_source_window_t),intent(out)::window
    integer,intent(out)::status
    window=interception_source_window_t(); status=INTWIN_INVALID
    if(id<=0_int64 .or. .not.ieee_is_finite(t0) .or. .not.ieee_is_finite(t1)) return
    if(t1<=t0 .or. .not.ieee_is_finite(aggregate) .or. aggregate<0.0_real64) return
    window%id=id; window%t0=t0; window%t1=t1; window%aggregate=aggregate; status=INTWIN_OK
  end subroutine

  subroutine initialize_interception_progress(window,progress,status)
    type(interception_source_window_t),intent(in)::window
    type(interception_progress_t),intent(out)::progress
    integer,intent(out)::status
    progress=interception_progress_t(); status=INTWIN_INVALID
    if(.not.window%valid()) return
    progress%initialized=.true.; progress%id=window%id; progress%t0=window%t0
    progress%t1=window%t1; progress%accepted_until=window%t0; status=INTWIN_OK
  end subroutine

  subroutine prepare_interception_trial(window,progress,endpoint,trial,status)
    type(interception_source_window_t),intent(in)::window
    type(interception_progress_t),intent(in)::progress
    real(real64),intent(in)::endpoint
    type(interception_trial_t),intent(out)::trial
    integer,intent(out)::status
    trial=interception_trial_t(); status=INTWIN_MISMATCH
    if(.not.progress%valid_for(window)) return
    status=INTWIN_ORDER
    if(.not.ieee_is_finite(endpoint) .or. endpoint<=progress%accepted_until .or. endpoint>window%t1) return
    trial%initialized=.true.; trial%id=window%id; trial%source_t0=window%t0; trial%source_t1=window%t1
    trial%origin=progress%accepted_until; trial%endpoint=endpoint
    trial%amount=cumulative(window,endpoint)-cumulative(window,progress%accepted_until)
    status=INTWIN_OK
  end subroutine

  subroutine accept_interception_trial(window,trial,progress,status)
    type(interception_source_window_t),intent(in)::window
    type(interception_trial_t),intent(in)::trial
    type(interception_progress_t),intent(inout)::progress
    integer,intent(out)::status
    status=INTWIN_MISMATCH
    if(.not.progress%valid_for(window) .or. .not.trial%ready()) return
    if(trial%id/=window%id .or. .not.same_time(trial%source_t0,window%t0) .or. .not.same_time(trial%source_t1,window%t1)) return
    status=INTWIN_ORDER
    if(.not.same_time(trial%origin,progress%accepted_until)) return
    progress%accepted_until=trial%endpoint; status=INTWIN_OK
  end subroutine

  subroutine export_interception_restart(window,progress,record,status)
    type(interception_source_window_t),intent(in)::window
    type(interception_progress_t),intent(in)::progress
    type(interception_restart_t),intent(out)::record
    integer,intent(out)::status
    record=interception_restart_t(); status=INTWIN_MISMATCH
    if(.not.progress%valid_for(window)) return
    record%schema=INTWIN_RESTART_SCHEMA; record%id=window%id; record%t0=window%t0; record%t1=window%t1
    record%aggregate=window%aggregate; record%accepted_until=progress%accepted_until; status=INTWIN_OK
  end subroutine

  subroutine restore_interception_restart(record,window,progress,status)
    type(interception_restart_t),intent(in)::record
    type(interception_source_window_t),intent(out)::window
    type(interception_progress_t),intent(out)::progress
    integer,intent(out)::status
    integer::s
    window=interception_source_window_t(); progress=interception_progress_t(); status=INTWIN_INVALID
    if(record%schema/=INTWIN_RESTART_SCHEMA) return
    call initialize_interception_window(record%id,record%t0,record%t1,record%aggregate,window,s)
    if(s/=INTWIN_OK .or. .not.ieee_is_finite(record%accepted_until)) return
    if(record%accepted_until<window%t0 .or. record%accepted_until>window%t1) return
    progress%initialized=.true.; progress%id=window%id; progress%t0=window%t0
    progress%t1=window%t1; progress%accepted_until=record%accepted_until; status=INTWIN_OK
  end subroutine

  pure logical function window_valid(self)
    class(interception_source_window_t),intent(in)::self
    window_valid=self%id>0_int64 .and. ieee_is_finite(self%t0) .and. ieee_is_finite(self%t1) .and. self%t1>self%t0 &
      .and. ieee_is_finite(self%aggregate) .and. self%aggregate>=0.0_real64
  end function
  pure real(real64) function aggregate_value(self)
    class(interception_source_window_t),intent(in)::self; aggregate_value=self%aggregate
  end function
  pure real(real64) function window_start_time(self)
    class(interception_source_window_t),intent(in)::self; window_start_time=self%t0
  end function
  pure real(real64) function window_end_time(self)
    class(interception_source_window_t),intent(in)::self; window_end_time=self%t1
  end function
  pure logical function progress_valid_for(self,window)
    class(interception_progress_t),intent(in)::self; type(interception_source_window_t),intent(in)::window
    progress_valid_for=self%initialized .and. window%valid() .and. self%id==window%id &
      .and. same_time(self%t0,window%t0) .and. same_time(self%t1,window%t1) &
      .and. self%accepted_until>=window%t0 .and. self%accepted_until<=window%t1
  end function
  pure real(real64) function accepted_amount(self,window)
    class(interception_progress_t),intent(in)::self; type(interception_source_window_t),intent(in)::window
    accepted_amount=0.0_real64; if(self%valid_for(window)) accepted_amount=cumulative(window,self%accepted_until)
  end function
  pure real(real64) function accepted_time(self)
    class(interception_progress_t),intent(in)::self; accepted_time=self%accepted_until
  end function
  pure logical function complete(self,window)
    class(interception_progress_t),intent(in)::self; type(interception_source_window_t),intent(in)::window
    complete=self%valid_for(window) .and. same_time(self%accepted_until,window%t1)
  end function
  pure logical function trial_ready(self)
    class(interception_trial_t),intent(in)::self
    trial_ready=self%initialized .and. self%id>0_int64 .and. self%endpoint>self%origin .and. self%amount>=0.0_real64
  end function
  pure real(real64) function apportioned_amount(self)
    class(interception_trial_t),intent(in)::self; apportioned_amount=self%amount
  end function
  pure real(real64) function cumulative(window,t)
    type(interception_source_window_t),intent(in)::window; real(real64),intent(in)::t
    if(same_time(t,window%t0)) then; cumulative=0.0_real64
    else if(same_time(t,window%t1)) then; cumulative=window%aggregate
    else; cumulative=window%aggregate*(t-window%t0)/(window%t1-window%t0); end if
  end function
  pure logical function same_time(a,b)
    real(real64),intent(in)::a,b; real(real64)::scale
    if(.not.ieee_is_finite(a) .or. .not.ieee_is_finite(b)) then; same_time=.false.; return; end if
    scale=max(1.0_real64,abs(a),abs(b)); same_time=abs(a-b)<=64.0_real64*epsilon(1.0_real64)*scale
  end function
end module mod_interception_source_window_runtime
