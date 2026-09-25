program test_ahl38_slot_handle_repair
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, initialize_b110_default_mvg_parameters
  use mod_b110_adaptive_hydraulic_provider, only: b110_adaptive_hydraulic_provider_t, &
       bind_b110_adaptive_hydraulic_provider
  implicit none

  integer, parameter :: NKEY=64, NREQ=200000, NREP=9, NH=16, NEVAL=100000
  type(b110_default_mvg_parameters_t), target :: p(NKEY)
  type(b110_adaptive_hydraulic_provider_t) :: warmer, phandle, pcopy
  real(real64) :: raw(42,1)
  real(real64) :: th(NH), wh(NH), kh(NH), ch(NH), dh(NH)
  real(real64) :: wc(NH), kc(NH), cc(NH), dc(NH)
  real(real64) :: thandle(NREP), tcopy(NREP), ratios(NREP)
  real(real64) :: tsame(NREP), tevalh(NREP), tevalc(NREP), eratio(NREP)
  logical :: ok,hit
  integer :: i,r

  do i=1,NKEY
    call make_raw(i,raw)
    call initialize_b110_default_mvg_parameters(p(i),raw)
    call bind_b110_adaptive_hydraulic_provider(warmer,p(i),0.25_real64,ok,hit)
    call require(ok,'registry warmup')
  end do

  do i=1,NH
    th(i)=-10.0_real64**(1.0_real64+4.0_real64*real(i-1,real64)/real(NH-1,real64))
  end do

  call bind_b110_adaptive_hydraulic_provider(phandle,p(1),0.25_real64,ok,hit,.true.)
  call require(ok .and. hit,'handle bind')
  call bind_b110_adaptive_hydraulic_provider(pcopy,p(1),0.25_real64,ok,hit,.false.)
  call require(ok .and. hit,'copy bind')
  call phandle%evaluate(th,wh,kh,ch,dh)
  call pcopy%evaluate(th,wc,kc,cc,dc)
  call require(all(wh==wc),'theta identity')
  call require(all(kh==kc),'K identity')
  call require(all(ch==cc),'C identity')
  call require(all(dh==dc),'dKdh identity')
  write(*,'(A)') 'AHL38_SEMANTIC_IDENTITY=PASS'

  do r=1,NREP
    if(mod(r,2)==1)then
      call time_switch(phandle,.true.,thandle(r))
      call time_switch(pcopy,.false.,tcopy(r))
      call time_eval(phandle,tevalh(r))
      call time_eval(pcopy,tevalc(r))
    else
      call time_switch(pcopy,.false.,tcopy(r))
      call time_switch(phandle,.true.,thandle(r))
      call time_eval(pcopy,tevalc(r))
      call time_eval(phandle,tevalh(r))
    end if
    call time_same(phandle,tsame(r))
    ratios(r)=thandle(r)/max(tcopy(r),tiny(1.0_real64))
    eratio(r)=tevalh(r)/max(tevalc(r),tiny(1.0_real64))
    write(*,'(A,1X,I0,1X,ES18.10,1X,ES18.10,1X,F10.6,1X,F10.6)') &
         'AHL38_BIND_PAIR',r,tcopy(r),thandle(r),ratios(r),tsame(r)
    write(*,'(A,1X,I0,1X,ES18.10,1X,ES18.10,1X,F10.6)') &
         'AHL38_EVAL_PAIR',r,tevalc(r),tevalh(r),eratio(r)
  end do

  call sort9(ratios);call sort9(eratio);call sort9(tsame)
  write(*,'(A,1X,F10.6)') 'AHL38_MEDIAN_HANDLE_OVER_COPY_BIND',ratios(5)
  write(*,'(A,1X,ES18.10)') 'AHL38_MEDIAN_SAME_KEY_SEC_PER_BIND',tsame(5)
  write(*,'(A,1X,F10.6)') 'AHL38_MEDIAN_HANDLE_OVER_COPY_EVAL',eratio(5)

  call require(ratios(5)<=0.80_real64,'changed-authority bind gate')
  call require(tsame(5)<=1.60006e-7_real64,'same-key bind gate')
  call require(eratio(5)<=1.05_real64,'evaluate overhead gate')
  write(*,'(A)') 'AHL38_PERFORMANCE_GATES=PASS'

