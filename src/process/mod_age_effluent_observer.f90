module mod_age_effluent_observer
  use iso_fortran_env,only:real64
  use ieee_arithmetic,only:ieee_is_finite
  implicit none
  private
  integer,parameter,public::AGE_EFFLUENT_OK=0,AGE_EFFLUENT_INVALID=1,AGE_EFFLUENT_UNREPRESENTABLE=2
  type,public::age_effluent_result_t
    ! Bottom, roots, then each drainage level; exports only, not net exchange.
    real(real64),allocatable::water_cm(:),age_amount_cm_day(:),mean_age_day(:)
  end type
  public::evaluate_age_effluent,age_effluent_mean
contains
  pure subroutine age_effluent_mean(amount,water,mean,status)
    real(real64),intent(in)::amount,water
    real(real64),intent(inout)::mean
    integer,intent(out)::status
    real(real64)::candidate
    status=AGE_EFFLUENT_INVALID
    if(.not.all(ieee_is_finite([amount,water])))return
    if(min(amount,water)<0.0_real64)return
    if(water<=0.0_real64)then
      if(amount>0.0_real64)return
      candidate=0.0_real64
    else
      status=AGE_EFFLUENT_UNREPRESENTABLE
      if(water<1.0_real64)then
        if(amount>huge(1.0_real64)*water)return
      end if
      candidate=amount/water
    end if
    mean=candidate;status=AGE_EFFLUENT_OK
  end subroutine

  pure subroutine evaluate_age_effluent(dt,concentration,root_rate,drainage_rate,bottom_up_rate,result,status)
    real(real64),intent(in)::dt,concentration(:),root_rate(:),drainage_rate(:,:),bottom_up_rate
    type(age_effluent_result_t),intent(inout)::result
    integer,intent(out)::status
    type(age_effluent_result_t)::candidate
    integer::n,levels,i,j,code
    real(real64)::outward
    status=AGE_EFFLUENT_INVALID;n=size(concentration);levels=size(drainage_rate,1)
    if(n<1.or.n>4096.or.levels>5.or.size(root_rate)/=n.or.size(drainage_rate,2)/=n)return
    if(.not.all(ieee_is_finite([dt,bottom_up_rate])).or..not.all(ieee_is_finite(concentration)).or. &
       .not.all(ieee_is_finite(root_rate)).or..not.all(ieee_is_finite(drainage_rate)))return
    ! Same finite forcing/amount envelope as the existing accepted age provider.
    ! These bounds preclude upper overflow under checked/trapping arithmetic.
    if(dt<=0.0_real64.or.dt>1.0e3_real64.or.any(concentration<0.0_real64).or. &
       any(concentration>1.0e24_real64).or.any(root_rate<0.0_real64).or. &
       any(root_rate>1.0e6_real64).or.any(abs(drainage_rate)>1.0e6_real64).or. &
       abs(bottom_up_rate)>1.0e6_real64)return
    allocate(candidate%water_cm(2+levels),candidate%age_amount_cm_day(2+levels),candidate%mean_age_day(2+levels))
    candidate%water_cm=0.0_real64;candidate%age_amount_cm_day=0.0_real64;candidate%mean_age_day=0.0_real64
    outward=max(-bottom_up_rate,0.0_real64)
    candidate%water_cm(1)=outward*dt
    candidate%age_amount_cm_day(1)=outward*concentration(n)*dt
    do i=1,n
      candidate%water_cm(2)=candidate%water_cm(2)+root_rate(i)*dt
      candidate%age_amount_cm_day(2)=candidate%age_amount_cm_day(2)+root_rate(i)*concentration(i)*dt
      do j=1,levels
        outward=max(drainage_rate(j,i),0.0_real64)
        candidate%water_cm(2+j)=candidate%water_cm(2+j)+outward*dt
        candidate%age_amount_cm_day(2+j)=candidate%age_amount_cm_day(2+j)+outward*concentration(i)*dt
      end do
    end do
    do j=1,2+levels
      call age_effluent_mean(candidate%age_amount_cm_day(j),candidate%water_cm(j),candidate%mean_age_day(j),code)
      if(code/=AGE_EFFLUENT_OK)then
        status=AGE_EFFLUENT_UNREPRESENTABLE;return
      end if
    end do
    result=candidate;status=AGE_EFFLUENT_OK
  end subroutine
end module
