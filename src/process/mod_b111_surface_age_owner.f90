! Isolated candidate surface-age persistent owner; not wired into production.
module mod_b111_surface_age_owner
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_b111_surface_age_budget, only: surface_age_request_t, surface_age_receipt_t, &
       advance_surface_age_budget, SURFACE_AGE_OK
  implicit none
  private
  integer, parameter, public :: AGE_OWNER_OK=0, AGE_OWNER_REJECTED=1
  type, public :: surface_age_owner_t
    private
    real(real64) :: time_day=0.0_real64, depth_cm=0.0_real64, stock_cm_day=0.0_real64
    integer(int64) :: identity=0_int64, revision=0_int64
    logical :: initialized=.false.
  end type
  type, public :: surface_age_restart_t
    private
    integer :: schema=1
    type(surface_age_owner_t) :: saved
  end type
  public :: initialize_surface_age_owner, snapshot_surface_age_owner
  public :: advance_surface_age_owner, export_surface_age_restart, restore_surface_age_restart
  public :: reconstruct_surface_age_owner
contains
  pure subroutine initialize_surface_age_owner(identity,time_day,depth_cm,age_day,state,status)
    integer(int64),intent(in)::identity
    real(real64),intent(in)::time_day,depth_cm,age_day
    type(surface_age_owner_t),intent(out)::state
    integer,intent(out)::status
    state=surface_age_owner_t()
    status=AGE_OWNER_REJECTED
    if(identity<=0_int64) return
    if(.not.all(ieee_is_finite([time_day,depth_cm,age_day])))return
    if(abs(time_day)>1.0e8_real64.or.depth_cm<0.0_real64.or.depth_cm>1.0e6_real64) return
    if(age_day<0.0_real64.or.age_day>1.0e6_real64) return
    if(depth_cm>0.0_real64) then
      if(age_day>1.0e12_real64/depth_cm)return
    end if
    state%identity=identity
    state%time_day=time_day
    state%depth_cm=depth_cm
    state%stock_cm_day=depth_cm*age_day
    state%initialized=.true.
    status=AGE_OWNER_OK
  end subroutine
  pure subroutine snapshot_surface_age_owner(state,time_day,depth_cm,stock_cm_day,revision,valid,identity)
    type(surface_age_owner_t),intent(in)::state
    real(real64),intent(out)::time_day,depth_cm,stock_cm_day
    integer(int64),intent(out)::revision
    logical,intent(out)::valid
    integer(int64),intent(out),optional::identity
    if(present(identity))identity=state%identity
    time_day=state%time_day
    depth_cm=state%depth_cm
    stock_cm_day=state%stock_cm_day
    revision=state%revision
    valid=state%initialized
  end subroutine
  pure subroutine advance_surface_age_owner(state,q,candidate,receipt,status)
    type(surface_age_owner_t),intent(in)::state
    type(surface_age_request_t),intent(in)::q
    type(surface_age_owner_t),intent(out)::candidate
    type(surface_age_receipt_t),intent(out)::receipt
    integer,intent(out)::status
    real(real64)::scale
    type(surface_age_request_t)::trial_request
    candidate=state
    receipt=surface_age_receipt_t()
    status=AGE_OWNER_REJECTED
    if(.not.state%initialized.or.state%revision>=huge(state%revision))return
    scale=max(1.0_real64,state%depth_cm,q%pond_start_cm)
    if(abs(state%depth_cm-q%pond_start_cm)>1.0e-12_real64*scale)return
    if(.not.ieee_is_finite(q%dt_day))return
    if(q%dt_day>1.0e8_real64-abs(state%time_day))return
    ! The persistent owner, not a potentially stale caller, supplies age stock.
    trial_request=q
    trial_request%pond_age_stock_cm_day=state%stock_cm_day
    call advance_surface_age_budget(trial_request,receipt)
    if(receipt%status/=SURFACE_AGE_OK)return
    candidate%time_day=state%time_day+q%dt_day
    candidate%depth_cm=q%pond_end_cm
    candidate%stock_cm_day=receipt%pond_end_stock_cm_day
    candidate%revision=state%revision+1_int64
    status=AGE_OWNER_OK
  end subroutine
  pure subroutine export_surface_age_restart(state,payload,status)
    type(surface_age_owner_t),intent(in)::state
    type(surface_age_restart_t),intent(out)::payload
    integer,intent(out)::status
    payload=surface_age_restart_t()
    status=AGE_OWNER_REJECTED
    if(.not.state%initialized)return
    payload%saved=state
    status=AGE_OWNER_OK
  end subroutine
  pure subroutine restore_surface_age_restart(payload,expected_identity,state,status)
    type(surface_age_restart_t),intent(in)::payload
    integer(int64),intent(in)::expected_identity
    type(surface_age_owner_t),intent(out)::state
    integer,intent(out)::status
    state=surface_age_owner_t()
    status=AGE_OWNER_REJECTED
    if(payload%schema/=1.or..not.payload%saved%initialized)return
    if(payload%saved%identity/=expected_identity.or.expected_identity<=0_int64)return
    if(.not.all(ieee_is_finite([payload%saved%time_day,payload%saved%depth_cm, &
        payload%saved%stock_cm_day])))return
    if(payload%saved%depth_cm<0.0_real64.or.payload%saved%stock_cm_day<0.0_real64)return
    if(payload%saved%depth_cm<=0.0_real64.and.payload%saved%stock_cm_day>0.0_real64)return
    if(payload%saved%revision<0_int64)return
    state=payload%saved
    status=AGE_OWNER_OK
  end subroutine
  pure subroutine reconstruct_surface_age_owner(identity,revision,time_day,depth_cm,stock_cm_day,state,status)
    integer(int64),intent(in)::identity,revision
    real(real64),intent(in)::time_day,depth_cm,stock_cm_day
    type(surface_age_owner_t),intent(out)::state
    integer,intent(out)::status
    state=surface_age_owner_t()
    status=AGE_OWNER_REJECTED
    if(identity<=0_int64.or.revision<0_int64)return
    if(.not.all(ieee_is_finite([time_day,depth_cm,stock_cm_day])))return
    if(abs(time_day)>1.0e8_real64.or.depth_cm<0.0_real64.or.depth_cm>1.0e6_real64)return
    if(stock_cm_day<0.0_real64.or.stock_cm_day>1.0e12_real64)return
    if(depth_cm<=0.0_real64.and.stock_cm_day>0.0_real64)return
    state%identity=identity
    state%revision=revision
    state%time_day=time_day
    state%depth_cm=depth_cm
    state%stock_cm_day=stock_cm_day
    state%initialized=.true.
    status=AGE_OWNER_OK
  end subroutine
end module mod_b111_surface_age_owner
