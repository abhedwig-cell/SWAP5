module hybrid_cde_interval_receipt
  use iso_fortran_env, only: real64,real128,int64
  use ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer,parameter,public :: CDE_DAY_OK=0,CDE_DAY_INPUT=1,CDE_DAY_STATE=2,CDE_DAY_BALANCE=3
  real(real64),parameter,public :: CDE_DAY_GUARD=1e-10_real64
  public :: cde_day_begin,cde_day_observe,cde_day_close,cde_day_diagnostics
  logical,save :: active=.false.
  real(real64),save :: initial_stock=0d0
  real(real128),save :: increments(6)=0.0_real128
  integer(int64),save :: observed(6)=0_int64
contains
  subroutine cde_day_begin(stock,status)
    real(real64),intent(in) :: stock
    integer,intent(out) :: status
    status=CDE_DAY_INPUT
    if(.not.ieee_is_finite(stock))return
    if(stock<0d0)return
    status=CDE_DAY_STATE
    if(active)return
    initial_stock=stock;increments=0.0_real128;observed=0_int64;active=.true.
    status=CDE_DAY_OK
  end subroutine

  subroutine cde_day_observe(slot,increment,status)
    integer,intent(in) :: slot
    real(real64),intent(in) :: increment
    integer,intent(out) :: status
    real(real128) :: candidate
    status=CDE_DAY_INPUT
    if(slot<1.or.slot>6.or..not.ieee_is_finite(increment))return
    status=CDE_DAY_STATE
    if(.not.active)return
    status=CDE_DAY_INPUT
    if(observed(slot)==huge(0_int64))return
    candidate=increments(slot)+real(increment,real128)
    if(.not.ieee_is_finite(candidate))return
    increments(slot)=candidate;observed(slot)=observed(slot)+1_int64
    status=CDE_DAY_OK
  end subroutine

  subroutine cde_day_close(stock,ledger,status)
    real(real64),intent(in) :: stock
    real(real64),intent(out) :: ledger(9)
    integer,intent(out) :: status
    real(real64) :: candidate(9)
    ledger=0d0;status=CDE_DAY_INPUT
    if(.not.ieee_is_finite(stock))return
    if(stock<0d0)return
    status=CDE_DAY_STATE
    if(.not.active)return
    candidate(1)=stock;candidate(2)=stock-initial_stock
    candidate(3:8)=real(increments,real64)
    status=CDE_DAY_INPUT
    if(.not.all(ieee_is_finite(candidate(1:8))))return
    candidate(9)=real(sum(real([stock,-initial_stock,-candidate(3:5),candidate(6:8)],real128)),real64)
    if(.not.ieee_is_finite(candidate(9)))return
    status=CDE_DAY_BALANCE
    if(abs(candidate(9))>CDE_DAY_GUARD)return
    ledger=candidate;active=.false.;status=CDE_DAY_OK
  end subroutine

  subroutine cde_day_diagnostics(stock,flow,counts,live)
    real(real64),intent(out) :: stock,flow(6)
    integer(int64),intent(out) :: counts(6)
    logical,intent(out) :: live
    stock=initial_stock;flow=real(increments,real64);counts=observed;live=active
  end subroutine
end module
