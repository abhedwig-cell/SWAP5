module mod_wall_cohort_research
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 implicit none
 private
 type,public::wall_cohort_t
  real(real64),allocatable::lo(:),hi(:),age(:),seed(:)
 end type
 public::prepare_wall_cohorts,wall_potential,advance_wall_cohorts,wall_count,compress_wall_cohorts
contains
 pure integer function wall_count(w) result(n)
  type(wall_cohort_t),intent(in)::w
  n=0;if(allocated(w%lo))n=size(w%lo)
 end function
 subroutine prepare_wall_cohorts(accepted,lo,hi,seed,candidate,ok)
  type(wall_cohort_t),intent(in)::accepted
  real(real64),intent(in)::lo,hi,seed
  type(wall_cohort_t),intent(out)::candidate
  logical,intent(out)::ok
  real(real64)::cursor,a,b
  integer::n,j,k
  ok=.false.;candidate=wall_cohort_t()
  if(.not.all(ieee_is_finite([lo,hi,seed])).or.lo<0.or.seed<0)return
  n=wall_count(accepted)
  if(n>0)then
   if(.not.allocated(accepted%hi).or..not.allocated(accepted%age).or..not.allocated(accepted%seed))return
   if(size(accepted%hi)/=n.or.size(accepted%age)/=n.or.size(accepted%seed)/=n)return
   if(.not.all(ieee_is_finite(accepted%lo)).or..not.all(ieee_is_finite(accepted%hi)).or..not.all(ieee_is_finite(accepted%age)).or..not.all(ieee_is_finite(accepted%seed)))return
   if(any(accepted%hi<=accepted%lo).or.any(accepted%lo<0).or.any(accepted%age<0).or.any(accepted%seed<0))return
   do j=2,n
    if(accepted%lo(j)/=accepted%hi(j-1))return
   enddo
  endif
  allocate(candidate%lo(n+2),candidate%hi(n+2),candidate%age(n+2),candidate%seed(n+2))
  k=0;cursor=lo
  if(hi>lo)then
   do j=1,n
    a=max(lo,accepted%lo(j));b=min(hi,accepted%hi(j))
    if(b<=a)cycle
    if(a>cursor)call add(cursor,a,0._real64,seed)
    call add(a,b,accepted%age(j),accepted%seed(j));cursor=b
   enddo
   if(hi>cursor)call add(cursor,hi,0._real64,seed)
  endif
  candidate%lo=candidate%lo(:k);candidate%hi=candidate%hi(:k)
  candidate%age=candidate%age(:k);candidate%seed=candidate%seed(:k)
  ok=.true.
 contains
  subroutine add(a,b,t,s)
   real(real64),intent(in)::a,b,t,s
   k=k+1;candidate%lo(k)=a;candidate%hi(k)=b;candidate%age(k)=t;candidate%seed(k)=s
  end subroutine
 end subroutine
 pure subroutine advance_wall_cohorts(w,dt)
  type(wall_cohort_t),intent(inout)::w
  real(real64),intent(in)::dt
  if(allocated(w%age))w%age=w%age+dt
 end subroutine
 subroutine compress_wall_cohorts(w,limit,dt,ok)
  type(wall_cohort_t),intent(inout)::w
  integer,intent(in)::limit
  real(real64),intent(in)::dt
  logical,intent(out)::ok
  real(real64)::score,best,l1,l2,s1,s2,age
  integer::n,j,k
  ok=.false.
  if(limit<1.or..not.ieee_is_finite(dt).or.dt<=0.)return
  n=wall_count(w)
  do while(n>limit)
   best=huge(1._real64);k=1
   do j=1,n-1
    score=abs(w%age(j+1)-w%age(j))/(w%age(j+1)+w%age(j)+dt)
    if(score<best)then;best=score;k=j;endif
   enddo
   l1=w%hi(k)-w%lo(k);l2=w%hi(k+1)-w%lo(k+1)
   s1=l1*w%seed(k);s2=l2*w%seed(k+1)
   if(s1+s2>0.)then
    age=(s1*w%age(k)+s2*w%age(k+1))/(s1+s2)
   else
    age=(l1*w%age(k)+l2*w%age(k+1))/(l1+l2)
   endif
   w%hi(k)=w%hi(k+1);w%seed(k)=(s1+s2)/(l1+l2);w%age(k)=age
   do j=k+1,n-1
    w%lo(j)=w%lo(j+1);w%hi(j)=w%hi(j+1);w%age(j)=w%age(j+1);w%seed(j)=w%seed(j+1)
   enddo
   n=n-1
   w%lo=w%lo(:n);w%hi=w%hi(:n);w%age=w%age(:n);w%seed=w%seed(:n)
  enddo
  ok=.true.
 end subroutine
 pure subroutine wall_potential(w,phi,head,conductivity,dt,length,chi,potential,darcy)
  type(wall_cohort_t),intent(in)::w
  real(real64),intent(in)::phi,head,conductivity,dt,length,chi
  real(real64),intent(out)::potential,darcy
  real(real64)::a,b,cp,cd,cross,rootdiff
  integer::j
  potential=0.;darcy=0.;cd=8._real64*conductivity*dt/length**2
  do j=1,wall_count(w)
   a=w%lo(j);b=w%hi(j)
   rootdiff=dt/(sqrt(w%age(j)+dt)+sqrt(w%age(j)))
   cp=chi*4._real64/length*w%seed(j)*rootdiff
   if(cd>0.)then
    cross=max(a,min(b,cp/cd-phi+head))
   else
    cross=b
   endif
   potential=potential+cp*(cross-a)+cd*((phi-head)*(b-cross)+.5_real64*(b**2-cross**2))
   darcy=darcy+cd*((phi-head)*(b-a)+.5_real64*(b**2-a**2))
  enddo
 end subroutine
end module
