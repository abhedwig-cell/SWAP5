program test_ahl34_bind_decomposition
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_adaptive_hydraulic_builder, only: b110_adaptive_hydraulic_table_t, build_b110_adaptive_hydraulic_table
  use mod_b110_adaptive_hydraulic_cache, only: b110_adaptive_hydraulic_cache_key_t, make_b110_adaptive_hydraulic_key
  use mod_b110_adaptive_hydraulic_provider, only: b110_adaptive_hydraulic_provider_t, &
       bind_b110_adaptive_hydraulic_provider
  implicit none

  integer, parameter :: NKEY=64, NREQ=200000, NREP=5
  type(b110_default_mvg_parameters_t), target :: p(NKEY)
  type(b110_default_mvg_provider_t) :: analytical(NKEY)
  type(b110_adaptive_hydraulic_table_t) :: table(NKEY)
  type(b110_adaptive_hydraulic_provider_t) :: adaptive
  real(real64) :: raw(24,1)
  real(real64) :: t_key(NREP),t_sampler(NREP),t_copy(NREP),t_switch(NREP),t_same(NREP)
  integer :: i,r
  logical :: ok,hit

  do i=1,NKEY
    call make_raw(i,raw)
    call initialize_b110_default_mvg_parameters(p(i),raw)
    call bind_b110_default_mvg_provider(analytical(i),p(i),0.25_real64)
    call build_b110_adaptive_hydraulic_table(analytical(i),p(i)%cofgen(1,1),p(i)%cofgen(2,1),table(i),ok)
    call require(ok,'table build')
  end do

  ! Warm the production shared registry before any complete-bind timing.
  do i=1,NKEY
    call bind_b110_adaptive_hydraulic_provider(adaptive,p(i),0.25_real64,ok,hit)
    call require(ok,'registry warmup')
  end do

  do r=1,NREP
    call time_key_build(p,t_key(r))
    call time_sampler_setup(p,t_sampler(r))
    call time_table_copy(table,t_copy(r))
    call time_same_key(adaptive,p(1),t_same(r))
    call bind_b110_adaptive_hydraulic_provider(adaptive,p(NKEY),0.25_real64,ok,hit)
    call require(ok,'switch setup')
    call time_switch(adaptive,p,t_switch(r))
  end do

  call sort5(t_key);call sort5(t_sampler);call sort5(t_copy);call sort5(t_switch);call sort5(t_same)

  write(*,'(A,1X,ES18.10)') 'AHL34_KEY_SEC',t_key(3)
  write(*,'(A,1X,ES18.10)') 'AHL34_SAMPLER_SEC',t_sampler(3)
  write(*,'(A,1X,ES18.10)') 'AHL34_TABLE_COPY_SEC',t_copy(3)
  write(*,'(A,1X,ES18.10)') 'AHL34_SAME_KEY_SEC',t_same(3)
  write(*,'(A,1X,ES18.10)') 'AHL34_CHANGED_AUTHORITY_SEC',t_switch(3)
  write(*,'(A,1X,F10.4,1X,A,F10.4,1X,A,F10.4,1X,A,F10.4)') &
       'AHL34_COMPONENT_FRACTIONS','KEY=',t_key(3)/t_switch(3), &
       'SAMPLER=',t_sampler(3)/t_switch(3),'COPY=',t_copy(3)/t_switch(3), &
       'SAME_BASE=',t_same(3)/t_switch(3)
  write(*,'(A,1X,A,F10.4,1X,A,F10.4)') 'AHL34_TABLE_SUPPORT', &
       'MEAN=',mean_support(table),'MAX=',max_support(table)
  write(*,'(A)') 'AHL34_CHARACTERIZATION=PASS'

