program test_fpe_zero_waste01_gwctx01
  use, intrinsic :: iso_fortran_env, only: int64, real64
  implicit none
  integer :: n, reps, rep, i, j
  integer(int64) :: c0,c1,rate
  integer(int64), allocatable :: handles(:)
  real(real64) :: old_s,new_s
  logical :: duplicate, increasing
  character(len=32) :: arg

  call get_command_argument(1,arg); read(arg,*) n
  reps=max(1,20000000/max(1,n*n))
  allocate(handles(n))
  do i=1,n
    handles(i)=int(i,int64)
  end do

  call system_clock(c0,rate)
  do rep=1,reps
    duplicate=.false.
    do i=1,n
      if(handles(i)<=0_int64)then
        duplicate=.true.; exit
      end if
      do j=1,i-1
        if(handles(j)==handles(i))then
          duplicate=.true.; exit
        end if
      end do
      if(duplicate)exit
    end do
  end do
  call system_clock(c1)
  old_s=real(c1-c0,real64)/real(rate,real64)

  call system_clock(c0)
  do rep=1,reps
    increasing=.true.
    if(handles(1)<=0_int64)increasing=.false.
    do i=2,n
      if(handles(i)<=0_int64 .or. handles(i)<=handles(i-1))then
        increasing=.false.; exit
      end if
    end do
  end do
  call system_clock(c1)
  new_s=real(c1-c0,real64)/real(rate,real64)

  if(duplicate .or. .not.increasing) error stop 'GWCTX01 proof mismatch'
  write(*,'(A,I0,A,I0,A,ES16.8,A,ES16.8,A,F12.6)') &
       'GWCTX01,n=',n,',reps=',reps,',pairwise_seconds=',old_s,',linear_seconds=',new_s,',ratio=',new_s/old_s
end program
