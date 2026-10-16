module mod_crop_b111_pressure_head_average
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: CROP_HAVG_OK=0, CROP_HAVG_INVALID=1
  real(real64), parameter :: B111_SMALL=1.0e-6_real64
  public :: compute_b111_pressure_head_average
contains
  ! B1.11 SWAP/functions.f90 h_average: weighted pF, then inverse pF.
  ! This pure sampler does not authenticate the hydraulic snapshot.
  pure subroutine compute_b111_pressure_head_average(z_monitor,dz,h,average,status)
    real(real64), intent(in) :: z_monitor,dz(:),h(:)
    real(real64), intent(out) :: average
    integer, intent(out) :: status
    real(real64) :: remaining,depth,pf,thickness
    integer :: i
    average=0.0_real64
    status=CROP_HAVG_INVALID
    if (.not.ieee_is_finite(z_monitor)) return
    if (size(dz)<1.or.size(h)/=size(dz)) return
    if (.not.all(ieee_is_finite(dz)).or..not.all(ieee_is_finite(h))) return
    if (any(dz<=0.0_real64).or.z_monitor>0.0_real64) return
    depth=-z_monitor
    ! MOD_params small = 1.0d-6 in the byte-verified B0 source.
    if (abs(z_monitor)<B111_SMALL) then
      average=-10.0_real64**log10(max(1.0_real64,-h(1)))
    else
      if (depth>sum(dz)) return
      remaining=depth
      pf=0.0_real64
      do i=1,size(dz)
        if (remaining<=0.0_real64) exit
        thickness=min(remaining,dz(i))
        pf=pf+log10(max(1.0_real64,-h(i)))*thickness/depth
        remaining=remaining-thickness
      end do
      if (remaining>epsilon(depth)*16.0_real64) return
      average=-10.0_real64**pf
    end if
    if (.not.ieee_is_finite(average)) return
    status=CROP_HAVG_OK
  end subroutine
end module