contains

  subroutine time_key_build(params,elapsed)
    type(b110_default_mvg_parameters_t),intent(in)::params(:)
    type(b110_adaptive_hydraulic_cache_key_t)::key
    integer(int64)::checksum
    real(real64),intent(out)::elapsed
    real(real64)::a,b
    integer::q,idx
    checksum=0_int64
    call cpu_time(a)
    do q=1,NREQ
      idx=1+mod(q-1,NKEY)
      key=make_b110_adaptive_hydraulic_key(params(idx),'B110_DEFAULT_MVG',3,1)
      checksum=ieor(checksum,key%fingerprint)
    end do
    call cpu_time(b)
    if(checksum==huge(checksum)) write(*,*) checksum
    elapsed=(b-a)/real(NREQ,real64)
  end subroutine time_key_build

  subroutine time_sampler_setup(params,elapsed)
    type(b110_default_mvg_parameters_t),target,intent(in)::params(:)
    type(b110_default_mvg_parameters_t),target::sp
    type(b110_default_mvg_provider_t)::prov
    real(real64)::input(42,1),checksum
    real(real64),intent(out)::elapsed
    real(real64)::a,b
    integer::q,idx
    checksum=0.0_real64
    call cpu_time(a)
    do q=1,NREQ
      idx=1+mod(q-1,NKEY)
      input(:,1)=params(idx)%cofgen(1:42,1)
      call initialize_b110_default_mvg_parameters(sp,input,params(idx)%ksatexm_extension_enabled)
      call bind_b110_default_mvg_provider(prov,sp,0.25_real64)
      checksum=checksum+sp%cofgen(29,1)
    end do
    call cpu_time(b)
    if(checksum<0.0_real64) write(*,*) checksum
    elapsed=(b-a)/real(NREQ,real64)
  end subroutine time_sampler_setup

  subroutine time_table_copy(src,elapsed)
    type(b110_adaptive_hydraulic_table_t),intent(in)::src(:)
    type(b110_adaptive_hydraulic_table_t)::dst
    real(real64),intent(out)::elapsed
    real(real64)::a,b,checksum
    integer::q,idx
    checksum=0.0_real64
    call cpu_time(a)
    do q=1,NREQ
      idx=1+mod(q-1,NKEY)
      dst=src(idx)
      checksum=checksum+dst%x(1)+real(dst%n,real64)*1.0e-12_real64
    end do
    call cpu_time(b)
    if(checksum>huge(checksum)) write(*,*) checksum
    elapsed=(b-a)/real(NREQ,real64)
  end subroutine time_table_copy

  subroutine time_same_key(prov,param,elapsed)
    type(b110_adaptive_hydraulic_provider_t),intent(inout)::prov
    type(b110_default_mvg_parameters_t),target,intent(in)::param
    real(real64),intent(out)::elapsed
    real(real64)::a,b
    integer::q
    logical::lok,lhit
    call bind_b110_adaptive_hydraulic_provider(prov,param,0.25_real64,lok,lhit)
    call require(lok,'same setup')
    call cpu_time(a)
    do q=1,NREQ
      call bind_b110_adaptive_hydraulic_provider(prov,param,0.25_real64,lok,lhit)
      if(.not.lok .or. .not.lhit) error stop 'same timed bind'
    end do
    call cpu_time(b)
    elapsed=(b-a)/real(NREQ,real64)
  end subroutine time_same_key

  subroutine time_switch(prov,params,elapsed)
    type(b110_adaptive_hydraulic_provider_t),intent(inout)::prov
    type(b110_default_mvg_parameters_t),target,intent(in)::params(:)
    real(real64),intent(out)::elapsed
    real(real64)::a,b
    integer::q,idx
    logical::lok,lhit
    call cpu_time(a)
    do q=1,NREQ
      idx=1+mod(q-1,NKEY)
      call bind_b110_adaptive_hydraulic_provider(prov,params(idx),0.25_real64,lok,lhit)
      if(.not.lok .or. .not.lhit) error stop 'switch timed bind'
    end do
    call cpu_time(b)
    elapsed=(b-a)/real(NREQ,real64)
  end subroutine time_switch

  real(real64) function mean_support(t) result(v)
    type(b110_adaptive_hydraulic_table_t),intent(in)::t(:)
    integer::j
    v=0.0_real64
    do j=1,size(t);v=v+real(t(j)%n,real64);end do
    v=v/real(size(t),real64)
  end function mean_support

  real(real64) function max_support(t) result(v)
    type(b110_adaptive_hydraulic_table_t),intent(in)::t(:)
    integer::j
    v=0.0_real64
    do j=1,size(t);v=max(v,real(t(j)%n,real64));end do
  end function max_support

  subroutine make_raw(idx,a)
    integer,intent(in)::idx
    real(real64),intent(out)::a(24,1)
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

  subroutine sort5(v)
    real(real64),intent(inout)::v(5)
    real(real64)::tmp
    integer::a,b
    do a=1,4;do b=a+1,5
      if(v(b)<v(a))then;tmp=v(a);v(a)=v(b);v(b)=tmp;end if
    end do;end do
  end subroutine sort5

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then;write(*,'(A,1X,A)')'AHL34_FAIL',trim(msg);error stop 1;end if
  end subroutine require
end program test_ahl34_bind_decomposition
