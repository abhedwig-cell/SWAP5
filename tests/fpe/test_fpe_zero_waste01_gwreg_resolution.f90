program test_fpe_zero_waste01_gwreg_resolution
  use, intrinsic :: iso_fortran_env, only: int64, real64
  implicit none
  integer(int64), allocatable :: handle_ids(:)
  logical, allocatable :: active(:)
  integer :: n,reps,r,h,idx,status
  integer(int64) :: c0,c1,rate,checksum,linear_checks,fast_checks
  real(real64) :: seconds
  character(len=32) :: arg

  call get_command_argument(1,arg); read(arg,*) n
  if(n<=0) error stop 'H-GWREG01 invalid N'
  select case(n)
  case(:100); reps=500
  case(101:1000); reps=20
  case default; reps=1
  end select

  allocate(handle_ids(n),active(n))
  active=.true.
  do h=1,n
    handle_ids(h)=int(h,int64)
  end do

  checksum=0_int64
  call system_clock(c0,rate)
  do r=1,reps
    do h=1,n
      call linear_resolve(int(h,int64),handle_ids,active,idx,status)
      if(status/=0 .or. idx/=h) error stop 'linear mismatch'
      checksum=checksum+int(idx,int64)
    end do
  end do
  call system_clock(c1)
  seconds=real(c1-c0,real64)/real(rate,real64)
  linear_checks=int(n,int64)*int(n+1,int64)/2_int64
  call emit('linear_full_pass',n,reps,seconds,checksum,linear_checks)

  checksum=0_int64
  call system_clock(c0)
  do r=1,reps
    do h=1,n
      call verified_direct_resolve(int(h,int64),handle_ids,active,idx,status)
      if(status/=0 .or. idx/=h) error stop 'direct mismatch'
      checksum=checksum+int(idx,int64)
    end do
  end do
  call system_clock(c1)
  seconds=real(c1-c0,real64)/real(rate,real64)
  fast_checks=int(n,int64)
  call emit('verified_direct_full_pass',n,reps,seconds,checksum,fast_checks)

  handle_ids=0_int64; active=.false.
  handle_ids(1)=int(n+1,int64); active(1)=.true.
  call verified_direct_resolve(int(n+1,int64),handle_ids,active,idx,status)
  if(status/=0 .or. idx/=1) error stop 'fallback failed'
  call verified_direct_resolve(1_int64,handle_ids,active,idx,status)
  if(status==0) error stop 'stale handle resolved'
  write(*,'(A,I0,A)') 'GWREG01_FALLBACK_LIFECYCLE,n=',n,',PASS'
  write(*,'(A)') 'FPE_ZERO_WASTE01_GWREG01_RESOLUTION=PASS'

contains
  subroutine linear_resolve(handle,ids,is_active,index,status)
    integer(int64),intent(in)::handle,ids(:)
    logical,intent(in)::is_active(:)
    integer,intent(out)::index,status
    integer::i
    index=0; status=1
    if(handle<=0_int64)return
    do i=1,size(ids)
      if(.not.is_active(i))cycle
      if(ids(i)==handle)then; index=i; status=0; return; end if
    end do
  end subroutine

  subroutine verified_direct_resolve(handle,ids,is_active,index,status)
    integer(int64),intent(in)::handle,ids(:)
    logical,intent(in)::is_active(:)
    integer,intent(out)::index,status
    integer::i,candidate
    index=0; status=1
    if(handle<=0_int64)return
    if(handle<=int(size(ids),int64))then
      candidate=int(handle)
      if(is_active(candidate).and.ids(candidate)==handle)then
        index=candidate; status=0; return
      end if
    end if
    do i=1,size(ids)
      if(.not.is_active(i))cycle
      if(ids(i)==handle)then; index=i; status=0; return; end if
    end do
  end subroutine

  subroutine emit(metric,nvalue,repetitions,elapsed,sumv,checks)
    character(len=*),intent(in)::metric
    integer,intent(in)::nvalue,repetitions
    real(real64),intent(in)::elapsed
    integer(int64),intent(in)::sumv,checks
    write(*,'(A,A,A,I0,A,I0,A,ES24.16,A,ES24.16,A,I0,A,I0)') &
      'GWREG01,metric=',trim(metric),',n=',nvalue,',reps=',repetitions,',seconds=',elapsed, &
      ',ns_per_full_pass=',1.0e9_real64*elapsed/real(repetitions,real64),',checksum=',sumv,',checks_per_pass=',checks
  end subroutine
end program
