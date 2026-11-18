module mod_prescribed_groundwater_reaction
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  public :: prescribed_groundwater_reaction
contains
  pure subroutine prescribed_groundwater_reaction(active, step, dz, trial, previous, saturated, &
                                                  net_sink, darcy_interface, bottom, delta, status)
    ! Read-only receipt for original SWBOTB1. The Richards interface owns the
    ! unsaturated exchange; only prescribed saturated-tail storage and original
    ! signed sink-source-root rates determine its constraint reaction.
    integer, intent(in) :: active
    real(8), intent(in) :: step, dz(:), trial(:), previous(:), saturated(:), net_sink(:), darcy_interface
    real(8), intent(inout) :: bottom, delta
    integer, intent(out) :: status
    integer :: n, i
    real(8) :: candidate_bottom, candidate_delta, storage

    status=1
    n=size(dz)
    if(n<1.or.active<1.or.active>n) return
    if(size(trial)/=n.or.size(previous)/=n.or.size(saturated)/=n.or.size(net_sink)/=n) return
    if(.not.ieee_is_finite(step).or..not.ieee_is_finite(darcy_interface)) return
    if(step<=0d0) return
    if(.not.all(ieee_is_finite(dz)).or..not.all(ieee_is_finite(trial))) return
    if(.not.all(ieee_is_finite(previous)).or..not.all(ieee_is_finite(saturated))) return
    if(.not.all(ieee_is_finite(net_sink))) return
    if(any(dz<=0d0).or.any(previous<0d0).or.any(saturated<0d0)) return
    candidate_bottom=darcy_interface
    candidate_delta=0d0
    do i=1,n
      if(i<=active) then
        storage=dz(i)*(trial(i)-previous(i))
      else
        storage=dz(i)*(saturated(i)-previous(i))
        candidate_bottom=candidate_bottom+storage/step+net_sink(i)
      end if
      candidate_delta=candidate_delta+storage
    end do
    if(.not.ieee_is_finite(candidate_bottom).or..not.ieee_is_finite(candidate_delta)) return
    bottom=candidate_bottom
    delta=candidate_delta
    status=0
  end subroutine
end module
