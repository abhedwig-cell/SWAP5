! Worker-local equality constraints on the complete Reference soil matrix.
! Solves [T+L*R^T B; C^T D] [head; contact] = [rhs; constraint_rhs].
! No physical state, source correction, contact law or file I/O is owned here.
module mod_reference_bordered_solver
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_reference_linear_solver,only:reference_tridag_low_rank
 implicit none
 private
 public::reference_bordered_solve
contains
 subroutine reference_bordered_solve(a,b,c,rhs,border,column_test,corner,constraint_rhs, &
                                    head,contact,status,additional_solves,left,right)
  real(real64),intent(in)::a(:),b(:),c(:),rhs(:),border(:,:),column_test(:,:),corner(:,:),constraint_rhs(:)
  real(real64),intent(out)::head(:),contact(:)
  integer,intent(out)::status,additional_solves
  real(real64),intent(in),optional::left(:,:),right(:,:)
  real(real64),allocatable::l(:,:),r(:,:),y(:),z(:,:),gamma(:),schur(:,:),small_rhs(:),lambda(:),x(:)
  real(real64),allocatable::defect(:),scale(:),small_defect(:),small_scale(:)
  integer::n,k,j,extra
  head=0d0;contact=0d0;status=3001;additional_solves=0
  n=size(rhs);k=size(constraint_rhs)
  if(n<1.or.size(a)/=n.or.size(b)/=n.or.size(c)/=n.or.size(head)/=n.or.size(contact)/=k)return
  if(any(shape(border)/=[n,k]).or.any(shape(column_test)/=[n,k]).or.any(shape(corner)/=[k,k]))return
  if(any(.not.ieee_is_finite(a)).or.any(.not.ieee_is_finite(b)).or.any(.not.ieee_is_finite(c)).or. &
     any(.not.ieee_is_finite(rhs)).or.any(.not.ieee_is_finite(border)).or. &
     any(.not.ieee_is_finite(column_test)).or.any(.not.ieee_is_finite(corner)).or. &
     any(.not.ieee_is_finite(constraint_rhs)))return
  if(present(left).neqv.present(right))return
  if(present(left).and.present(right))then
   if(size(left,1)/=n.or.size(right,1)/=n.or.size(left,2)/=size(right,2))return
   if(any(.not.ieee_is_finite(left)).or.any(.not.ieee_is_finite(right)))return
   l=left;r=right
  else
   allocate(l(n,0),r(n,0))
  end if
  allocate(y(n),z(n,k),gamma(n),schur(k,k),small_rhs(k),lambda(k),x(n))
  call reference_tridag_low_rank(n,a,b,c,rhs,l,r,y,gamma,status,extra)
  additional_solves=extra
  if(status/=0)return
  do j=1,k
   call reference_tridag_low_rank(n,a,b,c,border(:,j),l,r,z(:,j),gamma,status,extra)
   additional_solves=additional_solves+1+extra
   if(status/=0)return
  end do
  if(k>0)then
   schur=corner-matmul(transpose(column_test),z)
   small_rhs=constraint_rhs-matmul(transpose(column_test),y)
   call solve_small(schur,small_rhs,lambda,status)
   if(status/=0)return
   x=y-matmul(z,lambda)
  else
   x=y
  end if
  if(any(.not.ieee_is_finite(x)).or.any(.not.ieee_is_finite(lambda)))then
   status=3002;return
  end if
  ! Check BOTH blocks against their original coefficients, including storage.
  defect=b*x+matmul(l,matmul(transpose(r),x))+matmul(border,lambda)-rhs
  scale=1d0+abs(rhs)+abs(b*x)+matmul(abs(l),matmul(transpose(abs(r)),abs(x)))+matmul(abs(border),abs(lambda))
  do j=2,n
   defect(j)=defect(j)+a(j)*x(j-1);scale(j)=scale(j)+abs(a(j)*x(j-1))
   defect(j-1)=defect(j-1)+c(j-1)*x(j);scale(j-1)=scale(j-1)+abs(c(j-1)*x(j))
  end do
  small_defect=matmul(transpose(column_test),x)+matmul(corner,lambda)-constraint_rhs
  small_scale=1d0+abs(constraint_rhs)+matmul(transpose(abs(column_test)),abs(x))+matmul(abs(corner),abs(lambda))
  if(any(.not.ieee_is_finite(defect)).or.any(.not.ieee_is_finite(small_defect)))then
   status=3002;return
  end if
  if(any(abs(defect)>1024d0*epsilon(1d0)*scale).or. &
     any(abs(small_defect)>1024d0*epsilon(1d0)*small_scale))then
   status=3003;return
  end if
  head=x;contact=lambda;status=0
 end subroutine

 subroutine solve_small(a,b,x,status)
  real(real64),intent(in)::a(:,:),b(:)
  real(real64),intent(out)::x(:)
  integer,intent(out)::status
  real(real64)::m(size(b),size(b)),v(size(b)),row(size(b)),s,t,f
  integer::n,i,j,p
  status=3010;x=0d0;n=size(b);m=a;v=b
  do i=1,n
   s=maxval(abs(m(i,:)))
   if(s<=tiny(1d0))return
   m(i,:)=m(i,:)/s;v(i)=v(i)/s
  end do
  do i=1,n
   p=i-1+maxloc(abs(m(i:n,i)),dim=1)
   if(abs(m(p,i))<=64d0*epsilon(1d0))return
   row=m(i,:);m(i,:)=m(p,:);m(p,:)=row;t=v(i);v(i)=v(p);v(p)=t
   do j=i+1,n
    f=m(j,i)/m(i,i);m(j,i:n)=m(j,i:n)-f*m(i,i:n);v(j)=v(j)-f*v(i)
   end do
  end do
  do i=n,1,-1
   x(i)=(v(i)-dot_product(m(i,i+1:n),x(i+1:n)))/m(i,i)
  end do
  if(any(.not.ieee_is_finite(x)))return
  status=0
 end subroutine
end module