contains

  subroutine time_switch(prov,use_handle,elapsed)
    type(b110_adaptive_hydraulic_provider_t),intent(inout)::prov
    logical,intent(in)::use_handle
    real(real64),intent(out)::elapsed
    real(real64)::a,b
    integer::q,idx
    logical::lok,lhit
    call bind_b110_adaptive_hydraulic_provider(prov,p(NKEY),0.25_real64,lok,lhit,use_handle)
    call cpu_time(a)
    do q=1,NREQ
      idx=1+mod(q-1,NKEY)
      call bind_b110_adaptive_hydraulic_provider(prov,p(idx),0.25_real64,lok,lhit,use_handle)
      if(.not.lok .or. .not.lhit)error stop 'timed switch bind'
    end do
    call cpu_time(b)
    elapsed=(b-a)/real(NREQ,real64)
  end subroutine time_switch

  subroutine time_same(prov,elapsed)
    type(b110_adaptive_hydraulic_provider_t),intent(inout)::prov
    real(real64),intent(out)::elapsed
    real(real64)::a,b
    integer::q
    logical::lok,lhit
    call bind_b110_adaptive_hydraulic_provider(prov,p(1),0.25_real64,lok,lhit,.true.)
    call cpu_time(a)
    do q=1,NREQ
      call bind_b110_adaptive_hydraulic_provider(prov,p(1),0.25_real64,lok,lhit,.true.)
      if(.not.lok .or. .not.lhit)error stop 'timed same bind'
    end do
    call cpu_time(b)
    elapsed=(b-a)/real(NREQ,real64)
  end subroutine time_same

  subroutine time_eval(prov,elapsed)
    type(b110_adaptive_hydraulic_provider_t),intent(in)::prov
    real(real64),intent(out)::elapsed
    real(real64)::a,b
    real(real64)::w(NH),k(NH),c(NH),d(NH),checksum
    integer::q
    checksum=0.0_real64
    call cpu_time(a)
    do q=1,NEVAL
      call prov%evaluate(th,w,k,c,d)
      checksum=checksum+w(1)+1e-6_real64*c(NH)+1e-9_real64*k(1)
    end do
    call cpu_time(b)
    if(checksum==0.0_real64)error stop 'evaluation checksum'
    elapsed=(b-a)/real(NEVAL,real64)
  end subroutine time_eval

  subroutine make_raw(idx,a)
    integer,intent(in)::idx
    real(real64),intent(out)::a(42,1)
    real(real64)::scale,n
    a=0.0_real64
    scale=1.0_real64+1.0e-5_real64*real(idx,real64)
    n=1.50_real64+5.0e-4_real64*real(mod(idx,11),real64)
    a(1,1)=0.02_real64;a(2,1)=0.43_real64;a(3,1)=5.0_real64*scale
    a(4,1)=0.015_real64;a(5,1)=0.5_real64;a(6,1)=n
    a(7,1)=1.0_real64-1.0_real64/n;a(8,1)=a(4,1)
    a(9,1)=0.0_real64;a(10,1)=a(3,1);a(11,1)=0.999_real64
    a(12,1)=0.99_real64*a(3,1);a(22,1)=-1.0e6_real64;a(23,1)=1.0e-12_real64
  end subroutine make_raw

  subroutine sort9(v)
    real(real64),intent(inout)::v(9)
    real(real64)::tmp
    integer::a,b
    do a=1,8
      do b=a+1,9
        if(v(b)<v(a))then;tmp=v(a);v(a)=v(b);v(b)=tmp;end if
      end do
    end do
  end subroutine sort9

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)') 'AHL38_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine require
end program test_ahl38_slot_handle_repair
