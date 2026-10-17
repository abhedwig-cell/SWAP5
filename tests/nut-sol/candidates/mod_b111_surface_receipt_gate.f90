! Experimental acceptance gate for water-owner gross surface receipts.
! No committed water/chemical state and no inferred gross quantities.
module mod_b111_surface_receipt_gate
 use iso_fortran_env, only: real64
 use ieee_arithmetic, only: ieee_is_finite
 implicit none
 private
 integer,parameter,public :: SURFACE_RECEIPT_OK=0,SURFACE_RECEIPT_MISSING=1, &
      SURFACE_RECEIPT_INVALID=2,SURFACE_RECEIPT_BALANCE=3
 type,public :: surface_gross_receipt_t
  logical :: accepted=.false.
  logical :: gross_available=.false.
  real(real64) :: t0=0d0,t1=0d0,depth_begin=0d0,depth_end=0d0
  real(real64) :: qtop=0d0,rain=0d0,irrigation=0d0,runon=0d0
  real(real64) :: evaporation=0d0,runoff=0d0
 end type
 public :: check_surface_gross_receipt
contains
 pure subroutine check_surface_gross_receipt(s,status,residual)
  type(surface_gross_receipt_t),intent(in)::s
  integer,intent(out)::status
  real(real64),intent(out)::residual
  real(real64)::dt,scale
  residual=0d0
  status=SURFACE_RECEIPT_MISSING
  if(.not.s%accepted.or..not.s%gross_available)return
  status=SURFACE_RECEIPT_INVALID
  if(.not.all(ieee_is_finite([s%t0,s%t1,s%depth_begin,s%depth_end,s%qtop, &
       s%rain,s%irrigation,s%runon,s%evaporation,s%runoff])))return
  if(s%t1<=s%t0.or.abs(s%t0)>1d8.or.abs(s%t1)>1d8)return
  if(min(s%depth_begin,s%depth_end,s%rain,s%irrigation,s%runon,s%evaporation,s%runoff)<0d0)return
  if(maxval(abs([s%depth_begin,s%depth_end,s%qtop,s%rain,s%irrigation,s%runon, &
       s%evaporation,s%runoff]))>1d6)return
  dt=s%t1-s%t0
  if(dt<1d-100.or.dt>1d3)return
  residual=(s%depth_end-s%depth_begin)- &
       (s%rain+s%irrigation+s%runon+s%qtop-s%evaporation-s%runoff)*dt
  status=SURFACE_RECEIPT_BALANCE
  scale=max(1d0,abs(s%depth_begin),abs(s%depth_end), &
       (s%rain+s%irrigation+s%runon+abs(s%qtop)+s%evaporation+s%runoff)*dt)
  if(abs(residual)>max(1d-10,4096d0*epsilon(1d0)*scale))return
  status=SURFACE_RECEIPT_OK
 end subroutine
end module
