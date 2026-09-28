program test_outflow
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use mod_ppa_wu05a4_outflow_limit
  implicit none
  real(real64)::dt,total,excess,s(2),u(2),r(2),sr(2),ur(2),rr(2),f,ef
  real(real64)::expected(7),actual(7)
  integer::i
  logical::ok
  do i=1,100000
    dt=real(1+mod(i,8),real64)/16
    s=[real(mod(i,7),real64)/16,0.125_real64]
    u=[0.25_real64,real(mod(i,11),real64)/32]
    r=[0.0_real64,real(mod(i,5),real64)/16]
    total=sum(s)+sum(u)+sum(r)
    excess=real(mod(i,31),real64)/16
    ef=1
    if(excess/dt>1.e-7_real64) then
      if(total>excess) then
        ef=max(0.0_real64,1.0_real64-excess/total)
      else
        ef=0
      end if
    end if
    call run()
    call require(ok,1)
    expected=[ef,ef*s/dt,ef*u/dt,ef*r/dt]; actual=[f,sr,ur,rr]
    call require(all(transfer(expected,[0_int64],7)==transfer(actual,[0_int64],7)),2)
  end do
  dt=1; total=1; excess=1.e-7_real64
  call run()
  call require(ok.and.abs(f-1.0_real64)<tiny(f),3)
  excess=nearest(excess,1.0_real64)
  call run()
  call require(ok.and.f<1,4)
  total=0; excess=1
  call run()
  call require(ok.and.abs(f)<tiny(f),5)
  dt=0
  call run()
  call require(.not.ok,6)
  dt=1; r(1)=-1
  call run()
  call require(.not.ok,7)
  print '(a)','PPA_WU05A4_OUTFLOW_FORMULA_100000=PASS'
  print '(a)','PPA_WU05A4_OUTFLOW_THRESHOLD_INVALID=PASS'
contains
  subroutine run()
    call limit_domain_outflow(dt,total,excess,s,u,r,f,sr,ur,rr,ok)
  end subroutine
  subroutine require(condition,code)
    logical,intent(in)::condition
    integer,intent(in)::code
    if(condition)return
    print *,code
    error stop 1
  end subroutine
end program
