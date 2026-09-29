program test_redistribution
  use, intrinsic::iso_fortran_env,only:real64
  use mod_ppa_wu05a4_redistribution
  implicit none
  type(redistribution_candidate)::c
  real(real64)::d(3),p(3),v(3),l(3),q(3),o(3),rel(3)
  d=[0.25_real64,0.5_real64,0.25_real64]; p=[0.25_real64,0.5_real64,0.25_real64]
  rel=[1.0_real64,1.0_real64,1.0_real64]; v=0.125_real64; l=0.125_real64; q=0.5_real64; o=0.25_real64
  call redistribute_top_excess(0.5_real64,1.0_real64,1.0_real64,rel,p,d,o,v,l,q,q,c)
  call check(c%valid,1)
  call check(abs(c%remaining)<tiny(1.0_real64),2)
  call check(maxval(abs(c%deficit))<tiny(1.0_real64),3)
  call check(maxval(abs(c%vertical_rate-[0.5_real64,0.75_real64,0.5_real64]))<tiny(1.0_real64),4)
  call check(maxval(abs(c%outflow_excess))<tiny(1.0_real64),5)
  ! Source overwrites existing top rates from potentials; it does not add to q.
  call redistribute_top_excess(0.5_real64,1.e-6_real64,1.0_real64,rel,p,d,o,v,l,q,q,c)
  call check(c%valid.and.maxval(abs(c%vertical_rate-q))<tiny(1.0_real64),6)
  ! Reorder: smallest relative deficit receives its capped share first.
  rel=[3.0_real64,2.0_real64,1.0_real64]
  d=[1.0_real64,1.0_real64,0.125_real64]
  call redistribute_top_excess(0.5_real64,1.0_real64,sum(d),rel,p,d,o,v,l,q,q,c)
  call check(c%valid,7)
  call check(abs(c%deficit(3))<tiny(1.0_real64),8)
  call check(abs(sum(d-c%deficit)+c%remaining-1.0_real64)<1.e-14_real64,9)
  p=[1.0_real64,1.0_real64,1.0_real64]
  call redistribute_top_excess(0.5_real64,1.0_real64,sum(d),rel,p,d,o,v,l,q,q,c)
  call check(.not.c%valid.and..not.allocated(c%deficit),10)
  print '(a)','PPA_WU05A4_REDISTRIBUTION_ANALYTIC_ORDER_THRESHOLD=PASS'
  print '(a)','PPA_WU05A4_REDISTRIBUTION_INVALID_ATOMIC=PASS'
contains
  subroutine check(ok,code)
    logical,intent(in)::ok
    integer,intent(in)::code
    if(ok)return
    print *,code
    error stop 1
  end subroutine
end program
