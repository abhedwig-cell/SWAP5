program low_rank_reference_test
 use iso_fortran_env,only:real64
 use mod_reference_linear_solver
 implicit none
 real(real64),allocatable::a(:),b(:),c(:),rhs(:),x(:),expected(:),gamma(:),left(:,:),right(:,:),matrix(:,:)
 real(real64)::worst,error
 integer::n,rank,i,j,k,phase,code,cases
 worst=0d0;cases=0
 do phase=1,3
  n=3
  if(phase==2)n=17
  if(phase==3)n=112
  allocate(a(n),b(n),c(n),rhs(n),x(n),expected(n),gamma(n),matrix(n,n))
  do rank=0,5
   allocate(left(n,rank),right(n,rank))
   do k=1,12
    a=-.2d0;c=-.3d0;b=2d0;a(1)=0d0;c(n)=0d0
    matrix=0d0
    do i=1,n
     matrix(i,i)=b(i)
     if(i>1)matrix(i,i-1)=a(i)
     if(i<n)matrix(i,i+1)=c(i)
     expected(i)=sin(real(i+k,real64))
     do j=1,rank
      left(i,j)=.05d0*sin(real(i+2*j+k,real64))
      right(i,j)=.05d0*cos(real(2*i+j-k,real64))
     end do
    end do
    matrix=matrix+matmul(left,transpose(right));rhs=matmul(matrix,expected)
    call reference_tridag_low_rank(n,a,b,c,rhs,left,right,x,gamma,code)
    if(code/=0)error stop 'low-rank solve rejected nonsingular matrix'
    error=maxval(abs(matmul(matrix,x)-rhs));worst=max(worst,error)
    if(error>1d-12.or.maxval(abs(x-expected))>1d-12)error stop 'incorrect full low-rank solve'
    cases=cases+1
   end do
   deallocate(left,right)
  end do
  deallocate(a,b,c,rhs,x,expected,gamma,matrix)
 end do
 allocate(a(2),b(2),c(2),rhs(2),x(2),gamma(2),left(2,1),right(2,1))
 a=0d0;b=1d0;c=0d0;rhs=1d0;left(:,1)=[1d0,0d0];right(:,1)=[-1d0,0d0]
 call reference_tridag_low_rank(2,a,b,c,rhs,left,right,x,gamma,code)
 if(code==0)error stop 'singular full matrix silently solved as tridiagonal'
 print *, 'DATAQUAL10_LOW_RANK_SOLVE_PASS',cases,worst,code
end program
