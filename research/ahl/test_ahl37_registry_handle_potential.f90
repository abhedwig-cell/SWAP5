program test_ahl37_registry_handle_potential
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_adaptive_hydraulic_builder, only: b110_adaptive_hydraulic_table_t
  use mod_b110_adaptive_hydraulic_cache, only: b110_adaptive_hydraulic_cache_t, &
       b110_adaptive_hydraulic_cache_key_t, make_b110_adaptive_hydraulic_key
  implicit none

  integer, parameter :: NKEY=64, NREQ=200000, NREP=9
  integer, parameter :: POLICY_VERSION=3, BRANCH_POLICY_VERSION=1
  character(len=*), parameter :: MODEL_ID='B110_DEFAULT_MVG'
  type(b110_default_mvg_parameters_t), target :: p(NKEY)
  type(b110_default_mvg_provider_t) :: analytical(NKEY)
  type(b110_adaptive_hydraulic_cache_key_t) :: key(NKEY)
  type(b110_adaptive_hydraulic_cache_t) :: cache
  type(b110_adaptive_hydraulic_table_t) :: table
  real(real64) :: raw(42,1), tcopy(NREP), tslot(NREP), ratios(NREP)
  logical :: ok,hit
  integer :: i,r,slot

  do i=1,NKEY
    call make_raw(i,raw)
    call initialize_b110_default_mvg_parameters(p(i),raw)
    call bind_b110_default_mvg_provider(analytical(i),p(i),0.25_real64)
    key(i)=make_b110_adaptive_hydraulic_key(p(i),MODEL_ID,POLICY_VERSION,BRANCH_POLICY_VERSION)
    call cache%get_or_build(key(i),p(i),analytical(i),table,hit,ok)
    call require(ok,'warm build')
  end do

  do r=1,NREP
    if(mod(r,2)==1)then
      call time_copy(tcopy(r))
      call time_slot(tslot(r))
    else
      call time_slot(tslot(r))
      call time_copy(tcopy(r))
    end if
    ratios(r)=tslot(r)/max(tcopy(r),tiny(1.0_real64))
    write(*,'(A,1X,I0,1X,ES18.10,1X,ES18.10,1X,F10.6)') &
         'AHL37_PAIR',r,tcopy(r),tslot(r),ratios(r)
  end do

  call sort9(ratios)
  write(*,'(A,1X,F10.6)') 'AHL37_MEDIAN_SLOT_OVER_COPY_RATIO',ratios(5)
  write(*,'(A,1X,F10.6)') 'AHL37_MEDIAN_COPY_ELIMINATION_FRACTION',1.0_real64-ratios(5)
  call require(ratios(5)<0.75_real64,'ownership repair justification gate')
  write(*,'(A)') 'AHL37_CHARACTERIZATION=PASS'

contains

  subroutine time_copy(elapsed)
    real(real64),intent(out)::elapsed
    real(real64)::a,b
    integer::q,idx
    logical::lhit
    call cpu_time(a)
    do q=1,NREQ
      idx=1+mod(q-1,NKEY)
      call cache%lookup(key(idx),table,lhit)
      if(.not.lhit) error stop 'copy lookup miss'
    end do
    call cpu_time(b)
    elapsed=(b-a)/real(NREQ,real64)
  end subroutine time_copy

  subroutine time_slot(elapsed)
    real(real64),intent(out)::elapsed
    real(real64)::a,b
    integer::q,idx,lslot
    logical::lhit
    call cpu_time(a)
    do q=1,NREQ
      idx=1+mod(q-1,NKEY)
      call cache%find_slot(key(idx),lslot,lhit)
      if(.not.lhit .or. lslot<=0) error stop 'slot lookup miss'
      slot=lslot
    end do
    call cpu_time(b)
    elapsed=(b-a)/real(NREQ,real64)
  end subroutine time_slot

  subroutine make_raw(idx,a)
    integer,intent(in)::idx
    real(real64),intent(out)::a(42,1)
    real(real64)::scale,n
    a=0.0_real64
    scale=1.0_real64+1.0e-5_real64*real(idx,real64)
    n=1.50_real64+5.0e-4_real64*real(mod(idx,11),real64)
    a(1,1)=0.02_real64; a(2,1)=0.43_real64; a(3,1)=5.0_real64*scale
    a(4,1)=0.015_real64; a(5,1)=0.5_real64; a(6,1)=n
    a(7,1)=1.0_real64-1.0_real64/n; a(8,1)=a(4,1)
    a(9,1)=0.0_real64; a(10,1)=a(3,1); a(11,1)=0.999_real64
    a(12,1)=0.99_real64*a(3,1); a(22,1)=-1.0e6_real64; a(23,1)=1.0e-12_real64
  end subroutine make_raw

  subroutine sort9(v)
    real(real64),intent(inout)::v(9)
    real(real64)::tmp
    integer::a,b
    do a=1,8
      do b=a+1,9
        if(v(b)<v(a))then
          tmp=v(a);v(a)=v(b);v(b)=tmp
        end if
      end do
    end do
  end subroutine sort9

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)') 'AHL37_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine require

end program test_ahl37_registry_handle_potential
