program test_inflow_limit
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use mod_ppa_wu05a4_inflow_limit
  implicit none
  real(real64) :: s,v,g,dt,tv,tl,it,mt,ot,ip(2),mp(2),ir(2),mr(2),tr(2),f,tmp,mx,ex
  real(real64) :: incoming,etmp,emax,ef,eex,etr(2),eir(2),emr(2)
  integer :: i
  logical :: ok
  do i=1,100000
    dt=real(1+mod(i,8),real64)/16
    s=real(mod(i,19),real64)/16; v=1; g=0.25_real64
    tv=real(mod(i,3),real64)/32; tl=real(mod(i,5),real64)/64
    ip=[real(mod(i,7),real64)/32,0.125_real64]; mp=[0.25_real64,real(mod(i,11),real64)/32]
    if(mod(i,4)==0) then
      tv=0; tl=0; ip=0
    end if
    it=sum(ip); mt=sum(mp); ot=real(mod(i,13),real64)/16
    incoming=tv+tl+it+mt
    etmp=s+incoming-ot
    emax=v
    if((incoming-mt)/dt<1.e-7_real64.and.mt/dt>1.e-7_real64) emax=g
    ef=1; eex=0
    if(etmp>emax+1.e-7_real64.and.incoming>0) then
      ef=max(0.0_real64,1.0_real64-(etmp-emax)/incoming)
      eex=(1.0_real64-ef)*(tv+tl)
    end if
    etr=[ef*tv/dt,ef*tl/dt]; eir=ef*ip/dt; emr=ef*mp/dt
    call run()
    call require(ok,1)
    call require(all(transfer([f,tmp,mx,ex,tr,ir,mr],[0_int64],10)== &
        transfer([ef,etmp,emax,eex,etr,eir,emr],[0_int64],10)),2)
  end do
  dt=0
  call run()
  call require(.not.ok,3)
  dt=1; g=2
  call run()
  call require(.not.ok,4)
  g=0; ip(1)=-1
  call run()
  call require(.not.ok,5)
  print '(a)', 'PPA_WU05A4_INFLOW_LIMIT_FORMULA_100000=PASS'
  print '(a)', 'PPA_WU05A4_INFLOW_LIMIT_INVALID=PASS'
contains
  subroutine run()
    call limit_domain_inflow(s,v,g,dt,tv,tl,it,mt,ot,ip,mp,f,tmp,mx,ex,tr,ir,mr,ok)
  end subroutine
  subroutine require(condition,code)
    logical,intent(in)::condition
    integer,intent(in)::code
    if(condition)return
    print *,code
    error stop 1
  end subroutine
end program
