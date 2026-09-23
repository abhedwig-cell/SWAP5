! B1.11 MACRORATE final standard-domain outflow scaling, after redistribution.
module mod_ppa_wu05a4_outflow_limit
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  public :: limit_domain_outflow
contains
  pure subroutine limit_domain_outflow(dt,total,excess,saturated,unsaturated,rapid, &
      fraction,saturated_rate,unsaturated_rate,rapid_rate,ok)
    real(real64),intent(in)::dt,total,excess,saturated(:),unsaturated(:),rapid(:)
    real(real64),intent(out)::fraction,saturated_rate(:),unsaturated_rate(:),rapid_rate(:)
    logical,intent(out)::ok
    integer::n
    ok=.false.; fraction=0; saturated_rate=0; unsaturated_rate=0; rapid_rate=0
    n=size(saturated)
    if(n<1.or.size(unsaturated)/=n.or.size(rapid)/=n) return
    if(size(saturated_rate)/=n.or.size(unsaturated_rate)/=n.or.size(rapid_rate)/=n) return
    if(.not.all(ieee_is_finite([dt,total,excess]))) return
    if(.not.all(ieee_is_finite(saturated))) return
    if(.not.all(ieee_is_finite(unsaturated))) return
    if(.not.all(ieee_is_finite(rapid))) return
    if(dt<=0.or.total<0.or.excess<0) return
    if(any(saturated<0).or.any(unsaturated<0).or.any(rapid<0)) return
    ! Total and excess retain source-loop grouping; the caller supplies excess
    ! AFTER interdomain redistribution. Rapid is zero for an internal domain.
    fraction=1.0_real64
    if(excess/dt>1.e-7_real64) then
      if(total>excess) then
        fraction=1.0_real64-excess/total
        fraction=max(0.0_real64,fraction)
      else
        fraction=0.0_real64
      end if
    end if
    saturated_rate=fraction*saturated/dt
    unsaturated_rate=fraction*unsaturated/dt
    rapid_rate=fraction*rapid/dt
    ok=.true.
  end subroutine
end module
