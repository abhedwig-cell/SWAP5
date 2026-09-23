! Isolated B1.11 MACRORATE standard-domain top-excess redistribution.
module mod_ppa_wu05a4_redistribution
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  type,public::redistribution_candidate
    logical::valid=.false.
    real(real64)::remaining=0
    real(real64),allocatable::deficit(:),outflow_excess(:),vertical_rate(:),lateral_rate(:)
  end type
  public::redistribute_top_excess
contains
  subroutine redistribute_top_excess(dt,excess,total_deficit,relative_deficit,proportion,deficit, &
      outflow_excess,vertical,lateral,vertical_rate,lateral_rate,candidate)
    real(real64),intent(in)::dt,excess,total_deficit,relative_deficit(:),proportion(:),deficit(:)
    real(real64),intent(in)::outflow_excess(:),vertical(:),lateral(:),vertical_rate(:),lateral_rate(:)
    type(redistribution_candidate),intent(out)::candidate
    type(redistribution_candidate)::trial
    integer::n,i,j,k,swap,order(size(deficit))
    real(real64)::remaining_fraction,share,extra,factor
    n=size(deficit)
    if(n<1) return
    if(size(relative_deficit)/=n.or.size(proportion)/=n.or.size(outflow_excess)/=n) return
    if(size(vertical)/=n.or.size(lateral)/=n.or.size(vertical_rate)/=n.or.size(lateral_rate)/=n) return
    if(.not.all(ieee_is_finite([dt,excess,total_deficit]))) return
    if(dt<=0.or.excess<0.or.total_deficit<0) return
    if(.not.all(ieee_is_finite([relative_deficit,proportion,deficit,outflow_excess, &
        vertical,lateral,vertical_rate,lateral_rate]))) return
    if(any([relative_deficit,proportion,deficit,outflow_excess,vertical,lateral, &
        vertical_rate,lateral_rate]<0)) return
    if(any(proportion>1)) return
    trial%remaining=excess; trial%deficit=deficit; trial%outflow_excess=outflow_excess
    trial%vertical_rate=vertical_rate; trial%lateral_rate=lateral_rate
    if(excess>1.e-6_real64.and.total_deficit>1.e-6_real64) then
      order=[(i,i=1,n)]
      do i=1,n-1
        do j=i+1,n
          if(relative_deficit(order(i))>relative_deficit(order(j))) then
            swap=order(i); order(i)=order(j); order(j)=swap
          end if
        end do
      end do
      remaining_fraction=1.0_real64
      do i=1,n
        k=order(i)
        if(trial%deficit(k)>1.e-7_real64.and.vertical(k)+lateral(k)>1.e-7_real64) then
          ! Undefined source denominator is rejected, never replaced by epsilon.
          if(remaining_fraction<=0.or.proportion(k)>remaining_fraction) return
          share=proportion(k)/remaining_fraction
          extra=min(share*trial%remaining,trial%deficit(k))
          factor=extra/(vertical(k)+lateral(k))
          trial%vertical_rate(k)=(1.0_real64+factor)*vertical(k)/dt
          trial%lateral_rate(k)=(1.0_real64+factor)*lateral(k)/dt
          trial%remaining=trial%remaining-extra
          trial%outflow_excess(k)=max(0.0_real64,trial%outflow_excess(k)-extra)
          trial%deficit(k)=trial%deficit(k)-extra
        else
          trial%deficit(k)=0
        end if
        remaining_fraction=remaining_fraction-proportion(k)
      end do
    end if
    trial%valid=.true.
    candidate=trial
  end subroutine
end module
