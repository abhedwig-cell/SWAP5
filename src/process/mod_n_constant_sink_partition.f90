! Explicit equal-priority allocation policy. No daily caller is activated here.
module mod_n_constant_sink_partition
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 implicit none
 private
 public::partition_n_constant_sinks
contains
 pure subroutine partition_n_constant_sinks(request,dt,tau,total,actual,unmet,status)
  real(real64),intent(in)::request(:),dt,tau,total
  real(real64),intent(out)::actual(:),unmet(:)
  integer,intent(out)::status
  real(real64)::rate,amount,before,remaining,tol
  integer::i
  actual=0d0;unmet=0d0;status=1
  if(size(actual)/=size(request).or.size(unmet)/=size(request).or.size(request)==0)return
  if(.not.all(ieee_is_finite(request)))return
  if(.not.all(ieee_is_finite([dt,tau,total])))return
  if(dt<=0d0.or.tau<0d0.or.tau>dt.or.total<0d0.or.any(request<0d0))return
  rate=0d0
  do i=1,size(request)
   if(request(i)>huge(1d0)-rate)return
   rate=rate+request(i)
  end do
  if(dt>1d0)then
   if(rate>huge(1d0)/dt)return
  end if
  amount=rate*dt;before=rate*tau
  if(.not.all(ieee_is_finite([amount,before])))return
  tol=64d0*epsilon(1d0)*max(amount,total,tiny(1d0))
  if(total>amount)then
   if(total-amount>tol)return
  end if
  if(total<before)then
   if(before-total>tol)return
  end if
  if(rate==0d0)then
   if(total/=0d0)return
   status=0;return
  end if
  ! In a valid receipt all constant requests were met until tau. The
  ! remainder of actual delivery is shared in the same request proportions.
  remaining=max(0d0,min(amount,total)-before)
  if(count(request>0d0)==1)then
   do i=1,size(request)
    if(request(i)>0d0)actual(i)=min(amount,total)
   end do
  else
   actual=request*tau+(request/rate)*remaining
  end if
  unmet=max(0d0,request*dt-actual)
  if(.not.all(ieee_is_finite(actual)).or..not.all(ieee_is_finite(unmet)))then
   actual=0d0;unmet=0d0;return
  end if
  status=0
 end subroutine
end module
