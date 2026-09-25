program test_fpe_newton_candidate01_reductions
  use, intrinsic :: iso_fortran_env, only: int64, real64
  implicit none
  integer, parameter :: sizes(3)=[4,60,200]
  integer :: isize,n,reps,r,i
  integer(int64) :: c0,c1,rate
  real(real64),allocatable :: residual(:)
  real(real64) :: sump,sum1,fmax,seconds,checksum

  do isize=1,size(sizes)
    n=sizes(isize)
    allocate(residual(n))
    do i=1,n
      residual(i)=sin(0.17_real64*real(i,real64))*1.0e-6_real64+cos(0.07_real64*real(i,real64))*1.0e-9_real64
    end do
    reps=max(200000,20000000/n)

    checksum=0.0_real64
    call system_clock(c0,rate)
    do r=1,reps
      sump=0.5_real64*dot_product(residual,residual)
      sum1=sum(residual)
      fmax=maxval(abs(residual))
      checksum=checksum+sump+sum1+fmax
    end do
    call system_clock(c1)
    seconds=real(c1-c0,real64)/real(rate,real64)
    write(*,'(*(g0))') 'NEWTON_CANDIDATE01_REDUCTION|MODE=THREE_INTRINSICS|N=',n,'|REPS=',reps, &
         '|NS_PER=',1.0e9_real64*seconds/real(reps,real64),'|CHECKSUM=',checksum

    checksum=0.0_real64
    call system_clock(c0)
    do r=1,reps
      sump=0.0_real64; sum1=0.0_real64; fmax=0.0_real64
      do i=1,n
        sump=sump+residual(i)*residual(i)
        sum1=sum1+residual(i)
        fmax=max(fmax,abs(residual(i)))
      end do
      sump=0.5_real64*sump
      checksum=checksum+sump+sum1+fmax
    end do
    call system_clock(c1)
    seconds=real(c1-c0,real64)/real(rate,real64)
    write(*,'(*(g0))') 'NEWTON_CANDIDATE01_REDUCTION|MODE=ONE_LOOP|N=',n,'|REPS=',reps, &
         '|NS_PER=',1.0e9_real64*seconds/real(reps,real64),'|CHECKSUM=',checksum
    deallocate(residual)
  end do
  write(*,'(A)') 'NEWTON_CANDIDATE01_REDUCTION=PASS'
end program
